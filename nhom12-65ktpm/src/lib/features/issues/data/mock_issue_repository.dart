import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/issue.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../../core/contracts/repositories/issue_repository.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/mock/mock_issue_access.dart';
import '../../../core/mock/mock_transaction_store.dart';
import 'mock_issue_command_runner.dart';

// Mô phỏng RPC Issue (BR-34, BR-47, SS-BR §9). Issue KHÔNG bao giờ đổi
// owner/holder/due_date/payment hay Transaction.status; chỉ ghi Issue + Event.
class MockIssueRepository implements IssueRepository {
  MockIssueRepository(this._runner);

  final MockIssueCommandRunner _runner;

  static const _maxTextLength = 1000;

  static const _resolved = MockIssueFail(
    DomainErrorCode.invalidTransactionTransition,
    'Sự cố này đã được giải quyết.',
  );

  @override
  Future<CommandResult<IssueDetails>> reportIssue(
    CreateIssueInput input, {required String idempotencyKey}) =>
      _runner.run(
        command: 'report_issue',
        transactionId: input.transactionId,
        handoverId: input.handoverId,
        idempotencyKey: idempotencyKey,
        payload: '${input.type.wire}|${input.reason}|${input.handoverId ?? ''}',
        body: (txn) {
          final reason = input.reason.trim();
          if (reason.isEmpty || reason.length > _maxTextLength) {
            return const MockIssueFail(DomainErrorCode.invalidInput,
                'Hãy mô tả sự cố (tối đa 1000 ký tự).');
          }
          final handoverId = input.handoverId;
          if (handoverId != null &&
              handoverParties(_runner.store, txn.id, handoverId).isEmpty) {
            return const MockIssueFail(DomainErrorCode.invalidInput,
                'Lượt bàn giao không thuộc giao dịch này.');
          }
          final blocker = _reportBlocker(txn);
          if (blocker != null) return blocker;

          // Nguyên tử: Issue OPEN + Event giao dịch + Event Issue.
          final store = _runner.store;
          final issue = Issue(
            id: store.nextIssueId(),
            transactionId: txn.id,
            reporterId: _runner.actorId,
            type: input.type,
            reason: reason,
            handoverId: handoverId,
            status: IssueStatus.open,
            openedAt: store.clock(),
          );
          store.putIssue(issue);
          store.appendIssueEvent(
            issueId: issue.id,
            eventType: 'ISSUE_OPENED',
            safeDescription: 'Sự cố được mở.',
            actorDisplay: _runner.actorDisplay,
          );
          final eventId = store.appendEvent(
            transactionId: txn.id,
            eventType: 'ISSUE_OPENED',
            safeDescription:
                'Có sự cố được mở. Lịch sử bàn giao và thanh toán không thay đổi.',
            actorDisplay: _runner.actorDisplay,
          );
          return MockIssueOk(issueId: issue.id, eventId: eventId);
        },
      );

  @override
  Future<CommandResult<IssueDetails>> proposeResolution(
    String issueId, String summary, {required String idempotencyKey}) =>
      _runner.run(
        command: 'propose_issue_resolution',
        issueId: issueId,
        idempotencyKey: idempotencyKey,
        payload: summary,
        body: (txn) {
          final store = _runner.store;
          final issue = store.issue(issueId)!;
          if (!issue.isOpen) return _resolved;
          final text = summary.trim();
          if (text.isEmpty || text.length > _maxTextLength) {
            return const MockIssueFail(DomainErrorCode.invalidInput,
                'Hãy nhập phương án giải quyết (tối đa 1000 ký tự).');
          }
          // Revision tăng dần; xác nhận của bản cũ mất hiệu lực. Người đề xuất
          // cũng phải xác nhận riêng, đề xuất không tự là đồng thuận.
          final revision = (store.issueProposal(issueId)?.revision ?? 0) + 1;
          store.putIssueProposal(
            issueId,
            MockIssueProposal(
              revision: revision,
              summary: text,
              proposedBy: _runner.actorId,
              proposedAt: store.clock(),
            ),
          );
          return MockIssueOk(
            issueId: issueId,
            eventId: store.appendIssueEvent(
              issueId: issueId,
              eventType: 'RESOLUTION_PROPOSED',
              safeDescription: 'Đề xuất phương án giải quyết (bản $revision).',
              actorDisplay: _runner.actorDisplay,
            ),
          );
        },
      );

  @override
  Future<CommandResult<IssueDetails>> confirmResolution(
    String issueId, int resolutionRevision, {required String idempotencyKey}) =>
      _runner.run(
        command: 'confirm_issue_resolution',
        issueId: issueId,
        idempotencyKey: idempotencyKey,
        payload: '$resolutionRevision',
        body: (txn) {
          final store = _runner.store;
          final issue = store.issue(issueId)!;
          if (!issue.isOpen) return _resolved;
          final proposal = store.issueProposal(issueId);
          if (proposal == null) {
            return const MockIssueFail(
                DomainErrorCode.invalidTransactionTransition,
                'Chưa có phương án giải quyết để xác nhận.');
          }
          if (proposal.revision != resolutionRevision) {
            return const MockIssueFail(DomainErrorCode.conflict,
                'Phương án đã thay đổi. Hãy xem lại bản mới nhất.');
          }
          if (proposal.approvals.containsKey(_runner.actorId)) {
            return const MockIssueFail(
                DomainErrorCode.invalidTransactionTransition,
                'Bạn đã xác nhận phương án này.');
          }

          final now = store.clock();
          final approved = proposal.withApproval(_runner.actorId, now);
          store.putIssueProposal(issueId, approved);
          final eventId = store.appendIssueEvent(
            issueId: issueId,
            eventType: 'RESOLUTION_CONFIRMED',
            safeDescription: 'Xác nhận phương án giải quyết (bản $resolutionRevision).',
            actorDisplay: _runner.actorDisplay,
          );

          // Chỉ khi MỌI bên bị ảnh hưởng trực tiếp xác nhận mới RESOLVED; không ai đóng thay.
          if (_allApproved(issue, approved)) {
            store.putIssue(Issue(
              id: issue.id,
              transactionId: issue.transactionId,
              reporterId: issue.reporterId,
              type: issue.type,
              reason: issue.reason,
              handoverId: issue.handoverId,
              status: IssueStatus.resolved,
              openedAt: issue.openedAt,
              resolvedAt: now,
            ));
            store.appendIssueEvent(
              issueId: issueId,
              eventType: 'ISSUE_RESOLVED',
              safeDescription: 'Các bên đã thống nhất. Sự cố được giải quyết.',
            );
            store.appendEvent(
              transactionId: txn.id,
              eventType: 'ISSUE_RESOLVED',
              safeDescription: 'Một sự cố đã được các bên thống nhất giải quyết.',
            );
          }
          return MockIssueOk(issueId: issueId, eventId: eventId);
        },
      );

  // Bên bị ảnh hưởng suy ra theo Issue/chặng, không mặc định luôn là A và B.
  bool _allApproved(Issue issue, MockIssueProposal proposal) =>
      issueAffectedParties(_runner.store, issue)
          .every(proposal.approvals.containsKey);

  // Giao dịch đã hủy không còn đối tượng để khiếu nại; sau COMPLETED chỉ được
  // khởi tạo trong hạn 7 ngày lịch Việt Nam (hết ngày thứ 7).
  // Điều kiện dùng chung với allowedActions: isIssueReportWindowOpen.
  MockIssueFail? _reportBlocker(StudyTransaction txn) {
    if (isIssueReportWindowOpen(_runner.store, txn)) return null;
    if (txn.status == TransactionStatus.cancelled) {
      return const MockIssueFail(DomainErrorCode.invalidTransactionTransition,
          'Giao dịch đã hủy, không thể mở sự cố.');
    }
    return const MockIssueFail(DomainErrorCode.invalidTransactionTransition,
        'Đã quá hạn 7 ngày để mở sự cố cho giao dịch này.');
  }
}

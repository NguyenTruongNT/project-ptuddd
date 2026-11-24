import '../contracts/models/models.dart';
import '../contracts/repositories/issue_repository.dart';
import 'mock_fixtures.dart';
import 'mock_transaction_store.dart';

// Repository ĐỌC Issue. allowedActions mô phỏng gợi ý của server,
// không phải quyết định cuối: lệnh mock vẫn kiểm tra lại quyền và trạng thái.
class MockIssueQueryRepository implements IssueQueryRepository {
  MockIssueQueryRepository({
    required this.demoViewerId,
    MockTransactionStore? store,
  }) : store = store ?? MockTransactionStore.fromFixtures();

  final String demoViewerId;
  final MockTransactionStore store;

  // Chỉ A hoặc B của giao dịch; C không xem Issue chỉ vì là courier.
  bool _canSee(Issue issue) {
    final txn = store.transaction(issue.transactionId);
    return txn != null &&
        (txn.ownerAtAcceptance == demoViewerId || txn.receiverId == demoViewerId);
  }

  @override
  Future<List<IssueDetails>> getMyIssues() async => List.unmodifiable(
      store.issues.where(_canSee).map(_toDetails));

  @override
  Future<IssueDetails?> getIssueDetails(String issueId) async {
    final issue = store.issue(issueId);
    if (issue == null || !_canSee(issue)) return null; // Không lộ dữ liệu.
    return _toDetails(issue);
  }

  @override
  Future<List<IssueEventItem>> getTimeline(String issueId) async {
    if (await getIssueDetails(issueId) == null) return const [];
    final events = [...store.issueEvents(issueId)]..sort((a, b) {
        final byTime = a.serverAt.compareTo(b.serverAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return List.unmodifiable(events);
  }

  IssueDetails _toDetails(Issue issue) {
    final txn = store.transaction(issue.transactionId)!;
    final counterpartyId =
        issue.reporterId == txn.ownerAtAcceptance ? txn.receiverId : txn.ownerAtAcceptance;
    final proposal = store.issueProposal(issue.id);

    return IssueDetails(
      issue: issue,
      materialTitle: store.material(txn.materialId)?.title ?? 'Tài liệu',
      reporterDisplayName: _name(issue.reporterId),
      counterpartyDisplayName: _name(counterpartyId),
      relation: issue.reporterId == demoViewerId
          ? IssueRelation.reporter
          : IssueRelation.counterparty,
      proposal: proposal == null ? null : _toProposal(txn, proposal),
      // Bằng chứng thuộc EvidenceRepository (module Handover); mock chưa có ảnh.
      allowedActions: _allowedActions(issue, proposal),
    );
  }

  // Các bên bị ảnh hưởng trực tiếp: A và B của giao dịch (C chưa được tính).
  IssueResolutionProposal _toProposal(
      StudyTransaction txn, MockIssueProposal proposal) {
    return IssueResolutionProposal(
      revision: proposal.revision,
      summary: proposal.summary,
      proposedByDisplayName: _name(proposal.proposedBy),
      proposedAt: proposal.proposedAt,
      consents: [
        for (final userId in [txn.ownerAtAcceptance, txn.receiverId])
          IssueConsent(
            participantDisplayName: _name(userId),
            approvedAt: proposal.approvals[userId],
          ),
      ],
    );
  }

  Set<IssueAction> _allowedActions(Issue issue, MockIssueProposal? proposal) {
    if (!issue.isOpen) return const {};
    return Set.unmodifiable({
      IssueAction.proposeResolution,
      if (proposal != null && !proposal.approvals.containsKey(demoViewerId))
        IssueAction.confirmResolution,
    });
  }

  static String _name(String userId) =>
      MockFixtures.displayNames[userId] ?? 'Người dùng';
}

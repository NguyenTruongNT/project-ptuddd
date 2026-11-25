import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/models/issue.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/mock/mock_fixtures.dart';
import '../../../core/mock/mock_issue_access.dart';
import '../../../core/mock/mock_issue_query_repository.dart';
import '../../../core/mock/mock_transaction_store.dart';

// Kết quả kiểm tra + ghi của một lệnh Issue mock.
sealed class MockIssueMutation {
  const MockIssueMutation();
}

final class MockIssueOk extends MockIssueMutation {
  const MockIssueOk({required this.issueId, required this.eventId});
  final String issueId;
  final String eventId;
}

final class MockIssueFail extends MockIssueMutation {
  const MockIssueFail(this.code, this.safeMessage);
  final DomainErrorCode code;
  final String safeMessage;
}

typedef MockIssueBody = MockIssueMutation Function(StudyTransaction txn);

// Giả lập khung RPC server theo CONTRACTS.md §7 cho các lệnh Issue:
// 1) actor lấy từ "session" (actorId), không từ payload;
// 2) quyền theo phạm vi Issue/chặng (mock_issue_access.dart); mọi trường hợp
//    không đủ quyền trả FORBIDDEN chung, không phân biệt "không tồn tại";
// 3) kiểm tra (actor, command, idempotency_key) + hash payload;
// 4) kiểm tra quyền/trạng thái mới nhất TRƯỚC, sau đó mới ghi; trả ACK + event ID.
// Đây KHÔNG phải backend thật: Supabase RPC vẫn phải kiểm tra lại toàn bộ.
class MockIssueCommandRunner {
  MockIssueCommandRunner({required this.store, required this.actorId});

  final MockTransactionStore store;
  final String actorId;

  String? get actorDisplay => MockFixtures.displayNames[actorId];

  static const _forbidden = CommandError<IssueDetails>(
      DomainErrorCode.forbidden, 'Bạn không có quyền thực hiện thao tác này.');

  // Đúng một trong `issueId` (lệnh trên Issue có sẵn: chỉ bên bị ảnh hưởng trực tiếp)
  // hoặc `transactionId` (mở Issue mới: A/B hoặc một đầu của `handoverId`).
  Future<CommandResult<IssueDetails>> run({
    required String command,
    required String idempotencyKey,
    required MockIssueBody body,
    String? issueId,
    String? transactionId,
    String? handoverId,
    String payload = '',
  }) async {
    assert((issueId == null) != (transactionId == null));
    if (idempotencyKey.trim().isEmpty) {
      return const CommandError(
          DomainErrorCode.invalidInput, 'Thiếu mã thao tác, vui lòng thử lại.');
    }
    final issue = issueId == null ? null : store.issue(issueId);
    final txnId = issueId != null ? issue?.transactionId : transactionId;
    final txn = txnId == null ? null : store.transaction(txnId);
    final allowed = txn != null &&
        (issueId != null
            ? issue != null && canActOnIssue(store, issue, actorId)
            : canReportIssue(store, txn, handoverId, actorId));
    if (!allowed) {
      // Không phân biệt "không tồn tại" và "không có quyền".
      return _forbidden;
    }

    final payloadHash = '$command|${issueId ?? transactionId}|$payload';
    final previous = store.receipt(actorId, command, idempotencyKey);
    if (previous != null) {
      if (previous.payloadHash != payloadHash) {
        return const CommandError(DomainErrorCode.conflict,
            'Mã thao tác đã được dùng cho nội dung khác.');
      }
      // Retry sau timeout: trả kết quả cũ, không ghi lại lần hai.
      return CommandOk(await _details(previous.entityId!), previous.eventId);
    }

    switch (body(txn)) {
      case MockIssueFail(:final code, :final safeMessage):
        return CommandError(code, safeMessage);
      case MockIssueOk(issueId: final id, :final eventId):
        store.saveReceipt(
            actorId,
            command,
            idempotencyKey,
            MockCommandReceipt(
                payloadHash: payloadHash, eventId: eventId, entityId: id));
        return CommandOk(await _details(id), eventId);
    }
  }

  Future<IssueDetails> _details(String issueId) async =>
      (await MockIssueQueryRepository(demoViewerId: actorId, store: store)
          .getIssueDetails(issueId))!;
}

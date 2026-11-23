import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/mock/mock_fixtures.dart';
import '../../../core/mock/mock_transaction_query_repository.dart';
import '../../../core/mock/mock_transaction_store.dart';

// Kết quả kiểm tra + ghi của một lệnh mock.
sealed class MockMutation {
  const MockMutation();
}

final class MockMutationOk extends MockMutation {
  const MockMutationOk(this.eventId);
  final String eventId;
}

final class MockMutationFail extends MockMutation {
  const MockMutationFail(this.code, this.safeMessage);
  final DomainErrorCode code;
  final String safeMessage;
}

typedef MockMutationBody = MockMutation Function(
  StudyTransaction txn,
  TransactionViewerRole role,
);

// Giả lập khung RPC server theo CONTRACTS.md §7 cho các lệnh Transaction:
// 1) actor lấy từ "session" (actorId), không từ payload;
// 2) kiểm tra (actor, command, idempotency_key) + hash payload;
// 3) kiểm tra quyền/trạng thái mới nhất TRƯỚC, sau đó mới ghi;
// 4) trả ACK kèm event ID.
// Đây KHÔNG phải backend thật: Supabase RPC vẫn phải kiểm tra lại toàn bộ.
class MockCommandRunner {
  MockCommandRunner({required this.store, required this.actorId});

  final MockTransactionStore store;
  final String actorId;

  String? get actorDisplay => MockFixtures.displayNames[actorId];

  Future<CommandResult<TransactionDetails>> run({
    required String command,
    required String transactionId,
    required String idempotencyKey,
    required MockMutationBody body,
    String payload = '',
  }) async {
    if (idempotencyKey.trim().isEmpty) {
      return const CommandError(
          DomainErrorCode.invalidInput, 'Thiếu mã thao tác, vui lòng thử lại.');
    }
    final txn = store.transaction(transactionId);
    final isParticipant = txn != null &&
        (txn.ownerAtAcceptance == actorId || txn.receiverId == actorId);
    if (!isParticipant) {
      // Không phân biệt "không tồn tại" và "không có quyền".
      return const CommandError(
          DomainErrorCode.forbidden, 'Bạn không có quyền thực hiện thao tác này.');
    }

    final payloadHash = '$command|$transactionId|$payload';
    final previous = store.receipt(actorId, command, idempotencyKey);
    if (previous != null) {
      if (previous.payloadHash != payloadHash) {
        return const CommandError(DomainErrorCode.conflict,
            'Mã thao tác đã được dùng cho nội dung khác.');
      }
      // Retry sau timeout: trả kết quả cũ, không ghi lại lần hai.
      return CommandOk(await _details(transactionId), previous.eventId);
    }

    final role = txn.ownerAtAcceptance == actorId
        ? TransactionViewerRole.owner
        : TransactionViewerRole.receiver;
    final outcome = body(txn, role);
    switch (outcome) {
      case MockMutationFail(:final code, :final safeMessage):
        return CommandError(code, safeMessage);
      case MockMutationOk(:final eventId):
        store.saveReceipt(actorId, command, idempotencyKey,
            MockCommandReceipt(payloadHash: payloadHash, eventId: eventId));
        return CommandOk(await _details(transactionId), eventId);
    }
  }

  Future<TransactionDetails> _details(String transactionId) async =>
      (await MockTransactionQueryRepository(demoViewerId: actorId, store: store)
          .getTransactionDetails(transactionId))!;
}

// Sao chép PaymentConfirmation với các mốc mới (model dùng chung không có copyWith).
PaymentConfirmation copyPayment(
  PaymentConfirmation? base,
  String transactionId, {
  DateTime? buyerReportedAt,
  DateTime? sellerConfirmedAt,
  DateTime? refundReportedAt,
  DateTime? buyerRefundConfirmedAt,
}) =>
    PaymentConfirmation(
      transactionId: transactionId,
      buyerReportedAt: buyerReportedAt ?? base?.buyerReportedAt,
      sellerConfirmedAt: sellerConfirmedAt ?? base?.sellerConfirmedAt,
      refundReportedAt: refundReportedAt ?? base?.refundReportedAt,
      buyerRefundConfirmedAt:
          buyerRefundConfirmedAt ?? base?.buyerRefundConfirmedAt,
    );

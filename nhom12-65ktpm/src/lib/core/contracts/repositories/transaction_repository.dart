import '../command_result.dart';
import '../models/transaction.dart';

abstract interface class TransactionQueryRepository {
  Future<List<StudyTransaction>> getMyTransactions();
  Future<StudyTransaction?> getTransactionDetails(String transactionId);
  Future<List<TransactionEventItem>> getTimeline(String transactionId);
}

abstract interface class BorrowRepository {
  // Chỉ ghi ý định trả, không tự thay holder hay dueDate.
  Future<CommandResult<StudyTransaction>> requestReturn(
    String transactionId, {required String idempotencyKey});
}

abstract interface class SellerPaymentRepository {
  // A xác nhận đã thực nhận tiền; B self-report không mở Handover SELL.
  Future<CommandResult<StudyTransaction>> confirmSellerPayment(
    String transactionId, {required String idempotencyKey});
}

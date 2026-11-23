import '../command_result.dart';
import '../models/transaction.dart';

abstract interface class TransactionQueryRepository {
  // Chỉ giao dịch mà actor đăng nhập là A hoặc B.
  Future<List<TransactionDetails>> getMyTransactions();
  // null khi không tồn tại HOẶC không có quyền: không phân biệt để tránh lộ dữ liệu.
  Future<TransactionDetails?> getTransactionDetails(String transactionId);
  // Sự kiện server, sắp xếp tăng dần theo serverAt.
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

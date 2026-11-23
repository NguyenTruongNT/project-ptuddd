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

// Tiền SELL chuyển NGOÀI ứng dụng; các lệnh dưới chỉ ghi nhận xác nhận của người.
abstract interface class SellerPaymentRepository {
  // B báo "Tôi đã chuyển khoản": chỉ ghi buyer_reported_at, KHÔNG rời AWAITING_PAYMENT.
  Future<CommandResult<TransactionDetails>> reportBuyerTransfer(
    String transactionId, {required String idempotencyKey});

  // Chỉ A xác nhận đã thực nhận tiền -> AWAITING_HANDOVER (một lần duy nhất).
  Future<CommandResult<TransactionDetails>> confirmSellerPayment(
    String transactionId, {required String idempotencyKey});

  // Khi đang đề nghị hủy SELL đã nhận tiền: A báo đã hoàn tiền ngoài app.
  Future<CommandResult<TransactionDetails>> reportSellerRefund(
    String transactionId, {required String idempotencyKey});

  // Chỉ B xác nhận đã thực nhận đủ tiền hoàn.
  Future<CommandResult<TransactionDetails>> confirmRefundReceived(
    String transactionId, {required String idempotencyKey});
}

// Hủy Transaction cần A và B đồng thuận và không còn nghĩa vụ sách/tiền/Issue.
abstract interface class TransactionCancellationRepository {
  Future<CommandResult<TransactionDetails>> proposeCancellation(
    String transactionId, String reason, {required String idempotencyKey});

  // Người đề nghị tự rút lại.
  Future<CommandResult<TransactionDetails>> withdrawCancellation(
    String transactionId, {required String idempotencyKey});

  // Bên còn lại không đồng ý hủy.
  Future<CommandResult<TransactionDetails>> declineCancellation(
    String transactionId, {required String idempotencyKey});

  // Bên còn lại đồng ý; server chỉ CANCELLED khi hết nghĩa vụ.
  Future<CommandResult<TransactionDetails>> acceptCancellation(
    String transactionId, {required String idempotencyKey});
}

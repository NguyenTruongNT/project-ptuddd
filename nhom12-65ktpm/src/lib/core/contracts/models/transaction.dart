import '../domain_enums.dart';

class StudyTransaction {
  const StudyTransaction({
    required this.id,
    required this.listingId,
    required this.requestId,
    required this.materialId,
    required this.type,
    required this.ownerAtAcceptance,
    required this.receiverId,
    required this.status,
    this.agreedBorrowDays,
    this.agreedPriceVnd,
  });

  final String id;
  final String listingId;
  final String requestId;
  final String materialId;
  final OfferType type;
  final String ownerAtAcceptance;
  final String receiverId;
  final TransactionStatus status;
  final int? agreedBorrowDays;
  final int? agreedPriceVnd;
}

class BorrowingRecord {
  const BorrowingRecord({
    required this.transactionId,
    this.startedAt,
    this.dueDateVn,
    this.returnToCourierAt,
    this.reHandoverDueDateVn,
  });

  final String transactionId;
  final DateTime? startedAt;
  // Ngày yyyy-MM-dd theo lịch Việt Nam do server tính; KHÔNG tự cộng giờ UTC.
  final String? dueDateVn;
  final DateTime? returnToCourierAt;
  final String? reHandoverDueDateVn;
}

class PaymentConfirmation {
  const PaymentConfirmation({
    required this.transactionId,
    this.buyerReportedAt,
    this.sellerConfirmedAt,
    this.refundReportedAt,
    this.buyerRefundConfirmedAt,
  });

  final String transactionId;
  final DateTime? buyerReportedAt;
  final DateTime? sellerConfirmedAt;
  // A báo đã hoàn tiền NGOÀI ứng dụng (cột refund_proposed_at).
  final DateTime? refundReportedAt;
  // Chỉ B xác nhận đã thực nhận tiền hoàn; app không tự chuyển/hoàn tiền.
  final DateTime? buyerRefundConfirmedAt;

  // B báo đã chuyển tiền KHÔNG tương đương A đã xác nhận nhận tiền.
  bool get isSellerConfirmed => sellerConfirmedAt != null;

  // Đã nhận tiền mà chưa được B xác nhận hoàn lại -> còn nghĩa vụ tiền khi hủy.
  bool get hasOutstandingRefund =>
      sellerConfirmedAt != null && buyerRefundConfirmedAt == null;
}

// Đề nghị hủy Transaction đang chờ bên còn lại phản hồi (BR-45).
// Một bên đề nghị không đủ để hủy; server kiểm tra đồng thuận + nghĩa vụ.
class CancellationProposal {
  const CancellationProposal({
    required this.proposedBy,
    required this.reason,
    required this.proposedAt,
  });

  final TransactionViewerRole proposedBy;
  final String reason;
  final DateTime proposedAt;
}

class TransactionEventItem {
  const TransactionEventItem({
    required this.id,
    required this.transactionId,
    required this.eventType,
    required this.serverAt,
    required this.safeDescription,
    this.actorDisplay,
  });

  final String id;
  final String transactionId;
  final String eventType;
  final DateTime serverAt;
  final String safeDescription;
  // Tên hiển thị snapshot của actor do server cung cấp; null khi do hệ thống.
  final String? actorDisplay;
}

// Hành động mà server GỢI Ý cho actor hiện tại (CONTRACTS.md §3).
// UI chỉ dùng để bật/tắt nút; RPC luôn kiểm tra lại quyền và trạng thái.
enum TransactionAction {
  confirmSellerPayment('CAN_CONFIRM_SELLER_PAYMENT'),
  reportBuyerTransfer('CAN_REPORT_BUYER_TRANSFER'),
  startHandover('CAN_START_HANDOVER'),
  requestReturn('CAN_REQUEST_RETURN'),
  reportIssue('CAN_REPORT_ISSUE'),
  proposeCancellation('CAN_PROPOSE_CANCELLATION'),
  withdrawCancellation('CAN_WITHDRAW_CANCELLATION'),
  respondCancellation('CAN_RESPOND_CANCELLATION'),
  reportSellerRefund('CAN_REPORT_SELLER_REFUND'),
  confirmRefundReceived('CAN_CONFIRM_REFUND_RECEIVED');

  const TransactionAction(this.wire);
  final String wire;

  static TransactionAction fromWire(String raw) {
    for (final value in values) {
      if (value.wire == raw) return value;
    }
    throw FormatException('Hành động giao dịch không hợp lệ: $raw');
  }
}

// Vai trò của người đang xem trong giao dịch, do server suy ra từ auth.uid().
// Không dùng globalRole; C không xem toàn bộ Transaction qua DTO này.
enum TransactionViewerRole { owner, receiver }

// Read model cho SCR-13/SCR-14. Không chứa holderId, QR token,
// thông tin ngân hàng hay đường dẫn ảnh private.
class TransactionDetails {
  const TransactionDetails({
    required this.transaction,
    required this.materialTitle,
    required this.materialSubject,
    required this.ownerDisplayName,
    required this.receiverDisplayName,
    required this.viewerRole,
    required this.createdAt,
    this.borrowing,
    this.payment,
    this.openIssueCount = 0,
    this.cancellationProposal,
    this.allowedActions = const {},
  });

  final StudyTransaction transaction;
  final String materialTitle;
  final String materialSubject;
  final String ownerDisplayName;
  final String receiverDisplayName;
  final TransactionViewerRole viewerRole;
  final DateTime createdAt;
  final BorrowingRecord? borrowing; // Chỉ BORROW.
  final PaymentConfirmation? payment; // Chỉ SELL.
  final int openIssueCount;
  final CancellationProposal? cancellationProposal; // Đề nghị hủy đang chờ.
  final Set<TransactionAction> allowedActions;

  String get id => transaction.id;

  bool can(TransactionAction action) => allowedActions.contains(action);
}

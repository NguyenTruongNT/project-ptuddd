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
  });

  final String transactionId;
  final DateTime? buyerReportedAt;
  final DateTime? sellerConfirmedAt;

  // B báo đã chuyển tiền KHÔNG tương đương A đã xác nhận nhận tiền.
  bool get isSellerConfirmed => sellerConfirmedAt != null;
}

class TransactionEventItem {
  const TransactionEventItem({
    required this.id,
    required this.transactionId,
    required this.eventType,
    required this.serverAt,
    required this.safeDescription,
  });

  final String id;
  final String transactionId;
  final String eventType;
  final DateTime serverAt;
  final String safeDescription;
}

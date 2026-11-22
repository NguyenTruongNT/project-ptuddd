import '../domain_enums.dart';

class ExchangeRequest {
  const ExchangeRequest({
    required this.id,
    required this.listingId,
    required this.requesterId,
    required this.status,
    required this.createdAt,
    this.requestedBorrowDays,
  });

  final String id;
  final String listingId;
  final String requesterId;
  final ExchangeRequestStatus status;
  final DateTime createdAt; // Thời gian server, không lấy đồng hồ máy.
  final int? requestedBorrowDays; // Khi BORROW phải thuộc 1..30, server xác thực.
}

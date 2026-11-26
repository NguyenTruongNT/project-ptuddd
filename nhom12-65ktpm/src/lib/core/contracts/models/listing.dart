import '../domain_enums.dart';

// Listing là một lần đăng BORROW / SELL / DONATE cho Material.
class Listing {
  const Listing({
    required this.id,
    required this.materialId,
    required this.offerType,
    required this.status,
    this.askingPriceVnd,
    this.revision = 1,
    this.description,
    this.meetingArea,
  });

  final String id;
  final String materialId;
  final OfferType offerType;
  final ListingStatus status;
  final int? askingPriceVnd;
  final int revision;
  final String? description;
  final String? meetingArea;
}

// DTO công khai cho Explore. isRequestable là GỢI Ý UI từ server/read model;
// RPC createRequest luôn phải xác thực lại quyền và tính khả dụng.
class ListingCardModel {
  const ListingCardModel({
    required this.listingId,
    required this.materialId,
    required this.title,
    required this.subject,
    required this.offerType,
    required this.isRequestable,
    required this.isReserved,
    this.coverUrl,
    this.askingPriceVnd,
    this.condition = '',
    this.publishedAt,
    this.isOwner = false,
    this.hasPendingRequest = false,
  });

  final String listingId;
  final String materialId;
  final String title;
  final String subject;
  final OfferType offerType;
  final bool isRequestable;
  final bool isReserved; // Nhãn dẫn xuất, KHÔNG phải Listing.status.
  final String? coverUrl;
  final int? askingPriceVnd;
  final String condition;
  final DateTime? publishedAt;
  final bool isOwner;
  final bool hasPendingRequest;
}

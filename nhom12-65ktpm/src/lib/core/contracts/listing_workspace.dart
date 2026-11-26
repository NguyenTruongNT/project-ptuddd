import 'command_result.dart';
import 'domain_enums.dart';
import 'models/listing.dart';
import 'repositories/listing_repository.dart';

enum ListingAction { draft, publish, hide, show }

// Một ý định ghi giữ nguyên payload, revisions và key khi retry.
class ListingCommand {
  const ListingCommand({
    required this.action,
    required this.materialId,
    required this.idempotencyKey,
    this.listingId,
    this.expectedRevision,
    this.expectedMaterialRevision,
    this.offerType,
    this.askingPriceVnd,
    this.description,
    this.meetingArea,
  });
  final ListingAction action;
  final String materialId;
  final String? listingId;
  final String idempotencyKey;
  final int? expectedRevision;
  final int? expectedMaterialRevision;
  final OfferType? offerType;
  final int? askingPriceVnd;
  final String? description;
  final String? meetingArea;
  Map<String, dynamic> toRpc() => {
    'p_action': action.name,
    'p_material_id': materialId,
    'p_listing_id': listingId,
    'p_expected_revision': expectedRevision,
    'p_expected_material_revision': expectedMaterialRevision,
    'p_idempotency_key': idempotencyKey,
    'p_payload': action == ListingAction.hide || action == ListingAction.show
        ? <String, dynamic>{}
        : {
            'offer_type': offerType?.wire,
            'asking_price_vnd': askingPriceVnd,
            'description': description,
            'meeting_area': meetingArea,
          },
  };
  factory ListingCommand.fromRpc(Map<String, dynamic> v) {
    final p = Map<String, dynamic>.from(v['p_payload'] as Map);
    return ListingCommand(
      action: ListingAction.values.byName(v['p_action'] as String),
      materialId: v['p_material_id'] as String,
      listingId: v['p_listing_id'] as String?,
      idempotencyKey: v['p_idempotency_key'] as String,
      expectedRevision: (v['p_expected_revision'] as num?)?.toInt(),
      expectedMaterialRevision: (v['p_expected_material_revision'] as num?)
          ?.toInt(),
      offerType: p['offer_type'] == null
          ? null
          : OfferType.fromWire(p['offer_type'] as String),
      askingPriceVnd: (p['asking_price_vnd'] as num?)?.toInt(),
      description: p['description'] as String?,
      meetingArea: p['meeting_area'] as String?,
    );
  }
}

class ManagedListing {
  const ManagedListing({
    required this.listing,
    required this.materialRevision,
    this.title = '',
    this.coverUrl,
    this.canEdit = false,
    this.canHide = false,
    this.canShow = false,
    this.hasActiveTransaction = false,
    this.hasPendingRequests = false,
  });
  final Listing listing;
  final int materialRevision;
  final String title;
  // URL ký ngắn hạn chỉ dùng để hiển thị, không lưu vào nháp hoặc snapshot.
  final String? coverUrl;
  final bool canEdit;
  final bool canHide;
  final bool canShow;
  final bool hasActiveTransaction;
  final bool hasPendingRequests;
}

class ListingImage {
  const ListingImage({required this.id, this.url});
  final String id;
  final String? url;
}

// Chính sách chung BR-20, không phải cấu hình riêng do chủ tin nhập.
// Constructor private giữ một nguồn quy tắc cho cả dữ liệu thật và mock.
final class BorrowPolicy {
  const BorrowPolicy._();
  static const mvp = BorrowPolicy._();

  int get minDays => 1;
  int get maxDays => 30;
  bool get requesterProposesDays => true;
  bool get ownerMustAcceptRequestedDays => true;
  bool get allowsExtension => false;

  // UI kiểm tra sớm; RPC Request vẫn phải xác thực lại số ngày tại server.
  bool acceptsDays(int? days) =>
      days != null && days >= minDays && days <= maxDays;
}

// Projection cho Khanh/SCR-06: không QR/holder/private path.
class ListingDetails {
  const ListingDetails({
    required this.card,
    required this.ownerId,
    required this.ownerName,
    this.images = const [],
    this.materialDescription,
    this.description,
    this.meetingArea,
    this.isbn,
  });
  final ListingCardModel card;
  final String ownerId;
  final String ownerName;
  final List<ListingImage> images;
  final String? materialDescription;
  final String? description;
  final String? meetingArea;
  final String? isbn;
  // Dẫn xuất từ offer để SELL/DONATE không mang nhầm chính sách BORROW.
  // Không cần thêm cột Listing hoặc thay payload RPC cho quy tắc chung này.
  BorrowPolicy? get borrowPolicy =>
      card.offerType == OfferType.borrow ? BorrowPolicy.mvp : null;

  String get requestBlockedReason => card.isOwner
      ? 'OWNER'
      : card.isReserved
      ? 'RESERVED'
      : card.hasPendingRequest
      ? 'REQUEST_PENDING'
      : card.isRequestable
      ? ''
      : 'MATERIAL_UNAVAILABLE';
}

class ListingPage<T> {
  const ListingPage(this.items, {required this.hasMore});
  final List<T> items;
  final bool hasMore;
}

abstract interface class ListingWorkspaceRepository
    implements ListingRepository, ListingQueryRepository {
  Future<ManagedListing?> getManaged({String? listingId, String? materialId});
  Future<ListingPage<ManagedListing>> searchMine({
    String status = 'all',
    String query = '',
    int offset = 0,
    int limit = 20,
  });
  Future<CommandResult<ManagedListing>> execute(ListingCommand command);
  Future<CommandResult<ManagedListing>?> getCommandResult(
    ListingCommand command,
  );
  // SCR-06 đọc projection công khai này; không ghép bằng getMyMaterial của owner.
  // Null khi tin không còn công khai; lỗi backend được trả qua AppError.
  Future<ListingDetails?> getPublishedDetails(String listingId);
  Future<ListingPage<ListingCardModel>> searchPage({
    String keyword = '',
    int offset = 0,
    int limit = 20,
  });
}

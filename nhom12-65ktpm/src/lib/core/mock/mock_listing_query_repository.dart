import '../contracts/domain_enums.dart';
import '../contracts/models/models.dart';
import '../contracts/repositories/listing_repository.dart';
import 'mock_fixtures.dart';

// Mock CHỈ ĐỌC cho Explore: không tạo transaction hay thay trạng thái.
class MockListingQueryRepository implements ListingQueryRepository {
  const MockListingQueryRepository({this.demoViewerId = MockFixtures.outsider});
  final String demoViewerId;

  @override
  Future<List<ListingCardModel>> searchPublished({String keyword = ''}) async {
    final normalized = keyword.trim().toLowerCase();
    final cards = <ListingCardModel>[];

    for (final listing in MockFixtures.listings) {
      if (listing.status != ListingStatus.published) continue;
      final material = MockFixtures.materials.firstWhere(
        (item) => item.id == listing.materialId,
      );
      if (normalized.isNotEmpty &&
          !material.title.toLowerCase().contains(normalized) &&
          !material.subject.toLowerCase().contains(normalized)) {
        continue;
      }

      // RESERVED là trạng thái dẫn xuất khi tồn tại giao dịch chưa kết thúc.
      final reserved = MockFixtures.transactions.any(
        (txn) => txn.materialId == material.id && !txn.status.isTerminal,
      );
      // Giữ cùng ý nghĩa với projection server: chủ tin và người có PENDING
      // không được gửi yêu cầu mới, dù Material chưa có giao dịch active.
      final isOwner = material.ownerId == demoViewerId;
      final hasPendingRequest = MockFixtures.requests.any(
        (request) =>
            request.listingId == listing.id &&
            request.requesterId == demoViewerId &&
            request.status == ExchangeRequestStatus.pending,
      );
      cards.add(
        ListingCardModel(
          listingId: listing.id,
          materialId: material.id,
          title: material.title,
          subject: material.subject,
          condition: material.condition,
          coverUrl: MockFixtures.listingImages[listing.id]?.firstOrNull?.url,
          offerType: listing.offerType,
          askingPriceVnd: listing.askingPriceVnd,
          isReserved: reserved,
          isOwner: isOwner,
          hasPendingRequest: hasPendingRequest,
          isRequestable:
              !isOwner &&
              !reserved &&
              !hasPendingRequest &&
              material.ownerId == material.holderId,
        ),
      );
    }
    return List.unmodifiable(cards);
  }

  @override
  Future<ListingCardModel?> getPublishedCard(String listingId) async {
    final cards = await searchPublished();
    for (final card in cards) {
      if (card.listingId == listingId) return card;
    }
    return null;
  }
}

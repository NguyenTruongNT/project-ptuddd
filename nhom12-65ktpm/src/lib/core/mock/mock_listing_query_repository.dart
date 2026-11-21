import '../contracts/domain_enums.dart';
import '../contracts/models/models.dart';
import '../contracts/repositories/listing_repository.dart';
import 'mock_fixtures.dart';

// Mock CHỈ ĐỌC cho Explore: không tạo transaction hay thay trạng thái.
class MockListingQueryRepository implements ListingQueryRepository {
  const MockListingQueryRepository();

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
      cards.add(ListingCardModel(
        listingId: listing.id,
        materialId: material.id,
        title: material.title,
        subject: material.subject,
        offerType: listing.offerType,
        askingPriceVnd: listing.askingPriceVnd,
        isReserved: reserved,
        isRequestable: !reserved,
      ));
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

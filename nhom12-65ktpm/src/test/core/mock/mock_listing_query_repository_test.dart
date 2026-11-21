import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/mock/mock_listing_query_repository.dart';

void main() {
  const repository = MockListingQueryRepository();

  test('Listing PUBLISHED nhưng RESERVED vẫn hiện, không thể request', () async {
    final cards = await repository.searchPublished();
    final borrow = cards.singleWhere((item) => item.listingId == 'list-borrow-01');
    expect(borrow.isReserved, true);
    expect(borrow.isRequestable, false);
  });

  test('Listing DONATE chưa được giữ vẫn có thể request trên UI', () async {
    final card = await repository.getPublishedCard('list-donate-01');
    expect(card, isNotNull);
    expect(card!.isReserved, false);
    expect(card.isRequestable, true);
  });

  test('Tìm theo tên hoặc môn học, không lộ dữ liệu bí mật', () async {
    final cards = await repository.searchPublished(keyword: 'python');
    expect(cards.length, 1);
    expect(cards.first.title, 'Nhập môn Python');
    expect(cards.first.isReserved, true);
    // Không có trường qrToken hay đường dẫn ảnh minh chứng trong ListingCardModel.
  });
}

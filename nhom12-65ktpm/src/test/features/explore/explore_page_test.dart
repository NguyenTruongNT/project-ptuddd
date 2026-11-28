import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/listing.dart';
import 'package:studyshare/core/contracts/repositories/listing_repository.dart';
import 'package:studyshare/core/providers/mock_query_providers.dart';
import 'package:studyshare/features/explore/presentation/explore_page.dart';

void main() {
  const fixtures = <ListingCardModel>[
    ListingCardModel(
      listingId: 'listing-borrow',
      materialId: 'material-borrow',
      title: 'Giáo trình Giải tích',
      subject: 'Toán cao cấp',
      offerType: OfferType.borrow,
      isRequestable: false,
      isReserved: true,
    ),
    ListingCardModel(
      listingId: 'listing-sell',
      materialId: 'material-sell',
      title: 'Nhập môn Python',
      subject: 'Lập trình',
      offerType: OfferType.sell,
      askingPriceVnd: 90000,
      isRequestable: true,
      isReserved: false,
    ),
    ListingCardModel(
      listingId: 'listing-donate',
      materialId: 'material-donate',
      title: 'Cấu trúc dữ liệu',
      subject: 'CNTT',
      offerType: OfferType.donate,
      isRequestable: true,
      isReserved: false,
    ),
  ];

  Future<void> pumpExplorePage(
    WidgetTester tester, {
    ListingQueryRepository? repository,
    Size size = const Size(400, 800),
  }) async {
    await tester.binding.setSurfaceSize(size);

    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          listingQueryRepositoryProvider.overrideWithValue(
            repository ?? const FakeListingQueryRepository(listings: fixtures),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ExplorePage())),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('hiển thị danh sách tin đăng và trạng thái khả dụng', (
    WidgetTester tester,
  ) async {
    await pumpExplorePage(tester);

    expect(find.text('Khám phá tài liệu'), findsOneWidget);

    expect(find.text('Giáo trình Giải tích'), findsOneWidget);

    expect(find.text('Nhập môn Python'), findsOneWidget);

    expect(find.text('Cấu trúc dữ liệu'), findsOneWidget);

    expect(find.text('Đã giữ chỗ'), findsOneWidget);

    expect(find.text('Có thể yêu cầu'), findsNWidgets(2));
  });

  testWidgets('hiển thị đúng hình thức và giá bán', (
    WidgetTester tester,
  ) async {
    await pumpExplorePage(tester);

    expect(find.text('Cho mượn'), findsOneWidget);

    expect(find.text('Bán lại'), findsOneWidget);

    expect(find.text('Tặng miễn phí'), findsOneWidget);

    expect(find.text('90.000 đ'), findsOneWidget);
  });

  testWidgets('lọc chỉ các tin cho mượn', (WidgetTester tester) async {
    await pumpExplorePage(tester);

    await tester.tap(find.byKey(const ValueKey('explore-filter-borrow')));

    await tester.pumpAndSettle();

    expect(find.text('Giáo trình Giải tích'), findsOneWidget);

    expect(find.text('Nhập môn Python'), findsNothing);

    expect(find.text('Cấu trúc dữ liệu'), findsNothing);
  });

  testWidgets('lọc chỉ các tin tặng miễn phí', (WidgetTester tester) async {
    await pumpExplorePage(tester);

    await tester.tap(find.byKey(const ValueKey('explore-filter-donate')));

    await tester.pumpAndSettle();

    expect(find.text('Cấu trúc dữ liệu'), findsOneWidget);

    expect(find.text('Giáo trình Giải tích'), findsNothing);

    expect(find.text('Nhập môn Python'), findsNothing);
  });

  testWidgets('tìm theo tên tài liệu', (WidgetTester tester) async {
    await pumpExplorePage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('explore-search')),
      'Python',
    );

    // ExplorePage debounce tìm kiếm trong 350 ms.
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Nhập môn Python'), findsOneWidget);

    expect(find.text('Giáo trình Giải tích'), findsNothing);

    expect(find.text('Cấu trúc dữ liệu'), findsNothing);
  });

  testWidgets('tìm theo môn học không phân biệt hoa thường', (
    WidgetTester tester,
  ) async {
    await pumpExplorePage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('explore-search')),
      'toán CAO cấp',
    );

    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Giáo trình Giải tích'), findsOneWidget);

    expect(find.text('Nhập môn Python'), findsNothing);
  });

  testWidgets('hiển thị empty state khi không có kết quả phù hợp', (
    WidgetTester tester,
  ) async {
    await pumpExplorePage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('explore-search')),
      'Không tồn tại',
    );

    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Không tìm thấy tài liệu phù hợp.'), findsOneWidget);
  });

  testWidgets('hiển thị empty state khi repository trả danh sách rỗng', (
    WidgetTester tester,
  ) async {
    await pumpExplorePage(
      tester,
      repository: const FakeListingQueryRepository(
        listings: <ListingCardModel>[],
      ),
    );

    expect(find.text('Chưa có tin đăng công khai.'), findsOneWidget);
  });

  testWidgets('hiển thị lỗi an toàn và cho phép thử lại', (
    WidgetTester tester,
  ) async {
    await pumpExplorePage(
      tester,
      repository: const FailingListingQueryRepository(),
    );

    expect(
      find.text('Không tải được dữ liệu. Vui lòng thử lại.'),
      findsOneWidget,
    );

    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('không tràn giao diện ở kích thước mobile', (
    WidgetTester tester,
  ) async {
    await pumpExplorePage(tester, size: const Size(360, 800));

    expect(tester.takeException(), isNull);

    expect(find.text('Khám phá tài liệu'), findsOneWidget);
  });
}

class FakeListingQueryRepository implements ListingQueryRepository {
  const FakeListingQueryRepository({required this.listings});

  final List<ListingCardModel> listings;

  @override
  Future<List<ListingCardModel>> searchPublished({String keyword = ''}) async {
    return List<ListingCardModel>.unmodifiable(listings);
  }

  @override
  Future<ListingCardModel?> getPublishedCard(String listingId) async {
    for (final listing in listings) {
      if (listing.listingId == listingId) {
        return listing;
      }
    }

    return null;
  }
}

class FailingListingQueryRepository implements ListingQueryRepository {
  const FailingListingQueryRepository();

  @override
  Future<List<ListingCardModel>> searchPublished({String keyword = ''}) {
    throw StateError('Lỗi kỹ thuật giả lập không được hiển thị.');
  }

  @override
  Future<ListingCardModel?> getPublishedCard(String listingId) {
    throw StateError('Lỗi kỹ thuật giả lập không được hiển thị.');
  }
}

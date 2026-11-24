import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';
import 'package:studyshare/core/providers/mock_query_providers.dart';

void main() {
  test('Danh sách tin đăng mock có thể đọc công khai', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final listings = await container.read(publishedListingsProvider.future);
    expect(listings, isNotEmpty);
    // Vẫn hiển thị tin đã đặt nhưng không cho gửi Request.
    expect(
      listings.any((item) => item.isReserved && !item.isRequestable),
      isTrue,
    );
  });

  test('Người ngoài không đọc được tài liệu và giao dịch của A', () async {
    final container = ProviderContainer(
      overrides: [
        demoViewerIdProvider.overrideWith((ref) => MockFixtures.outsider),
      ],
    );
    addTearDown(container.dispose);
    final materials = await container.read(myMaterialsPreviewProvider.future);
    final transactions = await container.read(
      myTransactionsPreviewProvider.future,
    );
    expect(materials, isEmpty);
    expect(transactions, isEmpty);
  });

  test('Tài khoản A đọc được dữ liệu mock của chính mình', () async {
    final container = ProviderContainer(
      overrides: [
        demoViewerIdProvider.overrideWith((ref) => MockFixtures.userA),
      ],
    );
    addTearDown(container.dispose);
    final materials = await container.read(myMaterialsPreviewProvider.future);
    expect(materials, isNotEmpty);
  });
}

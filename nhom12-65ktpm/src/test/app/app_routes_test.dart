import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/app/app_routes.dart';

void main() {
  test('Danh mục có đúng 26 màn hình và không lặp mã SCR', () {
    expect(AppRoutes.screens, hasLength(26));
    expect(AppRoutes.screens.first.code, 'SCR-01');
    expect(AppRoutes.screens.last.code, 'SCR-26');
    final codes = AppRoutes.screens.map((screen) => screen.code).toSet();
    expect(codes.length, 26);
  });

  test('Đường dẫn chi tiết truyền đúng ID thử nghiệm', () {
    expect(AppRoutes.listingDetails('abc'), '/listings/abc');
    expect(AppRoutes.transactionDetails('txn-01'), '/transactions/txn-01');
    expect(AppRoutes.materialDetails('mat 01'), '/materials/mat%2001');
  });

  test('Mỗi màn hình có đường dẫn preview', () {
    for (final screen in AppRoutes.screens) {
      expect(screen.previewPath, startsWith('/'));
    }
  });
}

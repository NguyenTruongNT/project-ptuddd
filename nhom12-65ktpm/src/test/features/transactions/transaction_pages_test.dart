import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';
import 'package:studyshare/core/providers/mock_query_providers.dart';
import 'package:studyshare/features/transactions/presentation/my_transactions_page.dart';
import 'package:studyshare/features/transactions/presentation/transaction_details_page.dart';
import 'package:studyshare/features/transactions/providers/transaction_providers.dart';
import 'package:studyshare/l10n/app_localizations.dart';

// Router tối giản: chỉ hai màn của module, tránh animation của trang chủ.
Widget _app({required String viewer, required String initial, DateTime? nowUtc}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/transactions',
        builder: (context, state) => const Scaffold(body: MyTransactionsPage()),
      ),
      GoRoute(
        path: '/transactions/:transactionId',
        builder: (context, state) => TransactionDetailsPage(
          transactionId: state.pathParameters['transactionId']!,
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      workflowRpcProvider.overrideWithValue(null),
      demoViewerIdProvider.overrideWith((ref) => viewer),
      nowUtcProvider.overrideWith(
        (ref) => () => nowUtc ?? DateTime.utc(2026, 11, 23, 3),
      ),
    ],
    child: MaterialApp.router(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  group('SCR-13 Giao dịch của tôi', () {
    testWidgets('A thấy 3 tab và các giao dịch đang xử lý', (tester) async {
      await tester.pumpWidget(_app(viewer: MockFixtures.userA, initial: '/transactions'));
      await tester.pumpAndSettle();

      expect(find.text('Đang xử lý'), findsOneWidget);
      expect(find.text('Đã kết thúc'), findsOneWidget);
      expect(find.text('Có sự cố'), findsOneWidget);
      expect(find.text('Nhập môn Python'), findsOneWidget);
      expect(find.text('Giáo trình Giải tích'), findsOneWidget);
      expect(find.text('Cấu trúc dữ liệu'), findsNothing); // Chưa có Transaction.
      expect(find.text('Mạng máy tính'), findsOneWidget);
    });

    testWidgets('Người ngoài chỉ thấy empty state, không lộ giao dịch', (tester) async {
      await tester.pumpWidget(_app(viewer: MockFixtures.outsider, initial: '/transactions'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Chưa có giao dịch đang xử lý'), findsOneWidget);
      expect(find.text('Nhập môn Python'), findsNothing);
    });

    testWidgets('Chạm card mở SCR-14 của đúng giao dịch', (tester) async {
      await tester.pumpWidget(_app(viewer: MockFixtures.userA, initial: '/transactions'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nhập môn Python'));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết giao dịch'), findsOneWidget);
      expect(find.text('Thanh toán (ngoài ứng dụng)'), findsOneWidget);
    });
  });

  group('SCR-14 Chi tiết giao dịch', () {
    testWidgets('SELL: B báo chuyển khoản vẫn là chờ A xác nhận, bàn giao bị khóa',
        (tester) async {
      await tester.pumpWidget(
          _app(viewer: MockFixtures.userA, initial: '/transactions/txn-sell-01'));
      await tester.pumpAndSettle();

      expect(find.text('90.000 đ'), findsOneWidget);
      expect(find.textContaining('Chưa có xác nhận của người bán'), findsOneWidget);
      expect(find.textContaining('Mọi bàn giao bị khóa'), findsOneWidget);
      expect(find.textContaining('thành công'), findsNothing);
      // BR-29: không có nút tạo bàn giao trước khi A xác nhận tiền.
      expect(find.text('Tạo nhiệm vụ giao hộ'), findsNothing);
    });

    testWidgets('BORROW: hiện hạn trả 28/11 và timeline theo giờ Việt Nam',
        (tester) async {
      await tester.pumpWidget(
          _app(viewer: MockFixtures.userB, initial: '/transactions/txn-borrow-01'));
      await tester.pumpAndSettle();

      expect(find.textContaining('28/11/2026 (hết ngày'), findsOneWidget);
      expect(find.text('Quá hạn'), findsNothing);
      await tester.scrollUntilVisible(find.text('Lịch sử giao dịch'), 200);
      expect(find.text('A đã duyệt yêu cầu mượn.'), findsOneWidget);
      expect(find.textContaining('16:00 21/11/2026'), findsWidgets);
    });

    testWidgets('BORROW sau hạn: hiện nhãn Quá hạn', (tester) async {
      await tester.pumpWidget(_app(
        viewer: MockFixtures.userB,
        initial: '/transactions/txn-borrow-01',
        nowUtc: DateTime.utc(2026, 11, 28, 17), // 00:00 29/11 giờ VN.
      ));
      await tester.pumpAndSettle();

      expect(find.text('Quá hạn'), findsOneWidget);
    });

    testWidgets('Id lạ hoặc không có quyền: thông báo chung, không lộ dữ liệu',
        (tester) async {
      await tester.pumpWidget(
          _app(viewer: MockFixtures.outsider, initial: '/transactions/txn-sell-01'));
      await tester.pumpAndSettle();

      expect(find.text(TransactionDetailsPage.noAccessMessage), findsOneWidget);
      expect(find.text('Nhập môn Python'), findsNothing);
    });
  });
}

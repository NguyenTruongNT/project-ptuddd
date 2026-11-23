import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';
import 'package:studyshare/core/mock/mock_transaction_store.dart';
import 'package:studyshare/core/providers/mock_query_providers.dart';
import 'package:studyshare/features/transactions/data/mock_command_runner.dart';
import 'package:studyshare/features/transactions/data/mock_transaction_cancellation_repository.dart';
import 'package:studyshare/features/transactions/presentation/transaction_details_page.dart';
import 'package:studyshare/l10n/app_localizations.dart';

Widget _detailsApp({
  required String viewer,
  required String transactionId,
  MockTransactionStore? store,
}) {
  final router = GoRouter(
    initialLocation: '/transactions/$transactionId',
    routes: [
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
      demoViewerIdProvider.overrideWith((ref) => viewer),
      if (store != null) mockTransactionStoreProvider.overrideWith((ref) => store),
    ],
    child: MaterialApp.router(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

// Màn hình cao để toàn bộ SCR-14 hiển thị, không phụ thuộc vị trí cuộn.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('A xác nhận tiền qua hộp thoại, sau ACK mới mở bàn giao', (tester) async {
    _tallView(tester);
    await tester.pumpWidget(
        _detailsApp(viewer: MockFixtures.userA, transactionId: 'txn-sell-01'));
    await tester.pumpAndSettle();

    expect(find.text('Tạo nhiệm vụ giao hộ'), findsNothing);
    await tester.tap(find.text('Xác nhận đã nhận tiền'));
    await tester.pumpAndSettle();
    expect(find.textContaining('StudyShare không kiểm tra giao dịch ngân hàng.'),
        findsWidgets);

    // Bấm "Để sau" thì không có gì thay đổi.
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    expect(find.text('Chờ xác nhận tiền'), findsOneWidget);

    await tester.tap(find.text('Xác nhận đã nhận tiền'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã nhận đủ tiền'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Đã ghi nhận bạn nhận đủ tiền'), findsOneWidget);
    expect(find.text('Chờ bàn giao'), findsOneWidget);
    expect(find.text('Xác nhận đã nhận tiền'), findsNothing);
    expect(find.text('Tạo nhiệm vụ giao hộ'), findsOneWidget);
    expect(find.textContaining('Người bán xác nhận đã nhận đủ tiền'), findsOneWidget);
  });

  testWidgets('B không có nút xác nhận tiền thay người bán', (tester) async {
    _tallView(tester);
    await tester.pumpWidget(
        _detailsApp(viewer: MockFixtures.userB, transactionId: 'txn-sell-01'));
    await tester.pumpAndSettle();

    expect(find.text('Xác nhận đã nhận tiền'), findsNothing);
    // B đã báo chuyển khoản trong fixture nên không có nút báo lại.
    expect(find.text('Tôi đã chuyển khoản'), findsNothing);
  });

  testWidgets('B đề nghị hủy: bắt buộc lý do, sau ACK hiện thẻ đề nghị', (tester) async {
    _tallView(tester);
    await tester.pumpWidget(
        _detailsApp(viewer: MockFixtures.userB, transactionId: 'txn-sell-01'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đề nghị hủy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nếu tiền đã chuyển'), findsOneWidget);

    await tester.tap(find.text('Gửi đề nghị'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập lý do hủy.'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('cancellation-reason')), 'Đã mua được sách khác');
    await tester.tap(find.text('Gửi đề nghị'));
    await tester.pumpAndSettle();

    expect(find.text('Đang đề nghị hủy'), findsOneWidget);
    expect(find.textContaining('Bạn đã đề nghị hủy'), findsOneWidget);
    expect(find.text('Lý do: Đã mua được sách khác'), findsOneWidget);
    expect(find.text('Rút đề nghị hủy'), findsOneWidget);
    expect(find.text('Đồng ý hủy'), findsNothing); // Không tự đồng ý đề nghị của mình.
  });

  testWidgets('BORROW: B đồng ý hủy khi chưa trả sách bị server từ chối (AC-20)',
      (tester) async {
    _tallView(tester);
    final store = MockTransactionStore.fromFixtures();
    // A đề nghị hủy trước (cùng "server" mock).
    await MockTransactionCancellationRepository(
      MockCommandRunner(store: store, actorId: MockFixtures.userA),
    ).proposeCancellation('txn-borrow-01', 'Cần sách gấp', idempotencyKey: 'p');

    await tester.pumpWidget(_detailsApp(
      viewer: MockFixtures.userB,
      transactionId: 'txn-borrow-01',
      store: store,
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bên còn lại đề nghị hủy'), findsOneWidget);
    await tester.tap(find.text('Đồng ý hủy'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Đồng ý hủy').last);
    await tester.pumpAndSettle();

    expect(find.text('Tài liệu chưa được trả về người đăng.'), findsOneWidget);
    expect(find.text('Đang mượn'), findsOneWidget);
    expect(find.text('Đã hủy'), findsNothing);
  });
}

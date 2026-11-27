import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/models/notification_item.dart';
import 'package:studyshare/core/contracts/repositories/notification_repository.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';
import 'package:studyshare/core/mock/mock_transaction_store.dart';
import 'package:studyshare/core/providers/mock_query_providers.dart';
import 'package:studyshare/features/notifications/presentation/notifications_page.dart';
import 'package:studyshare/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:studyshare/features/notifications/providers/notification_providers.dart';
import 'package:studyshare/l10n/app_localizations.dart';

const a = MockFixtures.userA;

MockTransactionStore _store() => MockTransactionStore.fromFixtures(
      clock: () => DateTime.utc(2026, 11, 23, 3),
    );

// Router tối giản: hộp thư + màn đích giả để kiểm tra deep link.
Widget _app({
  required MockTransactionStore store,
  String viewer = a,
  String initial = '/notifications',
  List<Override> overrides = const [],
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => Scaffold(
          appBar: AppBar(actions: const [NotificationBell()]),
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/transactions/:transactionId',
        builder: (context, state) => Scaffold(
          body: Text('Giao dịch ${state.pathParameters['transactionId']}'),
        ),
      ),
      GoRoute(
        path: '/issues/:issueId',
        builder: (context, state) =>
            Scaffold(body: Text('Sự cố ${state.pathParameters['issueId']}')),
      ),
    ],
  );
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      workflowRpcProvider.overrideWithValue(null),
      demoViewerIdProvider.overrideWith((ref) => viewer),
      mockTransactionStoreProvider.overrideWith((ref) => store),
      ...overrides,
    ],
    child: MaterialApp.router(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

// Repository luôn lỗi mạng, để kiểm tra trạng thái lỗi + thử lại.
class _FailingQuery implements NotificationQueryRepository {
  int calls = 0;
  @override
  Future<List<AppNotification>> getMyNotifications() async {
    calls++;
    throw const AppError(DomainErrorCode.networkUnavailable,
        'Không thể tải dữ liệu. Kiểm tra kết nối và thử lại.');
  }
}

void main() {
  testWidgets('Hiện nhóm chưa đọc, chạm vào thì đánh dấu đã đọc và mở giao dịch',
      (tester) async {
    final store = _store();
    await tester.pumpWidget(_app(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Chưa đọc (1)'), findsOneWidget);
    expect(find.text('Người mua báo đã chuyển khoản'), findsOneWidget);
    expect(find.byKey(const ValueKey('notification-unread-dot')), findsOneWidget);

    await tester.tap(find.text('Người mua báo đã chuyển khoản'));
    await tester.pumpAndSettle();

    expect(find.text('Giao dịch txn-sell-01'), findsOneWidget);
    expect(store.notification('notice-a-01')!.isRead, isTrue);

    // Quay lại: thông báo nằm ở nhóm đã đọc, không còn chấm chưa đọc.
    final router = GoRouter.of(tester.element(find.text('Giao dịch txn-sell-01')));
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Đã đọc'), findsOneWidget);
    expect(find.textContaining('Chưa đọc'), findsNothing);
    expect(find.byKey(const ValueKey('notification-unread-dot')), findsNothing);
  });

  testWidgets('Thông báo Issue mở đúng màn sự cố', (tester) async {
    final store = _store()
      ..appendNotification(
        recipientId: a,
        type: 'ISSUE_OPENED',
        entityType: NotificationEntityType.issue,
        entityId: 'issue-mock-1',
        safePreview: 'Giáo trình Giải tích: Sự cố được mở.',
      );
    await tester.pumpWidget(_app(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Chưa đọc (2)'), findsOneWidget);
    await tester.tap(find.text('Có sự cố mới'));
    await tester.pumpAndSettle();
    expect(find.text('Sự cố issue-mock-1'), findsOneWidget);
  });

  testWidgets('Loại tài nguyên lạ: chỉ đánh dấu đã đọc, báo không mở được',
      (tester) async {
    final store = _store();
    final odd = store.appendNotification(
      recipientId: a,
      type: 'SOMETHING_NEW',
      entityType: NotificationEntityType.unknown,
      entityId: 'x',
      safePreview: 'Nội dung mới từ server.',
    );
    await tester.pumpWidget(_app(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nội dung mới từ server.'));
    await tester.pumpAndSettle();

    expect(find.text('Thông báo này không có nội dung để mở.'), findsOneWidget);
    expect(find.byType(NotificationsPage), findsOneWidget);
    expect(store.notification(odd.id)!.isRead, isTrue);
  });

  testWidgets('Đánh dấu tất cả đã đọc rồi nút bị tắt', (tester) async {
    final store = _store()
      ..appendNotification(
        recipientId: a,
        type: 'CANCELLATION_PROPOSED',
        entityType: NotificationEntityType.transaction,
        entityId: 'txn-sell-01',
        safePreview: 'Nhập môn Python: B đề nghị hủy giao dịch.',
      );
    await tester.pumpWidget(_app(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Đánh dấu tất cả đã đọc'));
    await tester.pumpAndSettle();

    expect(find.text('Đã đánh dấu 2 thông báo là đã đọc.'), findsOneWidget);
    expect(store.notificationsFor(a).every((n) => n.isRead), isTrue);
    final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.done_all));
    expect(button.onPressed, isNull);
  });

  testWidgets('Hộp thư trống hiện trạng thái rỗng', (tester) async {
    await tester.pumpWidget(
        _app(store: _store(), viewer: MockFixtures.userC));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có thông báo nào.'), findsOneWidget);
  });

  testWidgets('Lỗi mạng hiện thông điệp an toàn và cho thử lại', (tester) async {
    final failing = _FailingQuery();
    await tester.pumpWidget(_app(
      store: _store(),
      overrides: [
        notificationQueryRepositoryProvider.overrideWithValue(failing),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Không thể tải dữ liệu. Kiểm tra kết nối và thử lại.'),
        findsOneWidget);
    final before = failing.calls;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(failing.calls, greaterThan(before));
  });

  testWidgets('Chuông hiện số chưa đọc và mở hộp thư', (tester) async {
    final store = _store();
    await tester.pumpWidget(_app(store: store, initial: '/home'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Thông báo (1 chưa đọc)'), findsOneWidget);
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);

    await tester.tap(find.byType(NotificationBell));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsPage), findsOneWidget);

    // Đọc hết trong hộp thư rồi quay lại: badge biến mất.
    await tester.tap(find.byTooltip('Đánh dấu tất cả đã đọc'));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(NotificationsPage))).pop();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Thông báo'), findsOneWidget);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
  });

  testWidgets('Lỗi đánh dấu đã đọc vẫn mở nội dung và báo cho người dùng',
      (tester) async {
    final store = _store();
    await tester.pumpWidget(_app(
      store: store,
      overrides: [
        notificationRepositoryProvider.overrideWithValue(_TimeoutCommands()),
      ],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Người mua báo đã chuyển khoản'));
    await tester.pumpAndSettle();
    expect(find.text('Giao dịch txn-sell-01'), findsOneWidget);
    expect(find.textContaining('Chưa rõ máy chủ'), findsOneWidget);
    expect(store.notification('notice-a-01')!.isRead, isFalse);
  });
}

class _TimeoutCommands implements NotificationRepository {
  @override
  Future<CommandResult<AppNotification>> markRead(String notificationId,
          {required String idempotencyKey}) async =>
      const CommandError(DomainErrorCode.timeoutUnknown,
          'Chưa rõ máy chủ đã ghi nhận hay chưa.');

  @override
  Future<CommandResult<int>> markAllRead({required String idempotencyKey}) async =>
      const CommandError(DomainErrorCode.timeoutUnknown,
          'Chưa rõ máy chủ đã ghi nhận hay chưa.');
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/contracts/command_inputs.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/handover.dart';
import 'package:studyshare/core/contracts/models/issue.dart';
import 'package:studyshare/core/contracts/repositories/issue_repository.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';
import 'package:studyshare/core/mock/mock_transaction_store.dart';
import 'package:studyshare/core/providers/mock_query_providers.dart';
import 'package:studyshare/features/issues/data/mock_issue_command_runner.dart';
import 'package:studyshare/features/issues/data/mock_issue_repository.dart';
import 'package:studyshare/features/issues/presentation/create_issue_page.dart';
import 'package:studyshare/features/issues/presentation/issue_details_page.dart';
import 'package:studyshare/features/issues/presentation/issues_list_page.dart';
import 'package:studyshare/features/issues/providers/issue_providers.dart';
import 'package:studyshare/features/transactions/presentation/transaction_details_page.dart';
import 'package:studyshare/l10n/app_localizations.dart';

const _borrow = 'txn-borrow-01';

// Issue mẫu do B báo trên giao dịch mượn; dùng seed thay vì sửa fixture chung.
Issue _seedIssue() => Issue(
      id: 'issue-seed-1',
      transactionId: _borrow,
      reporterId: MockFixtures.userB,
      type: IssueType.wrongCondition,
      reason: 'Bìa sách bị rách.',
      status: IssueStatus.open,
      openedAt: DateTime.utc(2026, 11, 22, 2),
    );

MockTransactionStore _store({bool seeded = false}) =>
    MockTransactionStore.fromFixtures(
      clock: () => DateTime.utc(2026, 11, 23, 3),
      seedIssues: seeded ? [_seedIssue()] : null,
    );

// Router tối giản gồm các màn của module; /issues/new phải đứng trước /issues/:id.
Widget _app({
  required String viewer,
  required String initial,
  required MockTransactionStore store,
  List<Override> overrides = const [],
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/transactions/:transactionId',
        builder: (context, state) => TransactionDetailsPage(
            transactionId: state.pathParameters['transactionId']!),
      ),
      GoRoute(
        path: '/issues/new',
        builder: (context, state) => CreateIssuePage(
          transactionId: state.uri.queryParameters['transactionId'],
          handoverId: state.uri.queryParameters['handoverId'],
        ),
      ),
      GoRoute(
        path: '/issues',
        builder: (context, state) => const IssuesListPage(),
      ),
      GoRoute(
        path: '/issues/:issueId',
        builder: (context, state) =>
            IssueDetailsPage(issueId: state.pathParameters['issueId']!),
      ),
    ],
  );
  // UniqueKey: mỗi lần dựng là một "phiên" mới, không dùng lại cache provider cũ.
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

// Màn hình cao để toàn bộ trang hiển thị, không phụ thuộc vị trí cuộn.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

// Repository bọc ngoài: lần gọi reportIssue đầu server ĐÃ ghi nhưng client mất
// phản hồi (timeout), mô phỏng tình huống nguy hiểm nhất cho idempotency.
class _TimeoutOnceIssueRepository implements IssueRepository {
  _TimeoutOnceIssueRepository(this._inner);
  final IssueRepository _inner;
  final keys = <String>[];
  bool _failNext = true;

  @override
  Future<CommandResult<IssueDetails>> reportIssue(
    CreateIssueInput input, {required String idempotencyKey}) async {
    keys.add(idempotencyKey);
    final result =
        await _inner.reportIssue(input, idempotencyKey: idempotencyKey);
    if (_failNext) {
      _failNext = false;
      throw TimeoutException('mất phản hồi');
    }
    return result;
  }

  @override
  Future<CommandResult<IssueDetails>> proposeResolution(
    String issueId, String summary, {required String idempotencyKey}) =>
      _inner.proposeResolution(issueId, summary, idempotencyKey: idempotencyKey);

  @override
  Future<CommandResult<IssueDetails>> confirmResolution(
    String issueId, int resolutionRevision, {required String idempotencyKey}) =>
      _inner.confirmResolution(issueId, resolutionRevision,
          idempotencyKey: idempotencyKey);
}

void main() {
  group('SCR-21 Danh sách sự cố', () {
    testWidgets('Chưa có sự cố: hiện hướng dẫn, không có nút tạo tại đây',
        (tester) async {
      await tester.pumpWidget(_app(
          viewer: MockFixtures.userA, initial: '/issues', store: _store()));
      await tester.pumpAndSettle();

      expect(find.text('Đang mở'), findsWidgets); // Tab.
      expect(find.text('Đã giải quyết'), findsOneWidget);
      expect(find.textContaining('Không có sự cố nào đang mở'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('A thấy Issue của B, chạm card mở SCR-23', (tester) async {
      _tallView(tester);
      await tester.pumpWidget(_app(
          viewer: MockFixtures.userA,
          initial: '/issues',
          store: _store(seeded: true)));
      await tester.pumpAndSettle();

      expect(find.text('Giáo trình Giải tích'), findsOneWidget);
      expect(find.textContaining('Bạn B (demo) báo sự cố'), findsOneWidget);
      expect(find.text('Sai tình trạng / hư hỏng'), findsOneWidget);

      await tester.tap(find.text('Giáo trình Giải tích'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết sự cố'), findsOneWidget);
      expect(find.text('Bìa sách bị rách.'), findsOneWidget);
    });

    testWidgets('Người ngoài không thấy Issue của giao dịch khác', (tester) async {
      await tester.pumpWidget(_app(
          viewer: MockFixtures.outsider,
          initial: '/issues',
          store: _store(seeded: true)));
      await tester.pumpAndSettle();

      expect(find.text('Giáo trình Giải tích'), findsNothing);
      expect(find.textContaining('Không có sự cố nào đang mở'), findsOneWidget);
    });
  });

  group('SCR-22 Báo cáo sự cố', () {
    testWidgets('B gửi báo cáo: sau ACK mới chuyển sang SCR-23', (tester) async {
      _tallView(tester);
      final store = _store();
      await tester.pumpWidget(_app(
          viewer: MockFixtures.userB,
          initial: '/issues/new?transactionId=$_borrow',
          store: store));
      await tester.pumpAndSettle();

      expect(find.text('Giáo trình Giải tích'), findsOneWidget);
      await tester.tap(find.text('Sai tài liệu'));
      await tester.enterText(find.byKey(const Key('issue-reason')), 'Nhầm giáo trình.');
      await tester.tap(find.text('Gửi báo cáo'));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết sự cố'), findsOneWidget);
      expect(find.text('Nhầm giáo trình.'), findsOneWidget);
      expect(store.issues.length, 1);
      expect(store.issues.single.type, IssueType.wrongMaterial);
      expect(store.openIssueCount(_borrow), 1);
    });

    testWidgets('Mô tả rỗng: báo lỗi tại ô nhập, chưa gọi server', (tester) async {
      _tallView(tester);
      final store = _store();
      await tester.pumpWidget(_app(
          viewer: MockFixtures.userB,
          initial: '/issues/new?transactionId=$_borrow',
          store: store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gửi báo cáo'));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng mô tả sự cố.'), findsOneWidget);
      expect(store.issues, isEmpty);
    });

    testWidgets('Timeout sau khi server đã ghi: retry dùng lại key, không tạo Issue thứ hai',
        (tester) async {
      _tallView(tester);
      final store = _store();
      final flaky = _TimeoutOnceIssueRepository(MockIssueRepository(
          MockIssueCommandRunner(store: store, actorId: MockFixtures.userB)));
      await tester.pumpWidget(_app(
        viewer: MockFixtures.userB,
        initial: '/issues/new?transactionId=$_borrow',
        store: store,
        overrides: [issueRepositoryProvider.overrideWith((ref) => flaky)],
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('issue-reason')), 'Bìa rách.');
      await tester.tap(find.text('Gửi báo cáo'));
      await tester.pumpAndSettle();
      // Không coi timeout là thành công: vẫn ở form, chưa sang SCR-23.
      expect(find.text('Gửi báo cáo'), findsOneWidget);
      expect(find.text('Chi tiết sự cố'), findsNothing);

      await tester.tap(find.text('Gửi báo cáo'));
      await tester.pumpAndSettle();

      expect(flaky.keys.length, 2);
      expect(flaky.keys.first, flaky.keys.last);
      expect(store.issues.length, 1);
      expect(find.text('Chi tiết sự cố'), findsOneWidget);
    });

    testWidgets('Thiếu giao dịch, người ngoài hoặc giao dịch đã hủy: không có form',
        (tester) async {
      _tallView(tester);
      await tester.pumpWidget(_app(
          viewer: MockFixtures.userB, initial: '/issues/new', store: _store()));
      await tester.pumpAndSettle();
      expect(find.text(CreateIssuePage.noAccessMessage), findsOneWidget);
      expect(find.text('Gửi báo cáo'), findsNothing);

      await tester.pumpWidget(_app(
          viewer: MockFixtures.outsider,
          initial: '/issues/new?transactionId=$_borrow',
          store: _store()));
      await tester.pumpAndSettle();
      expect(find.text(CreateIssuePage.noAccessMessage), findsOneWidget);
      expect(find.text('Giáo trình Giải tích'), findsNothing);

      final cancelled = _store()..setStatus(_borrow, TransactionStatus.cancelled);
      await tester.pumpWidget(_app(
          viewer: MockFixtures.userB,
          initial: '/issues/new?transactionId=$_borrow',
          store: cancelled));
      await tester.pumpAndSettle();
      expect(find.textContaining('hiện không nhận báo sự cố'), findsOneWidget);
      expect(find.text('Gửi báo cáo'), findsNothing);
    });
  });

  group('SCR-23 Chi tiết sự cố', () {
    testWidgets('Id lạ hoặc không có quyền: thông báo chung, không lộ dữ liệu',
        (tester) async {
      await tester.pumpWidget(_app(
          viewer: MockFixtures.outsider,
          initial: '/issues/issue-seed-1',
          store: _store(seeded: true)));
      await tester.pumpAndSettle();
      expect(find.text(IssueDetailsPage.noAccessMessage), findsOneWidget);
      expect(find.text('Bìa sách bị rách.'), findsNothing);

      await tester.pumpWidget(_app(
          viewer: MockFixtures.userA,
          initial: '/issues/khong-co',
          store: _store(seeded: true)));
      await tester.pumpAndSettle();
      expect(find.text(IssueDetailsPage.noAccessMessage), findsOneWidget);
    });

    testWidgets('Dialog đề xuất không tràn trên 360×640 khi bàn phím mở',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = _store(seeded: true);
      await tester.pumpWidget(_app(
          viewer: MockFixtures.userA,
          initial: '/issues/issue-seed-1',
          store: store));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Đề xuất phương án'));
      await tester.tap(find.text('Đề xuất phương án'));
      await tester.pumpAndSettle();

      // Bàn phím cao (kèm thanh gợi ý) chiếm hơn nửa màn hình 640px.
      tester.view.viewInsets = const FakeViewPadding(bottom: 380);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull); // Không có RenderFlex overflow.

      // Nút gửi vẫn bấm được nhờ nội dung dialog cuộn được.
      await tester.enterText(
          find.byKey(const Key('resolution-summary')), 'Đổi bản khác.');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Gửi đề xuất'));
      await tester.pumpAndSettle();
      expect(store.issueProposal('issue-seed-1')?.summary, 'Đổi bản khác.');
    });

    testWidgets('A đề xuất, B xác nhận, A xác nhận: chỉ khi đủ hai bên mới đóng',
        (tester) async {
      _tallView(tester);
      final store = _store(seeded: true);

      // A đề xuất phương án.
      await tester.pumpWidget(_app(
          viewer: MockFixtures.userA,
          initial: '/issues/issue-seed-1',
          store: store));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận phương án'), findsNothing); // Chưa có phương án.
      await tester.tap(find.text('Đề xuất phương án'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi đề xuất')); // Rỗng -> báo lỗi, đóng không được.
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập phương án.'), findsOneWidget);
      await tester.enterText(
          find.byKey(const Key('resolution-summary')), 'A đổi bản sách khác.');
      await tester.tap(find.text('Gửi đề xuất'));
      await tester.pumpAndSettle();

      expect(find.text('Phương án giải quyết (bản 1)'), findsOneWidget);
      expect(find.text('A đổi bản sách khác.'), findsOneWidget);
      // Người đề xuất chưa tự được tính là đã xác nhận.
      expect(find.textContaining('Bạn A (demo) chưa xác nhận'), findsOneWidget);
      expect(find.text('Xác nhận phương án'), findsOneWidget);

      // B xác nhận.
      await tester.pumpWidget(_app(
          viewer: MockFixtures.userB,
          initial: '/issues/issue-seed-1',
          store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận phương án'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Để sau')); // Hủy hộp thoại: không có gì đổi.
      await tester.pumpAndSettle();
      expect(store.issueProposal('issue-seed-1')!.approvals, isEmpty);

      await tester.tap(find.text('Xác nhận phương án'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tôi đồng ý'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã ghi nhận xác nhận của bạn'), findsOneWidget);
      expect(find.text('Xác nhận phương án'), findsNothing);
      expect(find.textContaining('Chờ bên còn lại'), findsWidgets);
      expect(store.issue('issue-seed-1')!.isOpen, isTrue);

      // A xác nhận nốt -> RESOLVED.
      await tester.pumpWidget(_app(
          viewer: MockFixtures.userA,
          initial: '/issues/issue-seed-1',
          store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận phương án'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tôi đồng ý'));
      await tester.pumpAndSettle();

      expect(find.text('Đã giải quyết'), findsOneWidget);
      expect(find.text('Thao tác'), findsNothing);
      expect(store.issue('issue-seed-1')!.status, IssueStatus.resolved);
      expect(store.openIssueCount(_borrow), 0);
    });
  });

  group('SCR-23 theo phạm vi người xem', () {
    // Issue của chặng C->B: C đọc được nhưng không được mở giao dịch.
    MockTransactionStore legStore() => MockTransactionStore.fromFixtures(
          clock: () => DateTime.utc(2026, 11, 23, 3),
          seedIssues: [
            Issue(
              id: 'issue-leg-1',
              transactionId: 'txn-delivery-01',
              handoverId: 'handover-c-to-b',
              reporterId: MockFixtures.userB,
              type: IssueType.deliveryFailed,
              reason: 'C chưa giao sách.',
              status: IssueStatus.open,
              openedAt: DateTime.utc(2026, 11, 22, 2),
            ),
          ],
          seedHandovers: const [
            Handover(
                id: 'handover-c-to-b',
                transactionId: 'txn-delivery-01',
                fromUserId: MockFixtures.userC,
                toUserId: MockFixtures.userB,
                status: HandoverStatus.disputed),
          ],
        );

    testWidgets('C thấy Issue của chặng mình nhưng không có lối tắt sang giao dịch',
        (tester) async {
      _tallView(tester);
      await tester.pumpWidget(_app(
          viewer: MockFixtures.userC,
          initial: '/issues/issue-leg-1',
          store: legStore()));
      await tester.pumpAndSettle();

      expect(find.text('C chưa giao sách.'), findsOneWidget);
      expect(find.text('Xem giao dịch'), findsNothing);
      // C là bên bị ảnh hưởng nên được đề xuất phương án.
      expect(find.text('Đề xuất phương án'), findsOneWidget);
    });

    testWidgets('A là bên chỉ đọc: thấy Issue và giao dịch nhưng không có thao tác',
        (tester) async {
      _tallView(tester);
      await tester.pumpWidget(_app(
          viewer: MockFixtures.userA,
          initial: '/issues/issue-leg-1',
          store: legStore()));
      await tester.pumpAndSettle();

      expect(find.text('Xem giao dịch'), findsOneWidget);
      expect(find.text('Thao tác'), findsNothing);
      expect(find.text('Đề xuất phương án'), findsNothing);
    });

    testWidgets('C ở chặng khác nhận thông báo chung, không lộ nội dung',
        (tester) async {
      final store = MockTransactionStore.fromFixtures(
        clock: () => DateTime.utc(2026, 11, 23, 3),
        seedIssues: [_seedIssue()], // Issue giao dịch mượn A/B, không liên quan C.
      );
      await tester.pumpWidget(_app(
          viewer: MockFixtures.userC,
          initial: '/issues/issue-seed-1',
          store: store));
      await tester.pumpAndSettle();

      expect(find.text(IssueDetailsPage.noAccessMessage), findsOneWidget);
      expect(find.text('Bìa sách bị rách.'), findsNothing);
    });
  });

  group('Liên kết với SCR-14', () {
    testWidgets('Issue đang mở hiện banner ở giao dịch và dẫn tới SCR-21',
        (tester) async {
      _tallView(tester);
      await tester.pumpWidget(_app(
          viewer: MockFixtures.userA,
          initial: '/transactions/$_borrow',
          store: _store(seeded: true)));
      await tester.pumpAndSettle();

      expect(find.text('Có 1 sự cố đang mở'), findsOneWidget);
      await tester.tap(find.text('Có 1 sự cố đang mở'));
      await tester.pumpAndSettle();
      expect(find.text('Sự cố'), findsOneWidget); // AppBar SCR-21.
    });

    testWidgets('Nút "Báo sự cố" ở SCR-14 mở SCR-22 đúng giao dịch', (tester) async {
      _tallView(tester);
      await tester.pumpWidget(_app(
          viewer: MockFixtures.userB,
          initial: '/transactions/$_borrow',
          store: _store()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Báo sự cố'));
      await tester.pumpAndSettle();
      expect(find.text('Gửi báo cáo'), findsOneWidget);
      expect(find.text('Giáo trình Giải tích'), findsOneWidget);
    });
  });
}

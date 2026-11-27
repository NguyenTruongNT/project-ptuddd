import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:studyshare/core/auth/auth_session_providers.dart';
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/contracts/command_inputs.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/exchange_request.dart';
import 'package:studyshare/core/contracts/models/transaction.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';
import 'package:studyshare/features/requests/domain/request_view.dart';
import 'package:studyshare/features/requests/presentation/create_request_page.dart';
import 'package:studyshare/features/requests/presentation/request_center_page.dart';
import 'package:studyshare/features/requests/providers/request_providers.dart';
import 'package:studyshare/l10n/app_localizations.dart';

ExchangeRequest _request(String id, ExchangeRequestStatus status) =>
    ExchangeRequest(
      id: id,
      listingId: 'list-donate-01',
      requesterId: MockFixtures.userB,
      status: status,
      createdAt: DateTime.utc(2026, 11, 27, 3),
      requestedBorrowDays: 7,
    );

RequestView _view(
  String id, {
  required RequestViewerRole role,
  ExchangeRequestStatus status = ExchangeRequestStatus.pending,
  Set<RequestAction> actions = const {},
  String? rejectReason,
}) => RequestView(
  request: _request(id, status),
  materialTitle: 'Giáo trình $id',
  materialSubject: 'Toán',
  offerType: OfferType.borrow,
  ownerDisplayName: 'Chủ A',
  requesterDisplayName: 'Người gửi B',
  viewerRole: role,
  allowedActions: actions,
  rejectReason: rejectReason,
);

class _FakeRequestRepository implements RequestCenterRepository {
  _FakeRequestRepository({this.views = const []});

  List<RequestView> views;
  final List<String> calls = [];
  final List<String> keys = [];
  final List<CommandResult<ExchangeRequest>> createResults = [];
  CreateRequestInput? lastCreate;
  String? lastRejectReason;

  @override
  Future<List<RequestView>> getMyRequestViews() async => views;

  @override
  Future<List<ExchangeRequest>> getMyRequests() async =>
      views.map((v) => v.request).toList();

  @override
  Future<CommandResult<ExchangeRequest>> createRequest(
    CreateRequestInput input, {
    required String idempotencyKey,
  }) async {
    calls.add('create');
    keys.add(idempotencyKey);
    lastCreate = input;
    if (createResults.isNotEmpty) return createResults.removeAt(0);
    return CommandOk.receipt(
      _request('new', ExchangeRequestStatus.pending),
      commandId: 'cmd-1',
      serverRevision: 1,
    );
  }

  @override
  Future<CommandResult<StudyTransaction>> approveRequest(
    String requestId, {
    required String idempotencyKey,
  }) async {
    calls.add('approve:$requestId');
    return const CommandOk(
      StudyTransaction(
        id: 'txn-new',
        listingId: 'list-donate-01',
        requestId: 'in-1',
        materialId: 'mat-donate-01',
        type: OfferType.borrow,
        ownerAtAcceptance: MockFixtures.userA,
        receiverId: MockFixtures.userB,
        status: TransactionStatus.awaitingHandover,
        agreedBorrowDays: 7,
      ),
      'event-1',
    );
  }

  @override
  Future<CommandResult<ExchangeRequest>> rejectRequest(
    String requestId,
    String reason, {
    required String idempotencyKey,
  }) async {
    calls.add('reject:$requestId');
    lastRejectReason = reason;
    return CommandOk.receipt(
      _request(requestId, ExchangeRequestStatus.rejected),
      commandId: 'cmd-2',
      serverRevision: 2,
    );
  }

  @override
  Future<CommandResult<ExchangeRequest>> cancelPendingRequest(
    String requestId, {
    required String idempotencyKey,
  }) async {
    calls.add('cancel:$requestId');
    return CommandOk.receipt(
      _request(requestId, ExchangeRequestStatus.cancelled),
      commandId: 'cmd-3',
      serverRevision: 2,
    );
  }
}

// StateError là Error nên Riverpod không tự retry; test không để lại timer.
class _FailingRequestRepository extends _FakeRequestRepository {
  @override
  Future<List<RequestView>> getMyRequestViews() =>
      Future.error(StateError('SECRET_BACKEND_DETAIL'));
}

Widget _app({
  required String initial,
  required String viewer,
  RequestCenterRepository? repository,
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/requests', builder: (_, _) => const RequestCenterPage()),
      GoRoute(
        path: '/requests/new/:listingId',
        builder: (_, state) =>
            CreateRequestPage(listingId: state.pathParameters['listingId']!),
      ),
      GoRoute(
        path: '/listings/:listingId',
        builder: (_, _) => const Scaffold(body: Text('SCR-06')),
      ),
      GoRoute(
        path: '/transactions',
        builder: (_, _) => const Scaffold(body: Text('SCR-13')),
      ),
      GoRoute(
        path: '/transactions/:transactionId',
        builder: (_, state) => Scaffold(
          body: Text('SCR-14 ${state.pathParameters['transactionId']}'),
        ),
      ),
      GoRoute(
        path: '/explore',
        builder: (_, _) => const Scaffold(body: Text('SCR-05')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      workflowRpcProvider.overrideWithValue(null),
      sessionBoundaryProvider.overrideWithValue(viewer),
      requestRepositoryProvider.overrideWithValue(
        repository ?? _FakeRequestRepository(),
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
  group('SCR-11 Gửi yêu cầu', () {
    testWidgets('người ngoài gửi yêu cầu nhận tặng rồi sang SCR-12', (
      tester,
    ) async {
      final repo = _FakeRequestRepository();
      await tester.pumpWidget(
        _app(
          initial: '/requests/new/list-donate-01',
          viewer: MockFixtures.outsider,
          repository: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cấu trúc dữ liệu'), findsOneWidget);
      // DONATE không có ô số ngày mượn.
      expect(find.byKey(const ValueKey('request-days')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('request-submit')));
      await tester.pumpAndSettle();

      expect(repo.calls, ['create']);
      expect(repo.lastCreate?.listingId, 'list-donate-01');
      expect(repo.lastCreate?.requestedBorrowDays, isNull);
      expect(find.text('Trung tâm yêu cầu'), findsOneWidget);
    });

    testWidgets('chủ tài liệu không thấy nút gửi', (tester) async {
      final repo = _FakeRequestRepository();
      await tester.pumpWidget(
        _app(
          initial: '/requests/new/list-donate-01',
          viewer: MockFixtures.userA,
          repository: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('tài liệu của bạn'), findsOneWidget);
      expect(find.byKey(const ValueKey('request-submit')), findsNothing);
    });

    testWidgets('đã có yêu cầu PENDING thì chặn gửi trùng', (tester) async {
      await tester.pumpWidget(
        _app(
          initial: '/requests/new/list-donate-01',
          viewer: MockFixtures.userB,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('đang chờ cho tin đăng này'), findsOneWidget);
      expect(find.byKey(const ValueKey('request-submit')), findsNothing);
    });

    testWidgets(
      'lỗi nghiệp vụ hiển thị thông báo an toàn, không chuyển trang',
      (tester) async {
        final repo = _FakeRequestRepository()
          ..createResults.add(
            const CommandError(DomainErrorCode.duplicateRequest, 'RAW_SQL'),
          );
        await tester.pumpWidget(
          _app(
            initial: '/requests/new/list-donate-01',
            viewer: MockFixtures.outsider,
            repository: repo,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('request-submit')));
        await tester.pumpAndSettle();

        expect(
          find.text('Bạn đã có một yêu cầu đang chờ cho tin đăng này.'),
          findsOneWidget,
        );
        expect(find.textContaining('RAW_SQL'), findsNothing);
        expect(find.text('Gửi yêu cầu'), findsOneWidget);
      },
    );

    testWidgets('timeout giữ nguyên idempotency key khi gửi lại', (
      tester,
    ) async {
      final repo = _FakeRequestRepository()
        ..createResults.add(
          const CommandError(DomainErrorCode.timeoutUnknown, 'Chưa rõ'),
        );
      await tester.pumpWidget(
        _app(
          initial: '/requests/new/list-donate-01',
          viewer: MockFixtures.outsider,
          repository: repo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('request-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('request-submit')));
      await tester.pumpAndSettle();

      expect(repo.keys, hasLength(2));
      expect(repo.keys.first, repo.keys.last);
      expect(find.text('Trung tâm yêu cầu'), findsOneWidget);
    });
  });

  group('SCR-12 Trung tâm yêu cầu', () {
    _FakeRequestRepository seeded() => _FakeRequestRepository(
      views: [
        _view(
          'in-1',
          role: RequestViewerRole.owner,
          actions: {RequestAction.approve, RequestAction.reject},
        ),
        _view(
          'out-1',
          role: RequestViewerRole.requester,
          actions: {RequestAction.cancel},
        ),
        _view(
          'out-2',
          role: RequestViewerRole.requester,
          status: ExchangeRequestStatus.rejected,
          rejectReason: 'Đã cho bạn khác mượn',
        ),
      ],
    );

    testWidgets('tách yêu cầu nhận được và đã gửi, nút theo allowedActions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          initial: '/requests',
          viewer: MockFixtures.userA,
          repository: seeded(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nhận được (1)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('request-approve-in-1')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('request-reject-in-1')), findsOneWidget);
      expect(find.text('Người gửi: Người gửi B'), findsOneWidget);
      expect(find.byKey(const ValueKey('request-cancel-out-1')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('request-tab-sent')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('request-cancel-out-1')),
        findsOneWidget,
      );
      expect(find.text('Lý do: Đã cho bạn khác mượn'), findsOneWidget);
      expect(find.text('Bị từ chối'), findsOneWidget);
      // Request đã kết thúc không có nút thao tác.
      expect(find.byKey(const ValueKey('request-cancel-out-2')), findsNothing);
    });

    testWidgets('duyệt có xác nhận rồi mở giao dịch vừa tạo', (tester) async {
      final repo = seeded();
      await tester.pumpWidget(
        _app(
          initial: '/requests',
          viewer: MockFixtures.userA,
          repository: repo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('request-approve-in-1')));
      await tester.pumpAndSettle();
      expect(find.text('Duyệt yêu cầu?'), findsOneWidget);
      expect(repo.calls, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Duyệt').last);
      await tester.pumpAndSettle();

      expect(repo.calls, ['approve:in-1']);
      expect(find.text('SCR-14 txn-new'), findsOneWidget);
    });

    testWidgets('từ chối bắt buộc nhập lý do', (tester) async {
      final repo = seeded();
      await tester.pumpWidget(
        _app(
          initial: '/requests',
          viewer: MockFixtures.userA,
          repository: repo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('request-reject-in-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Từ chối'));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập lý do từ chối.'), findsOneWidget);
      expect(repo.calls, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('request-reject-reason')),
        '  Sách đang hỏng  ',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Từ chối'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['reject:in-1']);
      expect(repo.lastRejectReason, 'Sách đang hỏng');
    });

    testWidgets('người gửi rút yêu cầu sau khi xác nhận', (tester) async {
      final repo = seeded();
      await tester.pumpWidget(
        _app(
          initial: '/requests',
          viewer: MockFixtures.userB,
          repository: repo,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('request-tab-sent')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('request-cancel-out-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Rút yêu cầu'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['cancel:out-1']);
    });

    testWidgets('tải danh sách lỗi thì báo an toàn và cho thử lại', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          initial: '/requests',
          viewer: MockFixtures.userA,
          repository: _FailingRequestRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.textContaining('SECRET_BACKEND_DETAIL'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('requestViewFromRpc', () {
    Map<String, dynamic> raw({List<Object?>? actions}) => {
      'id': 'r1',
      'listingId': 'l1',
      'requesterId': 'u1',
      'requestedBorrowDays': 5,
      'status': 'PENDING',
      'createdAt': '2026-11-27T09:00:00+00:00',
      'decidedAt': null,
      'rejectReason': null,
      'revision': 1,
      'materialTitle': 'Giải tích',
      'materialSubject': 'Toán',
      'offerType': 'BORROW',
      'ownerId': 'o1',
      'ownerDisplayName': 'Chủ',
      'requesterDisplayName': 'Người gửi',
      'viewerRole': 'OWNER',
      'allowedActions':
          actions ?? ['CAN_APPROVE_REQUEST', 'CAN_REJECT_REQUEST'],
    };

    test('giải mã đủ trường hiển thị và quyền thao tác', () {
      final view = requestViewFromRpc(raw());
      expect(view.id, 'r1');
      expect(view.requestedBorrowDays, 5);
      expect(view.materialTitle, 'Giải tích');
      expect(view.isIncoming, isTrue);
      expect(view.can(RequestAction.approve), isTrue);
      expect(view.can(RequestAction.cancel), isFalse);
    });

    test('action lạ bị bỏ qua, không hiện nút chưa hỗ trợ', () {
      final view = requestViewFromRpc(raw(actions: ['CAN_SOMETHING_NEW']));
      expect(view.allowedActions, isEmpty);
    });

    test(
      'thiếu trường bắt buộc thì báo lỗi hợp đồng, không trả dữ liệu rỗng',
      () {
        final broken = raw()..remove('viewerRole');
        expect(() => requestViewFromRpc(broken), throwsFormatException);
      },
    );
  });
}

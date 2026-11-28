import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/transaction.dart';
import 'package:studyshare/core/contracts/repositories/transaction_repository.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';
import 'package:studyshare/core/providers/mock_query_providers.dart';
import 'package:studyshare/features/borrow/presentation/request_return_button.dart';
import 'package:studyshare/features/borrow/providers/borrow_providers.dart';
import 'package:studyshare/features/transactions/presentation/transaction_details_page.dart';
import 'package:studyshare/features/transactions/providers/transaction_providers.dart';
import 'package:studyshare/l10n/app_localizations.dart';

const _returnButton = ValueKey('borrow-request-return');

const _returnPending = StudyTransaction(
  id: 'txn-borrow-01',
  listingId: 'list-borrow-01',
  requestId: 'req-borrow-01',
  materialId: 'mat-borrow-01',
  type: OfferType.borrow,
  ownerAtAcceptance: MockFixtures.userA,
  receiverId: MockFixtures.userB,
  status: TransactionStatus.returnPending,
  agreedBorrowDays: 7,
);

/// Repository giả cho test (thay cho RPC Supabase), không phải mock của app.
class _FakeBorrowRepository implements BorrowRepository {
  final List<CommandResult<StudyTransaction>> results = [];
  final List<String> calls = [];
  final List<String> keys = [];

  @override
  Future<CommandResult<StudyTransaction>> requestReturn(
    String transactionId, {
    required String idempotencyKey,
  }) async {
    calls.add(transactionId);
    keys.add(idempotencyKey);
    if (results.isNotEmpty) return results.removeAt(0);
    return const CommandOk(_returnPending, 'event-return-1');
  }
}

Widget _buttonApp({BorrowRepository? repository}) {
  return ProviderScope(
    overrides: [
      if (repository != null)
        borrowRepositoryProvider.overrideWithValue(repository)
      else
        // StateError là Error nên Riverpod không tự retry; test không để lại timer.
        borrowRepositoryProvider.overrideWith(
          (ref) => throw StateError('NO_BACKEND'),
        ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: Center(
          child: RequestReturnButton(transactionId: 'txn-borrow-01'),
        ),
      ),
    ),
  );
}

// Màn cao để toàn bộ thẻ Thao tác được dựng, không phụ thuộc vị trí cuộn.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _detailsApp(String viewer, BorrowRepository repository) {
  final router = GoRouter(
    initialLocation: '/transactions/txn-borrow-01',
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
      // Dữ liệu đọc Transaction dùng fixture test của module Sơn.
      workflowRpcProvider.overrideWithValue(null),
      demoViewerIdProvider.overrideWith((ref) => viewer),
      nowUtcProvider.overrideWith(
        (ref) =>
            () => DateTime.utc(2026, 11, 23, 3),
      ),
      borrowRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

Future<void> _pressAndConfirm(WidgetTester tester) async {
  await tester.tap(find.byKey(_returnButton));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Yêu cầu trả'));
  await tester.pumpAndSettle();
}

void main() {
  group('RequestReturnButton', () {
    testWidgets('xác nhận rồi gọi RPC yêu cầu trả đúng giao dịch', (
      tester,
    ) async {
      final repo = _FakeBorrowRepository();
      await tester.pumpWidget(_buttonApp(repository: repo));

      await tester.tap(find.byKey(_returnButton));
      await tester.pumpAndSettle();
      expect(find.text('Yêu cầu trả tài liệu?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Yêu cầu trả'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['txn-borrow-01']);
      expect(find.textContaining('Đã gửi yêu cầu trả'), findsOneWidget);
    });

    testWidgets('bấm "Để sau" thì không gửi gì', (tester) async {
      final repo = _FakeBorrowRepository();
      await tester.pumpWidget(_buttonApp(repository: repo));

      await tester.tap(find.byKey(_returnButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();

      expect(repo.calls, isEmpty);
    });

    testWidgets('timeout giữ nguyên idempotency key khi bấm lại', (
      tester,
    ) async {
      final repo = _FakeBorrowRepository()
        ..results.add(
          const CommandError(DomainErrorCode.timeoutUnknown, 'Chưa rõ'),
        );
      await tester.pumpWidget(_buttonApp(repository: repo));

      await _pressAndConfirm(tester);
      await _pressAndConfirm(tester);

      expect(repo.keys, hasLength(2));
      expect(repo.keys.first, repo.keys.last);
    });

    testWidgets(
      'lỗi nghiệp vụ hiển thị thông báo an toàn, không báo thành công',
      (tester) async {
        final repo = _FakeBorrowRepository()
          ..results.add(
            const CommandError(
              DomainErrorCode.invalidTransactionTransition,
              'Trạng thái đã thay đổi. Hãy tải lại.',
            ),
          );
        await tester.pumpWidget(_buttonApp(repository: repo));

        await _pressAndConfirm(tester);

        expect(
          find.text('Trạng thái đã thay đổi. Hãy tải lại.'),
          findsOneWidget,
        );
        expect(find.textContaining('Đã gửi yêu cầu trả'), findsNothing);
      },
    );

    testWidgets('không có backend thì báo cần kết nối Supabase', (
      tester,
    ) async {
      await tester.pumpWidget(_buttonApp());

      await _pressAndConfirm(tester);

      expect(find.textContaining('kết nối Supabase'), findsOneWidget);
      expect(find.textContaining('NO_BACKEND'), findsNothing);
      expect(find.textContaining('Đã gửi yêu cầu trả'), findsNothing);
    });
  });

  group('SCR-14 hiển thị nút theo CAN_REQUEST_RETURN', () {
    testWidgets('B đang mượn thấy nút yêu cầu trả', (tester) async {
      _tallView(tester);
      await tester.pumpWidget(
        _detailsApp(MockFixtures.userB, _FakeBorrowRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(_returnButton), findsOneWidget);
    });

    testWidgets('chủ tài liệu A không thấy nút yêu cầu trả', (tester) async {
      _tallView(tester);
      await tester.pumpWidget(
        _detailsApp(MockFixtures.userA, _FakeBorrowRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(_returnButton), findsNothing);
    });
  });
}

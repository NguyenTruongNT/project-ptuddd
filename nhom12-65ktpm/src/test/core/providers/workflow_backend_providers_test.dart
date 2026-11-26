import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/auth/auth_session_providers.dart';
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/mock/mock_transaction_query_repository.dart';
import 'package:studyshare/core/providers/mock_query_providers.dart';
import 'package:studyshare/features/issues/data/mock_issue_repository.dart';
import 'package:studyshare/features/issues/data/supabase_issue_repository.dart';
import 'package:studyshare/features/issues/providers/issue_providers.dart';
import 'package:studyshare/features/transactions/data/mock_seller_payment_repository.dart';
import 'package:studyshare/features/transactions/data/supabase_transaction_repository.dart';
import 'package:studyshare/features/transactions/providers/transaction_providers.dart';

import '../../support/workflow_rpc_fixture.dart';

class _Actor extends Notifier<String> {
  @override
  String build() => workflowActorA;
  void change(String actor) => state = actor;
}

final _actorProvider = NotifierProvider<_Actor, String>(_Actor.new);

void main() {
  test('Demo tường minh dùng chung mock cho đọc và ghi', () async {
    final c = ProviderContainer(
      overrides: [
        sessionBoundaryProvider.overrideWithValue('demo'),
        supabaseClientProvider.overrideWithValue(null),
      ],
    );
    addTearDown(c.dispose);
    expect(
      c.read(transactionQueryRepositoryProvider),
      isA<MockTransactionQueryRepository>(),
    );
    expect(
      c.read(sellerPaymentRepositoryProvider),
      isA<MockSellerPaymentRepository>(),
    );
    expect(c.read(issueRepositoryProvider), isA<MockIssueRepository>());
    expect(await c.read(myTransactionsProvider.future), isNotEmpty);
  });

  test(
    'Phiên thật chọn đủ năm repository, Issue context cùng nguồn Transaction',
    () async {
      final backend = WorkflowTestBackend();
      await backend.login();
      addTearDown(backend.dispose);
      backend.onRpc = (_) => workflowResponse(transactionRpcFixture());
      final c = ProviderContainer(
        overrides: [
          sessionBoundaryProvider.overrideWithValue(workflowActorA),
          supabaseClientProvider.overrideWithValue(backend.client),
        ],
      );
      addTearDown(c.dispose);
      expect(
        c.read(transactionQueryRepositoryProvider),
        isA<SupabaseTransactionQueryRepository>(),
      );
      expect(
        c.read(issueQueryRepositoryProvider),
        isA<SupabaseIssueQueryRepository>(),
      );
      expect(
        c.read(sellerPaymentRepositoryProvider),
        isA<SupabaseSellerPaymentRepository>(),
      );
      expect(
        c.read(transactionCancellationRepositoryProvider),
        isA<SupabaseTransactionCancellationRepository>(),
      );
      expect(c.read(issueRepositoryProvider), isA<SupabaseIssueRepository>());
      expect(
        (await c.read(issueTransactionContextProvider('transaction-1').future))!
            .id,
        'transaction-1',
      );
    },
  );

  test('Đổi actor tải dữ liệu mới; logout không fallback thành mock', () async {
    final backend = WorkflowTestBackend();
    await backend.login();
    addTearDown(backend.dispose);
    backend.onRpc = (_) {
      final raw = transactionRpcFixture();
      raw['materialTitle'] = backend.client.auth.currentUser!.id;
      return workflowResponse([raw]);
    };
    final c = ProviderContainer(
      overrides: [
        sessionBoundaryProvider.overrideWith(
          (ref) => ref.watch(_actorProvider),
        ),
        supabaseClientProvider.overrideWithValue(backend.client),
      ],
    );
    addTearDown(c.dispose);
    final first = c.read(workflowRpcProvider);
    expect(
      (await c.read(myTransactionsProvider.future)).single.materialTitle,
      workflowActorA,
    );
    await backend.login(asB: true);
    c.read(_actorProvider.notifier).change(workflowActorB);
    expect(c.read(workflowRpcProvider), isNot(same(first)));
    expect(
      (await c.read(myTransactionsProvider.future)).single.materialTitle,
      workflowActorB,
    );
    c.read(_actorProvider.notifier).change('');
    await expectLater(
      c.read(myTransactionsProvider.future),
      throwsA(
        predicate<Object>(
          (e) => e.toString().contains('AUTH_REQUIRED'),
          'requires authentication',
        ),
      ),
    );
  });

  test('Chưa cấu hình hoặc Auth lỗi không tự bật demo', () {
    final c = ProviderContainer(
      overrides: [
        sessionBoundaryProvider.overrideWithValue(''),
        supabaseClientProvider.overrideWithValue(null),
      ],
    );
    addTearDown(c.dispose);
    expect(
      () => c.read(workflowRpcProvider),
      throwsA(
        predicate<Object>(
          (e) => e.toString().contains('AUTH_REQUIRED'),
          'requires authentication',
        ),
      ),
    );
  });
}

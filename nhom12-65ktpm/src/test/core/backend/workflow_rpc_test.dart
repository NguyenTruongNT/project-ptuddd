import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/features/issues/data/supabase_issue_repository.dart';
import 'package:studyshare/features/transactions/data/supabase_transaction_repository.dart';

import '../../support/workflow_rpc_fixture.dart';

void main() {
  late WorkflowTestBackend backend;
  late WorkflowRpc rpc;
  setUp(() async {
    backend = WorkflowTestBackend();
    await backend.login();
    rpc = WorkflowRpc(backend.client, workflowActorA);
  });
  tearDown(() async => backend.dispose());

  for (final entry in [
    ('P0001', 'CONFLICT', DomainErrorCode.conflict),
    ('P0001', 'ISSUE_BLOCKING_ACTION', DomainErrorCode.issueBlockingAction),
    ('P0001', 'FORBIDDEN', DomainErrorCode.forbidden),
    ('P0001', 'PRIVATE_UNKNOWN_ERROR', DomainErrorCode.unexpectedError),
    ('23505', 'PRIVATE_SQL_DETAIL', DomainErrorCode.conflict),
    ('23514', 'PRIVATE_SQL_DETAIL', DomainErrorCode.invalidInput),
    ('42883', 'PRIVATE_SQL_DETAIL', DomainErrorCode.backendUnavailable),
    ('42P01', 'PRIVATE_SQL_DETAIL', DomainErrorCode.backendUnavailable),
    ('42703', 'PRIVATE_SQL_DETAIL', DomainErrorCode.backendUnavailable),
    ('PGRST202', 'PRIVATE_SQL_DETAIL', DomainErrorCode.backendUnavailable),
    ('XX000', 'PRIVATE_SQL_DETAIL', DomainErrorCode.unexpectedError),
  ]) {
    test(
      'Gateway ${entry.$1}/${entry.$2}: Transaction và Issue nhận cùng mã an toàn',
      () async {
        backend.onRpc = (_) => workflowResponse({
          'code': entry.$1,
          'message': entry.$2,
        }, status: 400);
        final reads = [
          SupabaseTransactionQueryRepository(rpc).getMyTransactions,
          SupabaseIssueQueryRepository(rpc).getMyIssues,
        ];
        for (final read in reads) {
          await expectLater(
            read(),
            throwsA(
              isA<AppError>()
                  .having((e) => e.code, 'code', entry.$3)
                  .having(
                    (e) => e.safeMessage,
                    'safeMessage',
                    isNot(contains('PRIVATE_')),
                  ),
            ),
          );
        }
        // Cùng gateway phục vụ cả command có Event và command có receipt.
        final command = await rpc.command('review_command', {}, (v) => v);
        final receipt = await rpc.receiptCommand(
          'review_receipt',
          {},
          (v) => v,
        );
        for (final result in [command, receipt]) {
          expect(
            result,
            isA<CommandError>()
                .having((e) => e.code, 'code', entry.$3)
                .having(
                  (e) => e.safeMessage,
                  'safeMessage',
                  isNot(contains('PRIVATE_')),
                ),
          );
        }
      },
    );
  }

  test(
    'Mã wire lạ và envelope lỗi không bị diễn giải thành CONFLICT',
    () async {
      expect(
        DomainErrorCode.fromWire('NEW_PRIVATE_CODE'),
        DomainErrorCode.unexpectedError,
      );
      expect(DomainErrorCode.fromWire('CONFLICT'), DomainErrorCode.conflict);
      backend.onRpc = (_) => workflowResponse({
        'ok': false,
        'code': 'NEW_PRIVATE_CODE',
        'message': 'PRIVATE_PAYLOAD',
      });
      final result =
          await rpc.command('review_command', {}, (v) => v) as CommandError;
      expect(result.code, DomainErrorCode.unexpectedError);
      expect(result.safeMessage, isNot(contains('PRIVATE_')));
    },
  );

  test('Read sai DTO là unexpected; command thiếu ACK vẫn timeoutUnknown và giữ key', () async {
    backend.onRpc = (request) {
      if (request.url.path.endsWith('/review_command')) {
        expect(jsonDecode(request.body)['p_idempotency_key'], 'same-intent');
      }
      return workflowResponse({'ok': true, 'data': {}});
    };
    await expectLater(
      SupabaseTransactionQueryRepository(rpc).getMyTransactions(),
      throwsA(
        isA<AppError>().having(
          (e) => e.code,
          'code',
          DomainErrorCode.unexpectedError,
        ),
      ),
    );
    final result = await rpc.command('review_command', {
      'p_idempotency_key': 'same-intent',
    }, (v) => v) as CommandError;
    expect(result.code, DomainErrorCode.timeoutUnknown);
    final receipt = await rpc.receiptCommand(
      'review_receipt',
      {},
      (v) => v,
    ) as CommandError;
    expect(receipt.code, DomainErrorCode.timeoutUnknown);
  });

  test('Timeout đọc là lỗi mạng; timeout ghi phải đối soát ACK', () async {
    backend.onRpc = (_) => throw TimeoutException('PRIVATE_TIMEOUT_DETAIL');
    await expectLater(
      SupabaseIssueQueryRepository(rpc).getMyIssues(),
      throwsA(
        isA<AppError>().having(
          (e) => e.code,
          'code',
          DomainErrorCode.networkUnavailable,
        ),
      ),
    );
    expect(
      (await rpc.command('review_command', {}, (v) => v) as CommandError).code,
      DomainErrorCode.timeoutUnknown,
    );
  });
}

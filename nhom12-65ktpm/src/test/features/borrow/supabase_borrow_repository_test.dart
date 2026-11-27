import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/transaction.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/features/borrow/data/supabase_borrow_repository.dart';

import '../../support/workflow_rpc_fixture.dart';

void main() {
  late WorkflowTestBackend backend;
  late WorkflowRpc rpc;

  setUp(() async {
    backend = WorkflowTestBackend();
    await backend.login();
    rpc = WorkflowRpc(backend.client, workflowActorA);
  });

  tearDown(() {
    backend.dispose();
  });

  Map<String, dynamic> returnPendingFixture() {
    final Map<String, dynamic> fixture = transactionRpcFixture();

    fixture['transaction'] = <String, dynamic>{
      ...fixture['transaction'] as Map<String, dynamic>,
      'type': 'BORROW',
      'status': 'RETURN_PENDING',
      'agreedBorrowDays': 7,
      'agreedPriceVnd': null,
    };

    fixture['payment'] = null;

    fixture['borrowing'] = <String, dynamic>{
      'transactionId': 'transaction-1',
      'startedAt': '2026-11-20T09:00:00Z',
      'dueDateVn': '2026-11-28',
      'returnToCourierAt': null,
      'reHandoverDueDateVn': null,
    };

    fixture['allowedActions'] = <String>[
      'CAN_START_HANDOVER',
      'CAN_REPORT_ISSUE',
    ];

    return fixture;
  }

  test(
    'gọi đúng RPC request_borrow_return và giải mã RETURN_PENDING',
    () async {
      backend.onRpc = (_) {
        return workflowResponse(<String, dynamic>{
          'ok': true,
          'event_id': 'event-return-1',
          'data': returnPendingFixture(),
        });
      };

      final SupabaseBorrowRepository repository = SupabaseBorrowRepository(rpc);

      final CommandResult<StudyTransaction> result = await repository
          .requestReturn('transaction-1', idempotencyKey: 'return-key-1');

      expect(result, isA<CommandOk<StudyTransaction>>());

      final CommandOk<StudyTransaction> success =
          result as CommandOk<StudyTransaction>;

      expect(success.serverEventId, 'event-return-1');

      expect(success.data.id, 'transaction-1');

      expect(success.data.type, OfferType.borrow);

      expect(success.data.status, TransactionStatus.returnPending);

      expect(success.data.agreedBorrowDays, 7);

      expect(
        backend.requests.single.url.path,
        '/rest/v1/rpc/request_borrow_return',
      );
    },
  );

  test(
    'chỉ gửi transactionId và idempotency key, không gửi actor hoặc status',
    () async {
      backend.onRpc = (_) {
        return workflowResponse(<String, dynamic>{
          'ok': true,
          'event_id': 'event-return-2',
          'data': returnPendingFixture(),
        });
      };

      final SupabaseBorrowRepository repository = SupabaseBorrowRepository(rpc);

      await repository.requestReturn(
        ' transaction-1 ',
        idempotencyKey: ' return-key-2 ',
      );

      expect(backend.requests, hasLength(1));

      final Map<String, dynamic> body =
          jsonDecode(backend.requests.single.body) as Map<String, dynamic>;

      expect(body, <String, dynamic>{
        'p_transaction_id': 'transaction-1',
        'p_idempotency_key': 'return-key-2',
      });

      expect(body.containsKey('actorId'), isFalse);

      expect(body.containsKey('actor_id'), isFalse);

      expect(body.containsKey('ownerId'), isFalse);

      expect(body.containsKey('holderId'), isFalse);

      expect(body.containsKey('status'), isFalse);
    },
  );

  test('ID hoặc idempotency key rỗng bị chặn trước khi gửi RPC', () async {
    final SupabaseBorrowRepository repository = SupabaseBorrowRepository(rpc);

    final List<CommandResult<StudyTransaction>> results =
        <CommandResult<StudyTransaction>>[
          await repository.requestReturn('   ', idempotencyKey: 'return-key'),
          await repository.requestReturn(
            'transaction-1',
            idempotencyKey: '   ',
          ),
        ];

    for (final CommandResult<StudyTransaction> result in results) {
      expect(result, isA<CommandError<StudyTransaction>>());

      final CommandError<StudyTransaction> error =
          result as CommandError<StudyTransaction>;

      expect(error.code, DomainErrorCode.invalidInput);
    }

    expect(backend.requests, isEmpty);
  });

  test('lỗi nghiệp vụ từ backend không làm lộ raw message', () async {
    backend.onRpc = (_) {
      return workflowResponse(<String, dynamic>{
        'ok': false,
        'code': 'INVALID_TRANSACTION_TRANSITION',
        'message': 'SECRET_DATABASE_MESSAGE',
      });
    };

    final SupabaseBorrowRepository repository = SupabaseBorrowRepository(rpc);

    final CommandResult<StudyTransaction> result = await repository
        .requestReturn('transaction-1', idempotencyKey: 'return-key-error');

    expect(result, isA<CommandError<StudyTransaction>>());

    final CommandError<StudyTransaction> error =
        result as CommandError<StudyTransaction>;

    expect(error.code, DomainErrorCode.invalidTransactionTransition);

    expect(error.safeMessage, isNot(contains('SECRET_DATABASE_MESSAGE')));
  });

  test('ACK thiếu event_id không được báo thành công', () async {
    backend.onRpc = (_) {
      return workflowResponse(<String, dynamic>{
        'ok': true,
        'data': returnPendingFixture(),
      });
    };

    final SupabaseBorrowRepository repository = SupabaseBorrowRepository(rpc);

    final CommandResult<StudyTransaction> result = await repository
        .requestReturn('transaction-1', idempotencyKey: 'return-key-no-ack');

    expect(result, isA<CommandError<StudyTransaction>>());

    expect(
      (result as CommandError<StudyTransaction>).code,
      DomainErrorCode.timeoutUnknown,
    );
  });

  test('ACK có data sai định dạng không được báo thành công', () async {
    backend.onRpc = (_) {
      return workflowResponse(<String, dynamic>{
        'ok': true,
        'event_id': 'event-invalid-data',
        'data': <String, dynamic>{},
      });
    };

    final SupabaseBorrowRepository repository = SupabaseBorrowRepository(rpc);

    final CommandResult<StudyTransaction> result = await repository
        .requestReturn(
          'transaction-1',
          idempotencyKey: 'return-key-invalid-data',
        );

    expect(result, isA<CommandError<StudyTransaction>>());

    expect(
      (result as CommandError<StudyTransaction>).code,
      DomainErrorCode.timeoutUnknown,
    );
  });

  test('timeout giữ nguyên key để người dùng retry cùng thao tác', () async {
    final Completer<http.Response> waiting = Completer<http.Response>();

    backend.onRpc = (_) => waiting.future;

    final SupabaseBorrowRepository repository = SupabaseBorrowRepository(
      WorkflowRpc(
        backend.client,
        workflowActorA,
        timeout: const Duration(milliseconds: 25),
      ),
    );

    final CommandResult<StudyTransaction> first = await repository
        .requestReturn('transaction-1', idempotencyKey: 'stable-return-key');

    expect(first, isA<CommandError<StudyTransaction>>());

    expect(
      (first as CommandError<StudyTransaction>).code,
      DomainErrorCode.timeoutUnknown,
    );

    waiting.complete(
      workflowResponse(<String, dynamic>{
        'ok': true,
        'event_id': 'event-return-retry',
        'data': returnPendingFixture(),
      }),
    );

    backend.onRpc = (_) {
      return workflowResponse(<String, dynamic>{
        'ok': true,
        'event_id': 'event-return-retry',
        'data': returnPendingFixture(),
      });
    };

    final CommandResult<StudyTransaction> retry = await repository
        .requestReturn('transaction-1', idempotencyKey: 'stable-return-key');

    expect(retry, isA<CommandOk<StudyTransaction>>());

    expect(
      (retry as CommandOk<StudyTransaction>).serverEventId,
      'event-return-retry',
    );

    expect(
      backend.requests.map((http.BaseRequest request) {
        final http.Request typedRequest = request as http.Request;
        final Map<String, dynamic> body =
            jsonDecode(typedRequest.body) as Map<String, dynamic>;
        return body['p_idempotency_key'];
      }),
      <String>['stable-return-key', 'stable-return-key'],
    );
  });

  test('mất mạng không được báo command thành công', () async {
    backend.onRpc = (_) {
      throw http.ClientException('PRIVATE_ENDPOINT');
    };

    final SupabaseBorrowRepository repository = SupabaseBorrowRepository(rpc);

    final CommandResult<StudyTransaction> result = await repository
        .requestReturn(
          'transaction-1',
          idempotencyKey: 'return-key-network-error',
        );

    expect(result, isA<CommandError<StudyTransaction>>());

    expect(
      (result as CommandError<StudyTransaction>).code,
      DomainErrorCode.timeoutUnknown,
    );
  });
}

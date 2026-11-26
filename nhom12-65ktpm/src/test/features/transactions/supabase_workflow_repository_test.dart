import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/contracts/command_inputs.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/transaction.dart';
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
  tearDown(() => backend.dispose());

  test(
    'Transaction DTO: vai, giá snapshot, timestamp và allowedActions từ server',
    () async {
      backend.onRpc = (_) => workflowResponse([transactionRpcFixture()]);
      final records = await SupabaseTransactionQueryRepository(rpc)
          .getMyTransactions();
      final d = records.single;
      expect(d.transaction.agreedPriceVnd, 85000);
      expect(d.viewerRole, TransactionViewerRole.owner);
      expect(d.createdAt, DateTime.utc(2026, 11, 25, 2, 30));
      expect(d.payment!.isSellerConfirmed, isFalse);
      expect(d.can(TransactionAction.confirmSellerPayment), isTrue);
      expect(
        backend.requests.single.url.path,
        '/rest/v1/rpc/get_my_transactions',
      );
      expect(jsonDecode(backend.requests.single.body), isEmpty);
    },
  );

  test('BORROW giữ ngày VN, mốc giao hộ và hạn tái bàn giao độc lập', () async {
    final raw = transactionRpcFixture();
    raw['transaction'] = {
      ...raw['transaction'] as Map,
      'type': 'BORROW',
      'status': 'RETURN_IN_PROGRESS',
      'agreedBorrowDays': 7,
      'agreedPriceVnd': null,
    };
    raw['payment'] = null;
    raw['borrowing'] = {
      'transactionId': 'transaction-1',
      'startedAt': '2026-11-20T23:30:00+07:00',
      'dueDateVn': '2026-11-27',
      'returnToCourierAt': '2026-11-26T09:00:00+07:00',
      'reHandoverDueDateVn': '2026-11-30',
    };
    backend.onRpc = (_) => workflowResponse(raw);
    final d = (await SupabaseTransactionQueryRepository(rpc)
        .getTransactionDetails('transaction-1'))!;
    expect(d.borrowing!.dueDateVn, '2026-11-27');
    expect(d.borrowing!.startedAt, DateTime.utc(2026, 11, 20, 16, 30));
    expect(d.borrowing!.reHandoverDueDateVn, '2026-11-30');
    expect(d.payment, isNull);
  });

  test(
    'null/[] do server trả được giữ nguyên, không thêm dữ liệu mock',
    () async {
      backend.onRpc = (r) =>
          workflowResponse(r.url.path.endsWith('details') ? null : []);
      final tx = SupabaseTransactionQueryRepository(rpc);
      final issue = SupabaseIssueQueryRepository(rpc);
      expect(await tx.getTransactionDetails('unknown'), isNull);
      expect(await tx.getTimeline('unknown'), isEmpty);
      expect(await issue.getIssueDetails('unknown'), isNull);
      expect(await issue.getTimeline('unknown'), isEmpty);
    },
  );

  test(
    'Issue DTO chỉ lấy đồng thuận phiên bản hiện hành và quyền xem server',
    () async {
      backend.onRpc = (_) => workflowResponse([issueRpcFixture()]);
      final d = (await SupabaseIssueQueryRepository(rpc).getMyIssues()).single;
      expect(d.proposal!.revision, 2);
      expect(d.proposal!.approvedCount, 1);
      expect(d.proposal!.isFullyApproved, isFalse);
      expect(d.canViewEvidence, isFalse);
      expect(d.evidenceCount, 0);
    },
  );

  test(
    'Timeline Transaction/Issue ánh xạ đúng ID, actor và thời điểm server',
    () async {
      backend.onRpc = (request) => workflowResponse([
        {
          'id': 'event-1',
          if (request.url.path.contains('transaction'))
            'transactionId': 'transaction-1'
          else
            'issueId': 'issue-1',
          'eventType': 'CREATED',
          'serverAt': '2026-11-25T01:00:00Z',
          'safeDescription': 'Sự kiện an toàn',
          'actorDisplay': null,
        },
      ]);
      expect(
        (await SupabaseTransactionQueryRepository(rpc)
                .getTimeline('transaction-1'))
            .single
            .transactionId,
        'transaction-1',
      );
      expect(
        (await SupabaseIssueQueryRepository(rpc).getTimeline('issue-1'))
            .single
            .issueId,
        'issue-1',
      );
    },
  );

  test(
    'Tám lệnh tiền/hủy dùng đúng RPC, key và ACK, không gửi actor/status',
    () async {
      backend.onRpc = (_) => workflowResponse({
        'ok': true,
        'event_id': 'ack-1',
        'data': transactionRpcFixture(),
      });
      final pay = SupabaseSellerPaymentRepository(rpc);
      final cancel = SupabaseTransactionCancellationRepository(rpc);
      final calls = [
        () => pay.reportBuyerTransfer(
          'transaction-1',
          idempotencyKey: 'stable-key',
        ),
        () => pay.confirmSellerPayment(
          'transaction-1',
          idempotencyKey: 'stable-key',
        ),
        () => pay.reportSellerRefund(
          'transaction-1',
          idempotencyKey: 'stable-key',
        ),
        () => pay.confirmRefundReceived(
          'transaction-1',
          idempotencyKey: 'stable-key',
        ),
        () => cancel.proposeCancellation(
          'transaction-1',
          'Lý do hủy',
          idempotencyKey: 'stable-key',
        ),
        () => cancel.withdrawCancellation(
          'transaction-1',
          idempotencyKey: 'stable-key',
        ),
        () => cancel.declineCancellation(
          'transaction-1',
          idempotencyKey: 'stable-key',
        ),
        () => cancel.acceptCancellation(
          'transaction-1',
          idempotencyKey: 'stable-key',
        ),
      ];
      for (final call in calls) {
        final result = await call();
        expect(result, isA<CommandOk<TransactionDetails>>());
        expect((result as CommandOk).serverEventId, 'ack-1');
      }
      expect(backend.requests.map((r) => r.url.path.split('/').last), [
        'report_buyer_transfer',
        'confirm_seller_payment',
        'report_seller_refund',
        'confirm_refund_received',
        'propose_transaction_cancellation',
        'withdraw_transaction_cancellation',
        'decline_transaction_cancellation',
        'accept_transaction_cancellation',
      ]);
      for (final request in backend.requests) {
        final body = jsonDecode(request.body) as Map;
        expect(body['p_idempotency_key'], 'stable-key');
        expect(
          body.keys.toSet().difference({
            'p_transaction_id',
            'p_idempotency_key',
            'p_reason',
          }),
          isEmpty,
        );
      }
    },
  );

  test('Ba lệnh Issue giữ đúng context, revision và key cho RPC', () async {
    backend.onRpc = (_) => workflowResponse({
      'ok': true,
      'event_id': 'ack-issue',
      'data': issueRpcFixture(),
    });
    final issue = SupabaseIssueRepository(rpc);
    await issue.reportIssue(
      const CreateIssueInput(
        transactionId: 'transaction-1',
        type: IssueType.other,
        reason: 'Cần đối chiếu',
        handoverId: 'handover-1',
      ),
      idempotencyKey: 'create-key',
    );
    await issue.proposeResolution(
      'issue-1',
      'Phương án mới',
      idempotencyKey: 'proposal-key',
    );
    await issue.confirmResolution('issue-1', 2, idempotencyKey: 'consent-key');
    final body = jsonDecode(backend.requests.first.body) as Map;
    expect(body['p_handover_id'], 'handover-1');
    expect(body['p_issue_type'], 'OTHER');
    expect(jsonDecode(backend.requests.last.body)['p_resolution_revision'], 2);
    expect(backend.requests.map((r) => r.url.path.split('/').last), [
      'report_issue',
      'propose_issue_resolution',
      'confirm_issue_resolution',
    ]);
  });

  test(
    'Dữ liệu thiếu/sai và trạng thái lạ gây lỗi an toàn thay vì empty/mock',
    () async {
      final query = SupabaseTransactionQueryRepository(rpc);
      for (final response in [
        null,
        {},
        [
          {
            'transaction': {'status': 'INVENTED_STATUS'},
          },
        ],
      ]) {
        backend.onRpc = (_) => workflowResponse(response);
        await expectLater(
          query.getMyTransactions(),
          throwsA(
            isA<AppError>().having(
              (e) => e.code,
              'code',
              DomainErrorCode.unexpectedError,
            ),
          ),
        );
      }
    },
  );

  test(
    'Domain error và SQL permission không đưa message/payload thô lên UI',
    () async {
      backend.onRpc = (_) => workflowResponse({
        'ok': false,
        'code': 'CONFLICT',
        'message': 'SECRET_RAW_RESPONSE',
      });
      final pay = SupabaseSellerPaymentRepository(rpc);
      final result = await pay.confirmSellerPayment(
        'transaction-1',
        idempotencyKey: 'key',
      ) as CommandError;
      expect(result.code, DomainErrorCode.conflict);
      expect(result.safeMessage, isNot(contains('SECRET_RAW_RESPONSE')));
      backend.onRpc = (_) => workflowResponse({
        'code': '42501',
        'message': 'SECRET_RAW_RESPONSE',
        'details': null,
        'hint': null,
      }, status: 403);
      await expectLater(
        SupabaseTransactionQueryRepository(rpc).getMyTransactions(),
        throwsA(
          isA<AppError>().having(
            (e) => e.code,
            'code',
            DomainErrorCode.forbidden,
          ),
        ),
      );
    },
  );

  test(
    'Validate giới hạn trước khi gửi: lý do hủy/Issue, revision, key',
    () async {
      final cancel = SupabaseTransactionCancellationRepository(rpc);
      final issue = SupabaseIssueRepository(rpc);
      final results = [
        await cancel.proposeCancellation(
          'transaction-1',
          ' ',
          idempotencyKey: 'key',
        ),
        await cancel.proposeCancellation(
          'transaction-1',
          'x' * 501,
          idempotencyKey: 'key',
        ),
        await issue.reportIssue(
          CreateIssueInput(
            transactionId: 'transaction-1',
            type: IssueType.other,
            reason: 'x' * 1001,
          ),
          idempotencyKey: 'key',
        ),
        await issue.confirmResolution('issue-1', 0, idempotencyKey: 'key'),
        await issue.proposeResolution('issue-1', 'Tóm tắt', idempotencyKey: ''),
      ];
      for (final result in results) {
        expect((result as CommandError).code, DomainErrorCode.invalidInput);
      }
      expect(backend.requests, isEmpty);
    },
  );

  test('Timeout command giữ key retry và chỉ có ACK mới thành công', () async {
    final waiting = Completer<http.Response>();
    backend.onRpc = (_) => waiting.future;
    final pay = SupabaseSellerPaymentRepository(
      WorkflowRpc(
        backend.client,
        workflowActorA,
        timeout: const Duration(milliseconds: 25),
      ),
    );
    final first = await pay.confirmSellerPayment(
      'transaction-1',
      idempotencyKey: 'same-key',
    ) as CommandError;
    expect(first.code, DomainErrorCode.timeoutUnknown);
    waiting.complete(
      workflowResponse({
        'ok': true,
        'event_id': 'ack-1',
        'data': transactionRpcFixture(),
      }),
    );
    backend.onRpc = (_) => workflowResponse({
      'ok': true,
      'event_id': 'ack-1',
      'data': transactionRpcFixture(),
    });
    final retry = await pay.confirmSellerPayment(
      'transaction-1',
      idempotencyKey: 'same-key',
    );
    expect(retry, isA<CommandOk>());
    expect(
      backend.requests.map((r) => jsonDecode(r.body)['p_idempotency_key']),
      ['same-key', 'same-key'],
    );
  });

  test(
    'ACK sai định dạng và mất mạng không được báo command thành công',
    () async {
      final pay = SupabaseSellerPaymentRepository(rpc);
      for (final raw in [
        {'ok': true, 'data': transactionRpcFixture()},
        {'ok': true, 'event_id': 'e', 'data': {}},
      ]) {
        backend.onRpc = (_) => workflowResponse(raw);
        expect(
          (await pay.confirmSellerPayment(
            'transaction-1',
            idempotencyKey: 'key',
          ) as CommandError).code,
          DomainErrorCode.timeoutUnknown,
        );
      }
      backend.onRpc = (_) => throw http.ClientException('PRIVATE_ENDPOINT');
      expect(
        (await pay.confirmSellerPayment(
          'transaction-1',
          idempotencyKey: 'key',
        ) as CommandError).code,
        DomainErrorCode.timeoutUnknown,
      );
      await expectLater(
        SupabaseTransactionQueryRepository(rpc).getMyTransactions(),
        throwsA(
          isA<AppError>().having(
            (e) => e.code,
            'code',
            DomainErrorCode.networkUnavailable,
          ),
        ),
      );
    },
  );

  test(
    'Đổi tài khoản giữa request: không trả dữ liệu hay ACK của phiên trước',
    () async {
      final response = Completer<http.Response>();
      final sent = Completer<void>();
      backend.onRpc = (_) {
        sent.complete();
        return response.future;
      };
      final pending = SupabaseSellerPaymentRepository(
        rpc,
      ).confirmSellerPayment('transaction-1', idempotencyKey: 'old-actor-key');
      await sent.future;
      await backend.login(asB: true);
      response.complete(
        workflowResponse({
          'ok': true,
          'event_id': 'ack-old',
          'data': transactionRpcFixture(),
        }),
      );
      expect(
        (await pending as CommandError).code,
        DomainErrorCode.authRequired,
      );
      final before = backend.requests.length;
      await expectLater(
        SupabaseTransactionQueryRepository(rpc).getMyTransactions(),
        throwsA(isA<AppError>()),
      );
      expect(backend.requests.length, before);
    },
  );
}

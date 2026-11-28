import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/contracts/command_inputs.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/exchange_request.dart';
import 'package:studyshare/core/contracts/models/transaction.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/features/requests/data/supabase_request_repository.dart';

import '../../support/workflow_rpc_fixture.dart';

void main() {
  late WorkflowTestBackend backend;
  late WorkflowRpc rpc;
  late SupabaseRequestRepository repository;

  setUp(() async {
    backend = WorkflowTestBackend();
    await backend.login();
    rpc = WorkflowRpc(backend.client, workflowActorA);
    repository = SupabaseRequestRepository(rpc);
  });

  tearDown(() {
    backend.dispose();
  });

  Map<String, dynamic> requestFixture({
    String status = 'PENDING',
    int? requestedBorrowDays = 7,
  }) {
    return <String, dynamic>{
      'id': 'request-1',
      'listingId': 'listing-1',
      'requesterId': workflowActorA,
      'requestedBorrowDays': requestedBorrowDays,
      'status': status,
      'createdAt': '2026-11-27T09:00:00Z',
      'decidedAt': status == 'PENDING' ? null : '2026-11-27T10:00:00Z',
      'rejectReason': status == 'REJECTED'
          ? 'Tài liệu không còn phù hợp.'
          : null,
      'revision': status == 'PENDING' ? 1 : 2,
      'materialTitle': 'Giáo trình Giải tích',
      'materialSubject': 'Toán cao cấp',
      'offerType': 'BORROW',
      'ownerId': 'owner-1',
      'ownerDisplayName': 'Chủ tài liệu',
      'requesterDisplayName': 'Người gửi',
      'viewerRole': 'REQUESTER',
      'allowedActions': status == 'PENDING'
          ? <String>['CAN_CANCEL_REQUEST']
          : <String>[],
    };
  }

  Map<String, dynamic> requestReceipt({
    String status = 'PENDING',
    int? requestedBorrowDays = 7,
  }) {
    return <String, dynamic>{
      'ok': true,
      'command_id': 'command-request-1',
      'server_revision': status == 'PENDING' ? 1 : 2,
      'data': requestFixture(
        status: status,
        requestedBorrowDays: requestedBorrowDays,
      ),
    };
  }

  Map<String, dynamic> approvedTransactionFixture() {
    final Map<String, dynamic> fixture = transactionRpcFixture();

    fixture['transaction'] = <String, dynamic>{
      ...fixture['transaction'] as Map<String, dynamic>,
      'requestId': 'request-1',
      'listingId': 'listing-1',
      'type': 'BORROW',
      'status': 'AWAITING_HANDOVER',
      'agreedBorrowDays': 7,
      'agreedPriceVnd': null,
    };

    fixture['payment'] = null;
    fixture['borrowing'] = null;

    return fixture;
  }

  test('đọc danh sách Request và giải mã đúng dữ liệu lõi', () async {
    backend.onRpc = (_) {
      return workflowResponse(<Map<String, dynamic>>[
        requestFixture(),
        requestFixture(status: 'REJECTED', requestedBorrowDays: null),
      ]);
    };

    final List<ExchangeRequest> requests = await repository.getMyRequests();

    expect(requests, hasLength(2));
    expect(requests.first.id, 'request-1');
    expect(requests.first.status, ExchangeRequestStatus.pending);
    expect(requests.first.requestedBorrowDays, 7);
    expect(requests.last.status, ExchangeRequestStatus.rejected);

    expect(
      backend.requests.single.url.path,
      '/rest/v1/rpc/get_my_exchange_requests',
    );

    expect(jsonDecode(backend.requests.single.body), isEmpty);
  });

  test('tạo Request dùng đúng receipt RPC và không gửi actor/status', () async {
    backend.onRpc = (_) {
      return workflowResponse(requestReceipt());
    };

    final CommandResult<ExchangeRequest> result = await repository
        .createRequest(
          const CreateRequestInput(
            listingId: ' listing-1 ',
            requestedBorrowDays: 7,
          ),
          idempotencyKey: ' create-key ',
        );

    expect(result, isA<CommandOk<ExchangeRequest>>());

    final CommandOk<ExchangeRequest> success =
        result as CommandOk<ExchangeRequest>;

    expect(success.commandId, 'command-request-1');
    expect(success.serverRevision, 1);
    expect(success.serverEventId, isNull);
    expect(success.data.status, ExchangeRequestStatus.pending);

    expect(
      backend.requests.single.url.path,
      '/rest/v1/rpc/create_exchange_request',
    );

    final Map<String, dynamic> body =
        jsonDecode(backend.requests.single.body) as Map<String, dynamic>;

    expect(body, <String, dynamic>{
      'p_listing_id': 'listing-1',
      'p_requested_borrow_days': 7,
      'p_idempotency_key': 'create-key',
    });

    expect(body.containsKey('actorId'), isFalse);
    expect(body.containsKey('requesterId'), isFalse);
    expect(body.containsKey('status'), isFalse);
  });

  test('duyệt Request gọi RPC nguyên tử và giải mã Transaction', () async {
    backend.onRpc = (_) {
      return workflowResponse(<String, dynamic>{
        'ok': true,
        'event_id': 'event-request-accepted',
        'data': approvedTransactionFixture(),
      });
    };

    final CommandResult<StudyTransaction> result = await repository
        .approveRequest(' request-1 ', idempotencyKey: ' approve-key ');

    expect(result, isA<CommandOk<StudyTransaction>>());

    final CommandOk<StudyTransaction> success =
        result as CommandOk<StudyTransaction>;

    expect(success.serverEventId, 'event-request-accepted');

    expect(success.data.status, TransactionStatus.awaitingHandover);

    expect(success.data.requestId, 'request-1');
    expect(success.data.agreedBorrowDays, 7);

    expect(
      backend.requests.single.url.path,
      '/rest/v1/rpc/approve_exchange_request',
    );

    expect(jsonDecode(backend.requests.single.body), <String, dynamic>{
      'p_request_id': 'request-1',
      'p_idempotency_key': 'approve-key',
    });
  });

  test('từ chối Request gửi lý do đã trim và dùng receipt', () async {
    backend.onRpc = (_) {
      return workflowResponse(
        requestReceipt(status: 'REJECTED', requestedBorrowDays: 7),
      );
    };

    final CommandResult<ExchangeRequest> result = await repository
        .rejectRequest(
          ' request-1 ',
          ' Không còn phù hợp. ',
          idempotencyKey: ' reject-key ',
        );

    expect(result, isA<CommandOk<ExchangeRequest>>());

    final CommandOk<ExchangeRequest> success =
        result as CommandOk<ExchangeRequest>;

    expect(success.data.status, ExchangeRequestStatus.rejected);

    expect(success.serverRevision, 2);

    expect(
      backend.requests.single.url.path,
      '/rest/v1/rpc/reject_exchange_request',
    );

    expect(jsonDecode(backend.requests.single.body), <String, dynamic>{
      'p_request_id': 'request-1',
      'p_reason': 'Không còn phù hợp.',
      'p_idempotency_key': 'reject-key',
    });
  });

  test('rút Request gọi đúng cancel_pending_request', () async {
    backend.onRpc = (_) {
      return workflowResponse(
        requestReceipt(status: 'CANCELLED', requestedBorrowDays: 7),
      );
    };

    final CommandResult<ExchangeRequest> result = await repository
        .cancelPendingRequest(' request-1 ', idempotencyKey: ' cancel-key ');

    expect(result, isA<CommandOk<ExchangeRequest>>());

    expect(
      (result as CommandOk<ExchangeRequest>).data.status,
      ExchangeRequestStatus.cancelled,
    );

    expect(
      backend.requests.single.url.path,
      '/rest/v1/rpc/cancel_pending_request',
    );

    expect(jsonDecode(backend.requests.single.body), <String, dynamic>{
      'p_request_id': 'request-1',
      'p_idempotency_key': 'cancel-key',
    });
  });

  test('validation chặn input rỗng và số ngày ngoài 1 đến 30', () async {
    final List<CommandResult<Object>> results = <CommandResult<Object>>[
      await repository.createRequest(
        const CreateRequestInput(listingId: ' '),
        idempotencyKey: 'key',
      ),
      await repository.createRequest(
        const CreateRequestInput(
          listingId: 'listing-1',
          requestedBorrowDays: 0,
        ),
        idempotencyKey: 'key',
      ),
      await repository.createRequest(
        const CreateRequestInput(
          listingId: 'listing-1',
          requestedBorrowDays: 31,
        ),
        idempotencyKey: 'key',
      ),
      await repository.approveRequest(' ', idempotencyKey: 'key'),
      await repository.rejectRequest('request-1', ' ', idempotencyKey: 'key'),
      await repository.cancelPendingRequest('request-1', idempotencyKey: ' '),
    ];

    for (final CommandResult<Object> result in results) {
      expect(result, isA<CommandError<Object>>());
      expect(
        (result as CommandError<Object>).code,
        DomainErrorCode.invalidInput,
      );
    }

    expect(backend.requests, isEmpty);
  });

  test('lỗi nghiệp vụ không làm lộ raw message', () async {
    backend.onRpc = (_) {
      return workflowResponse(<String, dynamic>{
        'ok': false,
        'code': 'DUPLICATE_REQUEST',
        'message': 'SECRET_DATABASE_MESSAGE',
      });
    };

    final CommandResult<ExchangeRequest> result = await repository
        .createRequest(
          const CreateRequestInput(
            listingId: 'listing-1',
            requestedBorrowDays: 7,
          ),
          idempotencyKey: 'duplicate-key',
        );

    expect(result, isA<CommandError<ExchangeRequest>>());

    final CommandError<ExchangeRequest> error =
        result as CommandError<ExchangeRequest>;

    expect(error.code, DomainErrorCode.duplicateRequest);

    expect(error.safeMessage, isNot(contains('SECRET_DATABASE_MESSAGE')));
  });

  test('receipt hoặc ACK sai định dạng không được báo thành công', () async {
    backend.onRpc = (_) {
      return workflowResponse(<String, dynamic>{
        'ok': true,
        'server_revision': 1,
        'data': requestFixture(),
      });
    };

    final CommandResult<ExchangeRequest> createResult = await repository
        .createRequest(
          const CreateRequestInput(
            listingId: 'listing-1',
            requestedBorrowDays: 7,
          ),
          idempotencyKey: 'bad-receipt',
        );

    expect(createResult, isA<CommandError<ExchangeRequest>>());

    expect(
      (createResult as CommandError<ExchangeRequest>).code,
      DomainErrorCode.timeoutUnknown,
    );

    backend.requests.clear();

    backend.onRpc = (_) {
      return workflowResponse(<String, dynamic>{
        'ok': true,
        'data': approvedTransactionFixture(),
      });
    };

    final CommandResult<StudyTransaction> approveResult = await repository
        .approveRequest('request-1', idempotencyKey: 'bad-ack');

    expect(approveResult, isA<CommandError<StudyTransaction>>());

    expect(
      (approveResult as CommandError<StudyTransaction>).code,
      DomainErrorCode.timeoutUnknown,
    );
  });
}

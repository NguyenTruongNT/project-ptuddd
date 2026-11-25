import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/transaction.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/features/transactions/data/supabase_rpc_gateway.dart';
import 'package:studyshare/features/transactions/data/supabase_transaction_repositories.dart';

// JSON mẫu theo đúng dạng RPC Supabase dev trả về; chỉ dùng ID/tên giả.
Map<String, dynamic> _sellJson({
  String status = 'AWAITING_PAYMENT',
  List<String> actions = const ['CAN_CONFIRM_SELLER_PAYMENT'],
}) => {
  'transaction': {
    'id': 'txn-sell-1',
    'type': 'SELL',
    'status': status,
    'listingId': 'listing-1',
    'requestId': 'request-1',
    'materialId': 'material-1',
    'receiverId': 'user-b',
    'agreedPriceVnd': 50000,
    'agreedBorrowDays': null,
    'ownerAtAcceptance': 'user-a',
  },
  'viewerRole': 'OWNER',
  'createdAt': '2026-11-06T03:00:00+00:00',
  'materialTitle': 'Giải tích 1',
  'materialSubject': 'Toán',
  'ownerDisplayName': 'Người A',
  'receiverDisplayName': 'Người B',
  'borrowing': null,
  'payment': {
    'transactionId': 'txn-sell-1',
    'buyerReportedAt': '2026-11-07T01:00:00.12345+00:00',
    'sellerConfirmedAt': null,
    'refundReportedAt': null,
    'buyerRefundConfirmedAt': null,
  },
  'openIssueCount': 1,
  'cancellationProposal': {
    'reason': 'Đổi ý',
    'proposedAt': '2026-11-08T04:00:00+00:00',
    'proposedBy': 'RECEIVER',
  },
  'allowedActions': actions,
};

class _FakeRpc {
  final calls = <(String, Map<String, dynamic>)>[];
  Object? Function(String function, Map<String, dynamic> params) respond = (
    _,
    _,
  ) => null;
  bool session = true;

  SupabaseRpcGateway gateway() => SupabaseRpcGateway(
    invoke: (function, params) async {
      calls.add((function, params));
      return respond(function, params);
    },
    sessionValid: () => session,
    queryTimeout: const Duration(milliseconds: 200),
    commandTimeout: const Duration(milliseconds: 200),
  );
}

void main() {
  group('Đọc JSON giao dịch', () {
    test('parse đủ Transaction, Payment, đề nghị hủy và hành động', () {
      final details = parseTransactionDetails(_sellJson());
      expect(details.id, 'txn-sell-1');
      expect(details.transaction.type, OfferType.sell);
      expect(details.transaction.status, TransactionStatus.awaitingPayment);
      expect(details.transaction.agreedPriceVnd, 50000);
      expect(details.viewerRole, TransactionViewerRole.owner);
      expect(details.payment!.buyerReportedAt, isNotNull);
      expect(details.payment!.isSellerConfirmed, isFalse);
      expect(
        details.cancellationProposal!.proposedBy,
        TransactionViewerRole.receiver,
      );
      expect(details.openIssueCount, 1);
      expect(details.can(TransactionAction.confirmSellerPayment), isTrue);
      expect(details.createdAt.isUtc, isTrue);
    });

    test('bỏ qua mã hành động lạ thay vì làm vỡ màn hình', () {
      final details = parseTransactionDetails(
        _sellJson(actions: ['CAN_CONFIRM_SELLER_PAYMENT', 'CAN_FUTURE_THING']),
      );
      expect(details.allowedActions, {TransactionAction.confirmSellerPayment});
    });

    test('BORROW giữ nguyên ngày hạn lịch Việt Nam do server tính', () {
      final json = _sellJson()
        ..['payment'] = null
        ..['cancellationProposal'] = null
        ..['borrowing'] = {
          'transactionId': 'txn-sell-1',
          'startedAt': '2026-11-23T03:30:00+00:00',
          'dueDateVn': '2026-11-30',
          'returnToCourierAt': null,
          'reHandoverDueDateVn': null,
        };
      (json['transaction'] as Map)['type'] = 'BORROW';
      final details = parseTransactionDetails(json);
      expect(details.borrowing!.dueDateVn, '2026-11-30');
      expect(details.payment, isNull);
      expect(details.cancellationProposal, isNull);
    });
  });

  group('Truy vấn qua RPC', () {
    test('gọi đúng tên RPC và tham số, null khi không có quyền', () async {
      final rpc = _FakeRpc()
        ..respond = (function, _) => switch (function) {
          'get_my_transactions' => [_sellJson()],
          'get_transaction_timeline' => [
            {
              'id': 'event-1',
              'serverAt': '2026-11-06T03:00:00+00:00',
              'eventType': 'TRANSACTION_CREATED',
              'actorDisplay': 'Người A',
              'transactionId': 'txn-sell-1',
              'safeDescription': 'Tạo giao dịch.',
            },
          ],
          _ => null,
        };
      final repo = SupabaseTransactionQueryRepository(rpc.gateway());

      expect(await repo.getMyTransactions(), hasLength(1));
      expect(await repo.getTransactionDetails('txn-hidden'), isNull);
      final timeline = await repo.getTimeline('txn-sell-1');
      expect(timeline.single.eventType, 'TRANSACTION_CREATED');
      expect(rpc.calls.map((c) => c.$1), [
        'get_my_transactions',
        'get_transaction_details',
        'get_transaction_timeline',
      ]);
      expect(rpc.calls[1].$2, {'p_transaction_id': 'txn-hidden'});
    });

    test('không có phiên thì báo AUTH_REQUIRED và không gọi server', () async {
      final rpc = _FakeRpc()..session = false;
      final repo = SupabaseTransactionQueryRepository(rpc.gateway());
      await expectLater(
        repo.getMyTransactions(),
        throwsA(
          isA<AppError>().having(
            (e) => e.code,
            'code',
            DomainErrorCode.authRequired,
          ),
        ),
      );
      expect(rpc.calls, isEmpty);
    });

    test('lỗi mạng trở thành NETWORK_UNAVAILABLE an toàn', () async {
      final rpc = _FakeRpc()..respond = (_, _) => throw const SocketishError();
      final repo = SupabaseTransactionQueryRepository(rpc.gateway());
      await expectLater(
        repo.getMyTransactions(),
        throwsA(
          isA<AppError>().having(
            (e) => e.code,
            'code',
            DomainErrorCode.networkUnavailable,
          ),
        ),
      );
    });
  });

  group('Lệnh thanh toán và hủy', () {
    test('ok:true trả snapshot mới kèm event_id của server', () async {
      final rpc = _FakeRpc()
        ..respond = (_, _) => {
          'ok': true,
          'data': _sellJson(status: 'AWAITING_HANDOVER', actions: const []),
          'event_id': 'event-9',
        };
      final repo = SupabaseSellerPaymentRepository(rpc.gateway());
      final result = await repo.confirmSellerPayment(
        'txn-sell-1',
        idempotencyKey: 'k1',
      );

      expect(result, isA<CommandOk<TransactionDetails>>());
      final ok = result as CommandOk<TransactionDetails>;
      expect(ok.serverEventId, 'event-9');
      expect(ok.data.transaction.status, TransactionStatus.awaitingHandover);
      expect(rpc.calls.single.$1, 'confirm_seller_payment');
      // Không gửi actorId/status: server tự lấy từ auth.uid().
      expect(rpc.calls.single.$2, {
        'p_transaction_id': 'txn-sell-1',
        'p_idempotency_key': 'k1',
      });
    });

    test('ok:false giữ mã lỗi và thông điệp an toàn của server', () async {
      final rpc = _FakeRpc()
        ..respond = (_, _) => {
          'ok': false,
          'code': 'INVALID_TRANSACTION_TRANSITION',
          'message': 'Giao dịch này không có thanh toán.',
        };
      final repo = SupabaseSellerPaymentRepository(rpc.gateway());
      final result = await repo.reportBuyerTransfer(
        'txn-1',
        idempotencyKey: 'k2',
      );
      expect(
        result,
        isA<CommandError<TransactionDetails>>()
            .having(
              (e) => e.code,
              'code',
              DomainErrorCode.invalidTransactionTransition,
            )
            .having(
              (e) => e.safeMessage,
              'message',
              'Giao dịch này không có thanh toán.',
            ),
      );
    });

    test('timeout không được coi là thành công (TIMEOUT_UNKNOWN)', () async {
      final rpc = _FakeRpc()..respond = (_, _) => Completer<Object?>().future;
      final repo = SupabaseTransactionCancellationRepository(rpc.gateway());
      final result = await repo.acceptCancellation(
        'txn-1',
        idempotencyKey: 'k3',
      );
      expect(
        result,
        isA<CommandError<TransactionDetails>>().having(
          (e) => e.code,
          'code',
          DomainErrorCode.timeoutUnknown,
        ),
      );
    });

    test('thiếu event_id thì không báo thành công', () async {
      final rpc = _FakeRpc()
        ..respond = (_, _) => {'ok': true, 'data': _sellJson()};
      final repo = SupabaseTransactionCancellationRepository(rpc.gateway());
      final result = await repo.withdrawCancellation(
        'txn-1',
        idempotencyKey: 'k4',
      );
      expect((result as CommandError).code, DomainErrorCode.timeoutUnknown);
    });

    test('PostgrestException permission denied thành FORBIDDEN', () async {
      final rpc = _FakeRpc()
        ..respond = (_, _) => throw const PostgrestException(
          message: 'permission denied for function x',
          code: '42501',
        );
      final repo = SupabaseTransactionCancellationRepository(rpc.gateway());
      final result = await repo.proposeCancellation(
        'txn-1',
        'Lý do',
        idempotencyKey: 'k5',
      );
      expect((result as CommandError).code, DomainErrorCode.forbidden);
      expect(rpc.calls.single.$1, 'propose_transaction_cancellation');
      expect(rpc.calls.single.$2['p_reason'], 'Lý do');
    });

    test('đổi phiên giữa chừng thì bỏ kết quả (AUTH_REQUIRED)', () async {
      final rpc = _FakeRpc();
      rpc.respond = (_, _) {
        rpc.session = false;
        return {'ok': true, 'data': _sellJson(), 'event_id': 'event-1'};
      };
      final repo = SupabaseTransactionCancellationRepository(rpc.gateway());
      final result = await repo.declineCancellation(
        'txn-1',
        idempotencyKey: 'k6',
      );
      expect((result as CommandError).code, DomainErrorCode.authRequired);
    });
  });
}

class SocketishError implements Exception {
  const SocketishError();
}

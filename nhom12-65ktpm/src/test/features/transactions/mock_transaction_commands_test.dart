import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/transaction.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';
import 'package:studyshare/core/mock/mock_transaction_query_repository.dart';
import 'package:studyshare/core/mock/mock_transaction_store.dart';
import 'package:studyshare/features/transactions/data/mock_command_runner.dart';
import 'package:studyshare/features/transactions/data/mock_seller_payment_repository.dart';
import 'package:studyshare/features/transactions/data/mock_transaction_cancellation_repository.dart';

const _sell = 'txn-sell-01';
const _borrow = 'txn-borrow-01';
const _donate = 'txn-delivery-01';

// Một "server" mock dùng chung cho các actor trong cùng test.
class _World {
  final store = MockTransactionStore.fromFixtures(
    clock: () => DateTime.utc(2026, 11, 22, 3),
  );

  MockSellerPaymentRepository payment(String actor) =>
      MockSellerPaymentRepository(MockCommandRunner(store: store, actorId: actor));

  MockTransactionCancellationRepository cancel(String actor) =>
      MockTransactionCancellationRepository(
          MockCommandRunner(store: store, actorId: actor));

  Future<TransactionDetails> details(String actor, String id) async =>
      (await MockTransactionQueryRepository(demoViewerId: actor, store: store)
          .getTransactionDetails(id))!;
}

void expectError(CommandResult<TransactionDetails> result, DomainErrorCode code) {
  expect(result, isA<CommandError<TransactionDetails>>());
  expect((result as CommandError<TransactionDetails>).code, code);
}

TransactionDetails expectOk(CommandResult<TransactionDetails> result) {
  expect(result, isA<CommandOk<TransactionDetails>>(),
      reason: result is CommandError<TransactionDetails> ? result.safeMessage : null);
  return (result as CommandOk<TransactionDetails>).data;
}

void main() {
  const a = MockFixtures.userA;
  const b = MockFixtures.userB;

  group('Thanh toán SELL', () {
    test('A xác nhận tiền: AWAITING_HANDOVER, ghi Event, mở bàn giao (S7.6)', () async {
      final world = _World();
      final before = world.store.events(_sell).length;
      final data = expectOk(
          await world.payment(a).confirmSellerPayment(_sell, idempotencyKey: 'k1'));

      expect(data.transaction.status, TransactionStatus.awaitingHandover);
      expect(data.payment?.sellerConfirmedAt, DateTime.utc(2026, 11, 22, 3));
      expect(data.can(TransactionAction.startHandover), isTrue);
      expect(world.store.events(_sell).length, before + 1);
      expect(world.store.events(_sell).last.eventType, 'SELLER_PAYMENT_CONFIRMED');
    });

    test('B không thể xác nhận tiền thay A (SON-T07)', () async {
      final world = _World();
      expectError(await world.payment(b).confirmSellerPayment(_sell, idempotencyKey: 'k1'),
          DomainErrorCode.forbidden);
      expect((await world.details(a, _sell)).transaction.status,
          TransactionStatus.awaitingPayment);
    });

    test('Retry cùng key không nhân đôi Event; key mới bị từ chối (SON-T08)', () async {
      final world = _World();
      final repo = world.payment(a);
      final first = await repo.confirmSellerPayment(_sell, idempotencyKey: 'same');
      final count = world.store.events(_sell).length;
      final retry = await repo.confirmSellerPayment(_sell, idempotencyKey: 'same');

      expect((retry as CommandOk).serverEventId, (first as CommandOk).serverEventId);
      expect(world.store.events(_sell).length, count);
      expectError(await repo.confirmSellerPayment(_sell, idempotencyKey: 'other'),
          DomainErrorCode.invalidTransactionTransition);
      expect(world.store.events(_sell).length, count);
    });

    test('B đã báo chuyển khoản thì không báo lại; status giữ nguyên (SON-T06)', () async {
      final world = _World();
      expectError(await world.payment(b).reportBuyerTransfer(_sell, idempotencyKey: 'k'),
          DomainErrorCode.invalidTransactionTransition);
      final d = await world.details(b, _sell);
      expect(d.transaction.status, TransactionStatus.awaitingPayment);
      expect(d.payment?.isSellerConfirmed, isFalse);
    });

    test('Giao dịch không phải SELL không có thanh toán', () async {
      final world = _World();
      expectError(await world.payment(a).confirmSellerPayment(_donate, idempotencyKey: 'k'),
          DomainErrorCode.invalidTransactionTransition);
    });

    test('Người ngoài và C bị từ chối, không lộ giao dịch', () async {
      final world = _World();
      for (final actor in [MockFixtures.outsider, MockFixtures.userC]) {
        expectError(
            await world.payment(actor).confirmSellerPayment(_sell, idempotencyKey: 'k'),
            DomainErrorCode.forbidden);
      }
    });

    test('Thiếu idempotency key bị từ chối', () async {
      final world = _World();
      expectError(await world.payment(a).confirmSellerPayment(_sell, idempotencyKey: ' '),
          DomainErrorCode.invalidInput);
    });
  });

  group('Hủy giao dịch (BR-45, AC-20)', () {
    test('B đề nghị, A đồng ý khi chưa có tiền/sách: CANCELLED', () async {
      final world = _World();
      final proposed = expectOk(await world
          .cancel(b)
          .proposeCancellation(_sell, '  Đổi ý  ', idempotencyKey: 'p1'));
      expect(proposed.cancellationProposal?.reason, 'Đổi ý');
      expect(proposed.cancellationProposal?.proposedBy, TransactionViewerRole.receiver);
      expect(proposed.can(TransactionAction.withdrawCancellation), isTrue);
      expect((await world.details(a, _sell)).can(TransactionAction.respondCancellation),
          isTrue);

      final done = expectOk(
          await world.cancel(a).acceptCancellation(_sell, idempotencyKey: 'a1'));
      expect(done.transaction.status, TransactionStatus.cancelled);
      expect(done.cancellationProposal, isNull);
      expect(done.allowedActions, isEmpty);
      expect(world.store.events(_sell).last.eventType, 'TRANSACTION_CANCELLED');
    });

    test('Người đề nghị không thể tự đồng ý (không hủy một phía)', () async {
      final world = _World();
      await world.cancel(b).proposeCancellation(_sell, 'Lý do', idempotencyKey: 'p');
      expectError(await world.cancel(b).acceptCancellation(_sell, idempotencyKey: 'a'),
          DomainErrorCode.forbidden);
    });

    test('Lý do rỗng và đề nghị trùng bị chặn', () async {
      final world = _World();
      expectError(await world.cancel(a).proposeCancellation(_sell, '   ', idempotencyKey: 'p'),
          DomainErrorCode.invalidInput);
      await world.cancel(a).proposeCancellation(_sell, 'Lý do', idempotencyKey: 'p2');
      expectError(await world.cancel(b).proposeCancellation(_sell, 'Khác', idempotencyKey: 'p3'),
          DomainErrorCode.conflict);
    });

    test('Cùng key nhưng nội dung khác -> CONFLICT', () async {
      final world = _World();
      final repo = world.cancel(a);
      expectOk(await repo.proposeCancellation(_sell, 'Lý do 1', idempotencyKey: 'dup'));
      expectError(await repo.proposeCancellation(_sell, 'Lý do 2', idempotencyKey: 'dup'),
          DomainErrorCode.conflict);
    });

    test('BORROW khi B đang giữ sách: không được hủy (AC-20)', () async {
      final world = _World();
      await world.cancel(a).proposeCancellation(_borrow, 'Cần sách gấp', idempotencyKey: 'p');
      expectError(await world.cancel(b).acceptCancellation(_borrow, idempotencyKey: 'a'),
          DomainErrorCode.cancellationObligationPending);
      expect((await world.details(a, _borrow)).transaction.status,
          TransactionStatus.borrowing);
    });

    test('Còn nhiệm vụ giao hộ chưa kết thúc: không được hủy', () async {
      final world = _World();
      await world.cancel(b).proposeCancellation(_donate, 'Không cần nữa', idempotencyKey: 'p');
      expectError(await world.cancel(a).acceptCancellation(_donate, idempotencyKey: 'a'),
          DomainErrorCode.cancellationObligationPending);
    });

    test('Không đồng ý / rút lại giữ nguyên giao dịch', () async {
      final world = _World();
      await world.cancel(a).proposeCancellation(_sell, 'Lý do', idempotencyKey: 'p1');
      expectError(await world.cancel(a).declineCancellation(_sell, idempotencyKey: 'd0'),
          DomainErrorCode.forbidden);
      final declined =
          expectOk(await world.cancel(b).declineCancellation(_sell, idempotencyKey: 'd1'));
      expect(declined.cancellationProposal, isNull);
      expect(declined.transaction.status, TransactionStatus.awaitingPayment);

      await world.cancel(a).proposeCancellation(_sell, 'Lần 2', idempotencyKey: 'p2');
      expectError(await world.cancel(b).withdrawCancellation(_sell, idempotencyKey: 'w0'),
          DomainErrorCode.forbidden);
      final withdrawn =
          expectOk(await world.cancel(a).withdrawCancellation(_sell, idempotencyKey: 'w1'));
      expect(withdrawn.cancellationProposal, isNull);
    });
  });

  test('SELL đã nhận tiền: hủy chỉ sau khi hoàn tiền và B xác nhận (AC-25)', () async {
    final world = _World();
    expectOk(await world.payment(a).confirmSellerPayment(_sell, idempotencyKey: 'pay'));
    expectError(await world.payment(a).reportSellerRefund(_sell, idempotencyKey: 'r0'),
        DomainErrorCode.invalidTransactionTransition); // Chưa có đề nghị hủy.

    expectOk(await world.cancel(a).proposeCancellation(_sell, 'Hết hàng', idempotencyKey: 'p'));
    expectError(await world.cancel(b).acceptCancellation(_sell, idempotencyKey: 'a1'),
        DomainErrorCode.cancellationObligationPending);
    expectError(await world.payment(b).confirmRefundReceived(_sell, idempotencyKey: 'c0'),
        DomainErrorCode.invalidTransactionTransition); // A chưa báo hoàn.
    expectError(await world.payment(b).reportSellerRefund(_sell, idempotencyKey: 'r1'),
        DomainErrorCode.forbidden);

    final refunded =
        expectOk(await world.payment(a).reportSellerRefund(_sell, idempotencyKey: 'r2'));
    expect(refunded.payment?.refundReportedAt, isNotNull);
    expect((await world.details(b, _sell)).can(TransactionAction.confirmRefundReceived),
        isTrue);
    // A báo hoàn tiền vẫn chưa đủ: cần B xác nhận.
    expectError(await world.cancel(b).acceptCancellation(_sell, idempotencyKey: 'a2'),
        DomainErrorCode.cancellationObligationPending);

    expectOk(await world.payment(b).confirmRefundReceived(_sell, idempotencyKey: 'c1'));
    final done = expectOk(await world.cancel(b).acceptCancellation(_sell, idempotencyKey: 'a3'));
    expect(done.transaction.status, TransactionStatus.cancelled);
    expect(done.payment?.hasOutstandingRefund, isFalse);
  });
}

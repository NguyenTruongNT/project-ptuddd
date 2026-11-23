import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../../core/contracts/repositories/transaction_repository.dart';
import '../../../core/errors/app_error.dart';
import 'mock_command_runner.dart';

// Mô phỏng RPC thanh toán SELL (BR-25..29). Tiền chuyển ngoài ứng dụng;
// lệnh chỉ ghi nhận lời xác nhận của đúng người.
class MockSellerPaymentRepository implements SellerPaymentRepository {
  MockSellerPaymentRepository(this._runner);

  final MockCommandRunner _runner;

  static const _notSell = MockMutationFail(
    DomainErrorCode.invalidTransactionTransition,
    'Giao dịch này không có thanh toán.',
  );

  @override
  Future<CommandResult<TransactionDetails>> reportBuyerTransfer(
    String transactionId, {required String idempotencyKey}) =>
      _runner.run(
        command: 'report_buyer_transfer',
        transactionId: transactionId,
        idempotencyKey: idempotencyKey,
        body: (txn, role) {
          if (txn.type != OfferType.sell) return _notSell;
          if (role != TransactionViewerRole.receiver) {
            return const MockMutationFail(DomainErrorCode.forbidden,
                'Chỉ người mua được báo đã chuyển khoản.');
          }
          if (txn.status != TransactionStatus.awaitingPayment) {
            return const MockMutationFail(
                DomainErrorCode.invalidTransactionTransition,
                'Giao dịch không còn ở bước chờ thanh toán.');
          }
          final store = _runner.store;
          final payment = store.payment(txn.id);
          if (payment?.buyerReportedAt != null) {
            return const MockMutationFail(
                DomainErrorCode.invalidTransactionTransition,
                'Bạn đã báo chuyển khoản trước đó.');
          }
          // Chỉ ghi buyer_reported_at; Transaction vẫn AWAITING_PAYMENT.
          store.putPayment(copyPayment(payment, txn.id,
              buyerReportedAt: store.clock()));
          return MockMutationOk(store.appendEvent(
            transactionId: txn.id,
            eventType: 'PAYMENT_REPORTED',
            safeDescription:
                'Người mua báo đã chuyển khoản. Chờ người bán kiểm tra và xác nhận.',
            actorDisplay: _runner.actorDisplay,
          ));
        },
      );

  @override
  Future<CommandResult<TransactionDetails>> confirmSellerPayment(
    String transactionId, {required String idempotencyKey}) =>
      _runner.run(
        command: 'confirm_seller_payment',
        transactionId: transactionId,
        idempotencyKey: idempotencyKey,
        body: (txn, role) {
          if (txn.type != OfferType.sell) return _notSell;
          if (role != TransactionViewerRole.owner) {
            return const MockMutationFail(DomainErrorCode.forbidden,
                'Chỉ người bán được xác nhận đã nhận tiền.');
          }
          final store = _runner.store;
          final payment = store.payment(txn.id);
          if (payment?.isSellerConfirmed ?? false) {
            return const MockMutationFail(
                DomainErrorCode.invalidTransactionTransition,
                'Người bán đã xác nhận nhận tiền trước đó.');
          }
          if (txn.status != TransactionStatus.awaitingPayment) {
            return const MockMutationFail(
                DomainErrorCode.invalidTransactionTransition,
                'Giao dịch không còn ở bước chờ thanh toán.');
          }
          // Một lần duy nhất: ghi seller_confirmed_at + AWAITING_HANDOVER + Event.
          store.putPayment(copyPayment(payment, txn.id,
              sellerConfirmedAt: store.clock()));
          store.setStatus(txn.id, TransactionStatus.awaitingHandover);
          return MockMutationOk(store.appendEvent(
            transactionId: txn.id,
            eventType: 'SELLER_PAYMENT_CONFIRMED',
            safeDescription:
                'Người bán xác nhận đã nhận đủ tiền. Có thể bắt đầu bàn giao.',
            actorDisplay: _runner.actorDisplay,
          ));
        },
      );

  @override
  Future<CommandResult<TransactionDetails>> reportSellerRefund(
    String transactionId, {required String idempotencyKey}) =>
      _runner.run(
        command: 'report_seller_refund',
        transactionId: transactionId,
        idempotencyKey: idempotencyKey,
        body: (txn, role) {
          if (txn.type != OfferType.sell) return _notSell;
          if (role != TransactionViewerRole.owner) {
            return const MockMutationFail(DomainErrorCode.forbidden,
                'Chỉ người bán được báo đã hoàn tiền.');
          }
          final store = _runner.store;
          final payment = store.payment(txn.id);
          if (txn.status.isTerminal || store.cancellation(txn.id) == null) {
            return const MockMutationFail(
                DomainErrorCode.invalidTransactionTransition,
                'Chỉ hoàn tiền khi đang có đề nghị hủy giao dịch.');
          }
          if (!(payment?.isSellerConfirmed ?? false)) {
            return const MockMutationFail(
                DomainErrorCode.invalidTransactionTransition,
                'Chưa có khoản tiền nào được người bán xác nhận.');
          }
          if (payment?.refundReportedAt != null) {
            return const MockMutationFail(
                DomainErrorCode.invalidTransactionTransition,
                'Bạn đã báo hoàn tiền trước đó.');
          }
          store.putPayment(copyPayment(payment, txn.id,
              refundReportedAt: store.clock()));
          return MockMutationOk(store.appendEvent(
            transactionId: txn.id,
            eventType: 'REFUND_REPORTED',
            safeDescription:
                'Người bán báo đã hoàn tiền ngoài ứng dụng. Chờ người mua xác nhận.',
            actorDisplay: _runner.actorDisplay,
          ));
        },
      );

  @override
  Future<CommandResult<TransactionDetails>> confirmRefundReceived(
    String transactionId, {required String idempotencyKey}) =>
      _runner.run(
        command: 'confirm_refund_received',
        transactionId: transactionId,
        idempotencyKey: idempotencyKey,
        body: (txn, role) {
          if (txn.type != OfferType.sell) return _notSell;
          if (role != TransactionViewerRole.receiver) {
            return const MockMutationFail(DomainErrorCode.forbidden,
                'Chỉ người mua được xác nhận đã nhận lại tiền.');
          }
          final store = _runner.store;
          final payment = store.payment(txn.id);
          if (payment?.refundReportedAt == null) {
            return const MockMutationFail(
                DomainErrorCode.invalidTransactionTransition,
                'Người bán chưa báo hoàn tiền.');
          }
          if (payment?.buyerRefundConfirmedAt != null) {
            return const MockMutationFail(
                DomainErrorCode.invalidTransactionTransition,
                'Bạn đã xác nhận nhận lại tiền trước đó.');
          }
          store.putPayment(copyPayment(payment, txn.id,
              buyerRefundConfirmedAt: store.clock()));
          return MockMutationOk(store.appendEvent(
            transactionId: txn.id,
            eventType: 'REFUND_CONFIRMED',
            safeDescription: 'Người mua xác nhận đã nhận lại đủ tiền.',
            actorDisplay: _runner.actorDisplay,
          ));
        },
      );
}

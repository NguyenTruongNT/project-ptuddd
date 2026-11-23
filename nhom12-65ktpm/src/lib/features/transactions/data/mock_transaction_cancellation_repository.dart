import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../../core/contracts/repositories/transaction_repository.dart';
import '../../../core/errors/app_error.dart';
import 'mock_command_runner.dart';

// Mô phỏng RPC hủy Transaction (BR-45, STATE_MACHINES §9):
// một bên đề nghị, bên còn lại đồng ý; chỉ CANCELLED khi không còn nghĩa vụ
// sách / tiền / Issue. Không có "Force Cancel".
class MockTransactionCancellationRepository
    implements TransactionCancellationRepository {
  MockTransactionCancellationRepository(this._runner);

  final MockCommandRunner _runner;

  static const maxReasonLength = 500;

  static const _terminal = MockMutationFail(
    DomainErrorCode.invalidTransactionTransition,
    'Giao dịch đã kết thúc.',
  );
  static const _noProposal = MockMutationFail(
    DomainErrorCode.invalidTransactionTransition,
    'Không có đề nghị hủy nào đang chờ.',
  );

  @override
  Future<CommandResult<TransactionDetails>> proposeCancellation(
    String transactionId, String reason, {required String idempotencyKey}) {
    final trimmed = reason.trim();
    return _runner.run(
      command: 'propose_transaction_cancellation',
      transactionId: transactionId,
      idempotencyKey: idempotencyKey,
      payload: trimmed,
      body: (txn, role) {
        if (trimmed.isEmpty) {
          return const MockMutationFail(
              DomainErrorCode.invalidInput, 'Vui lòng nhập lý do hủy.');
        }
        if (trimmed.length > maxReasonLength) {
          return const MockMutationFail(DomainErrorCode.invalidInput,
              'Lý do hủy tối đa $maxReasonLength ký tự.');
        }
        if (txn.status.isTerminal) return _terminal;
        final store = _runner.store;
        if (store.cancellation(txn.id) != null) {
          return const MockMutationFail(DomainErrorCode.conflict,
              'Đã có đề nghị hủy đang chờ phản hồi.');
        }
        store.putCancellation(
          txn.id,
          CancellationProposal(
            proposedBy: role,
            reason: trimmed,
            proposedAt: store.clock(),
          ),
        );
        return MockMutationOk(store.appendEvent(
          transactionId: txn.id,
          eventType: 'CANCELLATION_PROPOSED',
          safeDescription: 'Có đề nghị hủy giao dịch, chờ bên còn lại phản hồi.',
          actorDisplay: _runner.actorDisplay,
        ));
      },
    );
  }

  @override
  Future<CommandResult<TransactionDetails>> withdrawCancellation(
    String transactionId, {required String idempotencyKey}) =>
      _runner.run(
        command: 'withdraw_transaction_cancellation',
        transactionId: transactionId,
        idempotencyKey: idempotencyKey,
        body: (txn, role) {
          final store = _runner.store;
          final proposal = store.cancellation(txn.id);
          if (proposal == null) return _noProposal;
          if (proposal.proposedBy != role) {
            return const MockMutationFail(DomainErrorCode.forbidden,
                'Chỉ người đề nghị được rút lại đề nghị hủy.');
          }
          store.putCancellation(txn.id, null);
          return MockMutationOk(store.appendEvent(
            transactionId: txn.id,
            eventType: 'CANCELLATION_WITHDRAWN',
            safeDescription: 'Đề nghị hủy đã được rút lại.',
            actorDisplay: _runner.actorDisplay,
          ));
        },
      );

  @override
  Future<CommandResult<TransactionDetails>> declineCancellation(
    String transactionId, {required String idempotencyKey}) =>
      _runner.run(
        command: 'decline_transaction_cancellation',
        transactionId: transactionId,
        idempotencyKey: idempotencyKey,
        body: (txn, role) {
          final store = _runner.store;
          final proposal = store.cancellation(txn.id);
          if (proposal == null) return _noProposal;
          if (proposal.proposedBy == role) {
            return const MockMutationFail(DomainErrorCode.forbidden,
                'Bên còn lại mới được phản hồi đề nghị hủy.');
          }
          store.putCancellation(txn.id, null);
          return MockMutationOk(store.appendEvent(
            transactionId: txn.id,
            eventType: 'CANCELLATION_DECLINED',
            safeDescription: 'Đề nghị hủy bị từ chối, giao dịch tiếp tục.',
            actorDisplay: _runner.actorDisplay,
          ));
        },
      );

  @override
  Future<CommandResult<TransactionDetails>> acceptCancellation(
    String transactionId, {required String idempotencyKey}) =>
      _runner.run(
        command: 'accept_transaction_cancellation',
        transactionId: transactionId,
        idempotencyKey: idempotencyKey,
        body: (txn, role) {
          final store = _runner.store;
          final proposal = store.cancellation(txn.id);
          if (txn.status.isTerminal) return _terminal;
          if (proposal == null) return _noProposal;
          if (proposal.proposedBy == role) {
            return const MockMutationFail(DomainErrorCode.forbidden,
                'Cần bên còn lại đồng ý mới được hủy.');
          }
          final blocker = cancellationBlocker(txn);
          if (blocker != null) return blocker;

          // Nguyên tử: CANCELLED + đóng đề nghị + Event; owner/holder giữ nguyên.
          store.setStatus(txn.id, TransactionStatus.cancelled);
          store.putCancellation(txn.id, null);
          return MockMutationOk(store.appendEvent(
            transactionId: txn.id,
            eventType: 'TRANSACTION_CANCELLED',
            safeDescription:
                'Hai bên đồng ý hủy giao dịch. Tin đăng cũ được lưu trữ.',
            actorDisplay: _runner.actorDisplay,
          ));
        },
      );

  // Nghĩa vụ còn mở chặn việc hủy (SS-BR §10).
  MockMutationFail? cancellationBlocker(StudyTransaction txn) {
    final store = _runner.store;
    if (store.openIssueCount(txn.id) > 0) {
      return const MockMutationFail(DomainErrorCode.issueBlockingAction,
          'Còn sự cố đang mở. Hãy giải quyết sự cố trước khi hủy.');
    }
    if (store.hasActiveHandover(txn.id) || store.hasActiveDeliveryTask(txn.id)) {
      return const MockMutationFail(
          DomainErrorCode.cancellationObligationPending,
          'Còn lượt bàn giao hoặc nhiệm vụ giao hộ chưa kết thúc.');
    }
    final material = store.material(txn.materialId);
    if (material == null || material.holderId != txn.ownerAtAcceptance) {
      return const MockMutationFail(
          DomainErrorCode.cancellationObligationPending,
          'Tài liệu chưa được trả về người đăng.');
    }
    if (txn.type == OfferType.sell &&
        (store.payment(txn.id)?.hasOutstandingRefund ?? false)) {
      return const MockMutationFail(
          DomainErrorCode.cancellationObligationPending,
          'Người mua chưa xác nhận đã nhận lại tiền.');
    }
    return null;
  }
}

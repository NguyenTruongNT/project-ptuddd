import '../../../core/backend/workflow_json.dart';
import '../../../core/backend/workflow_rpc.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../../core/contracts/repositories/transaction_repository.dart';

/// Repository gọi RPC Supabase thật cho nghiệp vụ yêu cầu trả.
///
/// Flutter chỉ gửi transactionId và idempotency key.
/// Quyền, trạng thái và việc chuyển BORROWING -> RETURN_PENDING
/// được kiểm tra và thực hiện nguyên tử ở backend.
class SupabaseBorrowRepository implements BorrowRepository {
  const SupabaseBorrowRepository(this._rpc);

  final WorkflowRpc _rpc;

  @override
  Future<CommandResult<StudyTransaction>> requestReturn(
    String transactionId, {
    required String idempotencyKey,
  }) {
    final String normalizedTransactionId = transactionId.trim();
    final String normalizedKey = idempotencyKey.trim();

    return _rpc.command<StudyTransaction>(
      'request_borrow_return',
      <String, dynamic>{
        'p_transaction_id': normalizedTransactionId,
        'p_idempotency_key': normalizedKey,
      },
      _transactionFromDetails,
      validationMessage:
          normalizedTransactionId.isEmpty || normalizedKey.isEmpty
          ? 'Thiếu giao dịch hoặc mã thao tác.'
          : null,
    );
  }
}

/// RPC dùng helper `ss_finish_txn_command`, nên trường `data` trả về
/// TransactionDetails. BorrowRepository chỉ cần StudyTransaction bên trong.
StudyTransaction _transactionFromDetails(Object? raw) {
  final Map<String, dynamic> details = WorkflowJson.object(raw);

  final Map<String, dynamic> transaction = WorkflowJson.object(
    details['transaction'],
  );

  return StudyTransaction(
    id: WorkflowJson.text(transaction['id']),
    listingId: WorkflowJson.text(transaction['listingId']),
    requestId: WorkflowJson.text(transaction['requestId']),
    materialId: WorkflowJson.text(transaction['materialId']),
    type: OfferType.fromWire(WorkflowJson.text(transaction['type'])),
    ownerAtAcceptance: WorkflowJson.text(transaction['ownerAtAcceptance']),
    receiverId: WorkflowJson.text(transaction['receiverId']),
    status: TransactionStatus.fromWire(
      WorkflowJson.text(transaction['status']),
    ),
    agreedBorrowDays: WorkflowJson.optionalInteger(
      transaction['agreedBorrowDays'],
    ),
    agreedPriceVnd: WorkflowJson.optionalInteger(transaction['agreedPriceVnd']),
  );
}

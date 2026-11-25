import '../../../core/backend/workflow_json.dart';
import '../../../core/backend/workflow_rpc.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../../core/contracts/repositories/transaction_repository.dart';

TransactionViewerRole _role(Object? raw) => switch (raw) {
  'OWNER' => TransactionViewerRole.owner,
  'RECEIVER' => TransactionViewerRole.receiver,
  _ => throw const FormatException('Invalid viewer role'),
};

TransactionDetails transactionDetailsFromRpc(Object? raw) {
  final r = WorkflowJson.object(raw);
  final t = WorkflowJson.object(r['transaction']);
  final borrow = r['borrowing'] == null
      ? null
      : WorkflowJson.object(r['borrowing']);
  final payment = r['payment'] == null
      ? null
      : WorkflowJson.object(r['payment']);
  final cancellation = r['cancellationProposal'] == null
      ? null
      : WorkflowJson.object(r['cancellationProposal']);
  return TransactionDetails(
    transaction: StudyTransaction(
      id: WorkflowJson.text(t['id']),
      listingId: WorkflowJson.text(t['listingId']),
      requestId: WorkflowJson.text(t['requestId']),
      materialId: WorkflowJson.text(t['materialId']),
      type: OfferType.fromWire(WorkflowJson.text(t['type'])),
      ownerAtAcceptance: WorkflowJson.text(t['ownerAtAcceptance']),
      receiverId: WorkflowJson.text(t['receiverId']),
      status: TransactionStatus.fromWire(WorkflowJson.text(t['status'])),
      agreedBorrowDays: WorkflowJson.optionalInteger(t['agreedBorrowDays']),
      agreedPriceVnd: WorkflowJson.optionalInteger(t['agreedPriceVnd']),
    ),
    materialTitle: WorkflowJson.text(r['materialTitle']),
    materialSubject: WorkflowJson.text(r['materialSubject']),
    ownerDisplayName: WorkflowJson.text(r['ownerDisplayName']),
    receiverDisplayName: WorkflowJson.text(r['receiverDisplayName']),
    viewerRole: _role(r['viewerRole']),
    createdAt: WorkflowJson.timestamp(r['createdAt']),
    borrowing: borrow == null
        ? null
        : BorrowingRecord(
            transactionId: WorkflowJson.text(borrow['transactionId']),
            startedAt: WorkflowJson.optionalTimestamp(borrow['startedAt']),
            dueDateVn: WorkflowJson.dateVn(borrow['dueDateVn']),
            returnToCourierAt: WorkflowJson.optionalTimestamp(
              borrow['returnToCourierAt'],
            ),
            reHandoverDueDateVn: WorkflowJson.dateVn(
              borrow['reHandoverDueDateVn'],
            ),
          ),
    payment: payment == null
        ? null
        : PaymentConfirmation(
            transactionId: WorkflowJson.text(payment['transactionId']),
            buyerReportedAt: WorkflowJson.optionalTimestamp(
              payment['buyerReportedAt'],
            ),
            sellerConfirmedAt: WorkflowJson.optionalTimestamp(
              payment['sellerConfirmedAt'],
            ),
            refundReportedAt: WorkflowJson.optionalTimestamp(
              payment['refundReportedAt'],
            ),
            buyerRefundConfirmedAt: WorkflowJson.optionalTimestamp(
              payment['buyerRefundConfirmedAt'],
            ),
          ),
    openIssueCount: WorkflowJson.integer(r['openIssueCount']),
    cancellationProposal: cancellation == null
        ? null
        : CancellationProposal(
            proposedBy: _role(cancellation['proposedBy']),
            reason: WorkflowJson.text(cancellation['reason']),
            proposedAt: WorkflowJson.timestamp(cancellation['proposedAt']),
          ),
    allowedActions: Set.unmodifiable(
      WorkflowJson.list(r['allowedActions'])
          .map((a) => TransactionAction.fromWire(WorkflowJson.text(a))),
    ),
  );
}

class SupabaseTransactionQueryRepository implements TransactionQueryRepository {
  const SupabaseTransactionQueryRepository(this.rpc);
  final WorkflowRpc rpc;
  @override
  Future<List<TransactionDetails>> getMyTransactions() => rpc.read(
    'get_my_transactions',
    {},
    (raw) => List.unmodifiable(
      WorkflowJson.list(raw).map(transactionDetailsFromRpc),
    ),
  );
  @override
  Future<TransactionDetails?> getTransactionDetails(String transactionId) =>
      rpc.read('get_transaction_details', {
        'p_transaction_id': transactionId,
      }, (raw) => raw == null ? null : transactionDetailsFromRpc(raw));
  @override
  Future<List<TransactionEventItem>> getTimeline(String transactionId) =>
      rpc.read(
        'get_transaction_timeline',
        {'p_transaction_id': transactionId},
        (raw) => List.unmodifiable(
          WorkflowJson.list(raw).map((value) {
            final r = WorkflowJson.object(value);
            return TransactionEventItem(
              id: WorkflowJson.text(r['id']),
              transactionId: WorkflowJson.text(r['transactionId']),
              eventType: WorkflowJson.text(r['eventType']),
              serverAt: WorkflowJson.timestamp(r['serverAt']),
              safeDescription: WorkflowJson.text(r['safeDescription']),
              actorDisplay: WorkflowJson.optionalText(r['actorDisplay']),
            );
          }),
        ),
      );
}

class SupabaseSellerPaymentRepository implements SellerPaymentRepository {
  const SupabaseSellerPaymentRepository(this.rpc);
  final WorkflowRpc rpc;
  Future<CommandResult<TransactionDetails>> _run(
    String name,
    String id,
    String key,
  ) => rpc.command(
    name,
    {'p_transaction_id': id, 'p_idempotency_key': key},
    transactionDetailsFromRpc,
    validationMessage: id.trim().isEmpty || key.trim().isEmpty
        ? 'Thiếu giao dịch hoặc mã thao tác.'
        : null,
  );
  @override
  Future<CommandResult<TransactionDetails>> reportBuyerTransfer(
    String transactionId, {
    required String idempotencyKey,
  }) => _run('report_buyer_transfer', transactionId, idempotencyKey);
  @override
  Future<CommandResult<TransactionDetails>> confirmSellerPayment(
    String transactionId, {
    required String idempotencyKey,
  }) => _run('confirm_seller_payment', transactionId, idempotencyKey);
  @override
  Future<CommandResult<TransactionDetails>> reportSellerRefund(
    String transactionId, {
    required String idempotencyKey,
  }) => _run('report_seller_refund', transactionId, idempotencyKey);
  @override
  Future<CommandResult<TransactionDetails>> confirmRefundReceived(
    String transactionId, {
    required String idempotencyKey,
  }) => _run('confirm_refund_received', transactionId, idempotencyKey);
}

class SupabaseTransactionCancellationRepository
    implements TransactionCancellationRepository {
  const SupabaseTransactionCancellationRepository(this.rpc);
  final WorkflowRpc rpc;
  Future<CommandResult<TransactionDetails>> _run(
    String name,
    String id,
    String key, {
    String? reason,
  }) => rpc.command(
    name,
    {
      'p_transaction_id': id,
      'p_idempotency_key': key,
      if (reason != null) 'p_reason': reason.trim(),
    },
    transactionDetailsFromRpc,
    validationMessage: id.trim().isEmpty || key.trim().isEmpty
        ? 'Thiếu giao dịch hoặc mã thao tác.'
        : reason != null &&
              (reason.trim().isEmpty || reason.trim().length > 500)
        ? 'Lý do hủy cần từ 1 đến 500 ký tự.'
        : null,
  );
  @override
  Future<CommandResult<TransactionDetails>> proposeCancellation(
    String transactionId,
    String reason, {
    required String idempotencyKey,
  }) => _run(
    'propose_transaction_cancellation',
    transactionId,
    idempotencyKey,
    reason: reason,
  );
  @override
  Future<CommandResult<TransactionDetails>> withdrawCancellation(
    String transactionId, {
    required String idempotencyKey,
  }) =>
      _run('withdraw_transaction_cancellation', transactionId, idempotencyKey);
  @override
  Future<CommandResult<TransactionDetails>> declineCancellation(
    String transactionId, {
    required String idempotencyKey,
  }) => _run('decline_transaction_cancellation', transactionId, idempotencyKey);
  @override
  Future<CommandResult<TransactionDetails>> acceptCancellation(
    String transactionId, {
    required String idempotencyKey,
  }) => _run('accept_transaction_cancellation', transactionId, idempotencyKey);
}

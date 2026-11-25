import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../../core/contracts/repositories/transaction_repository.dart';
import 'supabase_rpc_gateway.dart';

// Repository Transaction/Payment/Hủy gọi RPC Supabase thật.
// Server tự lấy actor từ auth.uid(), kiểm tra quyền + trạng thái + idempotency;
// client không gửi actorId/status và không tự sửa snapshot sau lệnh.

class SupabaseTransactionQueryRepository implements TransactionQueryRepository {
  const SupabaseTransactionQueryRepository(this._rpc);

  final SupabaseRpcGateway _rpc;

  @override
  Future<List<TransactionDetails>> getMyTransactions() => _rpc.query(
    'get_my_transactions',
    const {},
    (raw) => List.unmodifiable(asJsonList(raw).map(parseTransactionDetails)),
  );

  // Server trả null cả khi không tồn tại lẫn không có quyền.
  @override
  Future<TransactionDetails?> getTransactionDetails(String transactionId) =>
      _rpc.query('get_transaction_details', {
        'p_transaction_id': transactionId,
      }, (raw) => raw == null ? null : parseTransactionDetails(asJsonMap(raw)));

  // Giữ nguyên thứ tự server (tăng dần theo serverAt, đã có tie-break).
  @override
  Future<List<TransactionEventItem>> getTimeline(String transactionId) =>
      _rpc.query(
        'get_transaction_timeline',
        {'p_transaction_id': transactionId},
        (raw) => List.unmodifiable(asJsonList(raw).map(parseTransactionEvent)),
      );
}

class SupabaseSellerPaymentRepository implements SellerPaymentRepository {
  const SupabaseSellerPaymentRepository(this._rpc);

  final SupabaseRpcGateway _rpc;

  Future<CommandResult<TransactionDetails>> _run(
    String function,
    String transactionId,
    String idempotencyKey,
  ) => _rpc.command(function, {
    'p_transaction_id': transactionId,
    'p_idempotency_key': idempotencyKey,
  }, parseTransactionDetails);

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
  const SupabaseTransactionCancellationRepository(this._rpc);

  final SupabaseRpcGateway _rpc;

  Future<CommandResult<TransactionDetails>> _run(
    String function,
    String transactionId,
    String idempotencyKey,
  ) => _rpc.command(function, {
    'p_transaction_id': transactionId,
    'p_idempotency_key': idempotencyKey,
  }, parseTransactionDetails);

  @override
  Future<CommandResult<TransactionDetails>> proposeCancellation(
    String transactionId,
    String reason, {
    required String idempotencyKey,
  }) => _rpc.command('propose_transaction_cancellation', {
    'p_transaction_id': transactionId,
    'p_reason': reason,
    'p_idempotency_key': idempotencyKey,
  }, parseTransactionDetails);

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

// ---------- Đọc JSON (camelCase, khớp DTO trong core/contracts) ----------

TransactionViewerRole parseViewerRole(Object? raw) => switch (raw) {
  'OWNER' => TransactionViewerRole.owner,
  'RECEIVER' => TransactionViewerRole.receiver,
  _ => throw FormatException('Vai trò giao dịch không hợp lệ: $raw'),
};

TransactionDetails parseTransactionDetails(Map<String, dynamic> json) {
  final borrowing = json['borrowing'];
  final payment = json['payment'];
  final cancellation = json['cancellationProposal'];
  return TransactionDetails(
    transaction: _parseTransaction(asJsonMap(json['transaction'])),
    materialTitle: json['materialTitle'] as String,
    materialSubject: json['materialSubject'] as String? ?? '',
    ownerDisplayName: json['ownerDisplayName'] as String? ?? '',
    receiverDisplayName: json['receiverDisplayName'] as String? ?? '',
    viewerRole: parseViewerRole(json['viewerRole']),
    createdAt: parseServerTime(json['createdAt']),
    borrowing: borrowing == null ? null : _parseBorrowing(asJsonMap(borrowing)),
    payment: payment == null ? null : _parsePayment(asJsonMap(payment)),
    openIssueCount: parseOptionalInt(json['openIssueCount']) ?? 0,
    cancellationProposal: cancellation == null
        ? null
        : _parseCancellation(asJsonMap(cancellation)),
    allowedActions: parseAllowedActions(
      json['allowedActions'],
      TransactionAction.fromWire,
    ),
  );
}

StudyTransaction _parseTransaction(Map<String, dynamic> json) =>
    StudyTransaction(
      id: json['id'] as String,
      listingId: json['listingId'] as String,
      requestId: json['requestId'] as String,
      materialId: json['materialId'] as String,
      type: OfferType.fromWire(json['type'] as String),
      ownerAtAcceptance: json['ownerAtAcceptance'] as String,
      receiverId: json['receiverId'] as String,
      status: TransactionStatus.fromWire(json['status'] as String),
      agreedBorrowDays: parseOptionalInt(json['agreedBorrowDays']),
      agreedPriceVnd: parseOptionalInt(json['agreedPriceVnd']),
    );

// Ngày hạn giữ nguyên chuỗi yyyy-MM-dd lịch Việt Nam do server tính.
BorrowingRecord _parseBorrowing(Map<String, dynamic> json) => BorrowingRecord(
  transactionId: json['transactionId'] as String,
  startedAt: parseOptionalServerTime(json['startedAt']),
  dueDateVn: json['dueDateVn'] as String?,
  returnToCourierAt: parseOptionalServerTime(json['returnToCourierAt']),
  reHandoverDueDateVn: json['reHandoverDueDateVn'] as String?,
);

PaymentConfirmation _parsePayment(Map<String, dynamic> json) =>
    PaymentConfirmation(
      transactionId: json['transactionId'] as String,
      buyerReportedAt: parseOptionalServerTime(json['buyerReportedAt']),
      sellerConfirmedAt: parseOptionalServerTime(json['sellerConfirmedAt']),
      refundReportedAt: parseOptionalServerTime(json['refundReportedAt']),
      buyerRefundConfirmedAt: parseOptionalServerTime(
        json['buyerRefundConfirmedAt'],
      ),
    );

CancellationProposal _parseCancellation(Map<String, dynamic> json) =>
    CancellationProposal(
      proposedBy: parseViewerRole(json['proposedBy']),
      reason: json['reason'] as String? ?? '',
      proposedAt: parseServerTime(json['proposedAt']),
    );

TransactionEventItem parseTransactionEvent(Map<String, dynamic> json) =>
    TransactionEventItem(
      id: json['id'] as String,
      transactionId: json['transactionId'] as String,
      eventType: json['eventType'] as String,
      serverAt: parseServerTime(json['serverAt']),
      safeDescription: json['safeDescription'] as String? ?? '',
      actorDisplay: json['actorDisplay'] as String?,
    );

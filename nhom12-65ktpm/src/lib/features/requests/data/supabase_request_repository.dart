import '../../../core/backend/workflow_json.dart';
import '../../../core/backend/workflow_rpc.dart';
import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/exchange_request.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../../core/contracts/repositories/request_repository.dart';
import '../../transactions/data/supabase_transaction_repository.dart';
import '../../../core/errors/app_error.dart';

/// Repository Request kết nối trực tiếp với Supabase RPC.
///
/// Flutter chỉ gửi dữ liệu đầu vào nghiệp vụ và idempotency key.
/// Actor, quyền, trạng thái và Transaction được xác định tại backend.
class SupabaseRequestRepository implements RequestRepository {
  const SupabaseRequestRepository(this._rpc);

  final WorkflowRpc _rpc;

  @override
  Future<List<ExchangeRequest>> getMyRequests() {
    return _rpc.read<List<ExchangeRequest>>(
      'get_my_exchange_requests',
      const <String, dynamic>{},
      (Object? raw) {
        return List<ExchangeRequest>.unmodifiable(
          WorkflowJson.list(raw).map(_requestFromRpc),
        );
      },
    );
  }

  @override
  Future<CommandResult<ExchangeRequest>> createRequest(
    CreateRequestInput input, {
    required String idempotencyKey,
  }) {
    final String listingId = input.listingId.trim();
    final String key = idempotencyKey.trim();
    final int? days = input.requestedBorrowDays;

    if (listingId.isEmpty ||
        key.isEmpty ||
        (days != null && (days < 1 || days > 30))) {
      return Future<CommandResult<ExchangeRequest>>.value(
        const CommandError<ExchangeRequest>(
          DomainErrorCode.invalidInput,
          'Thông tin yêu cầu chưa hợp lệ.',
        ),
      );
    }

    return _rpc.receiptCommand<ExchangeRequest>(
      'create_exchange_request',
      <String, dynamic>{
        'p_listing_id': listingId,
        'p_requested_borrow_days': days,
        'p_idempotency_key': key,
      },
      _requestFromRpc,
    );
  }

  @override
  Future<CommandResult<StudyTransaction>> approveRequest(
    String requestId, {
    required String idempotencyKey,
  }) {
    final String normalizedRequestId = requestId.trim();
    final String key = idempotencyKey.trim();

    return _rpc.command<StudyTransaction>(
      'approve_exchange_request',
      <String, dynamic>{
        'p_request_id': normalizedRequestId,
        'p_idempotency_key': key,
      },
      (Object? raw) {
        return transactionDetailsFromRpc(raw).transaction;
      },
      validationMessage: normalizedRequestId.isEmpty || key.isEmpty
          ? 'Thiếu yêu cầu hoặc mã thao tác.'
          : null,
    );
  }

  @override
  Future<CommandResult<ExchangeRequest>> rejectRequest(
    String requestId,
    String reason, {
    required String idempotencyKey,
  }) {
    final String normalizedRequestId = requestId.trim();
    final String normalizedReason = reason.trim();
    final String key = idempotencyKey.trim();

    if (normalizedRequestId.isEmpty ||
        normalizedReason.isEmpty ||
        key.isEmpty) {
      return Future<CommandResult<ExchangeRequest>>.value(
        const CommandError<ExchangeRequest>(
          DomainErrorCode.invalidInput,
          'Thiếu yêu cầu, lý do từ chối hoặc mã thao tác.',
        ),
      );
    }

    return _rpc.receiptCommand<ExchangeRequest>(
      'reject_exchange_request',
      <String, dynamic>{
        'p_request_id': normalizedRequestId,
        'p_reason': normalizedReason,
        'p_idempotency_key': key,
      },
      _requestFromRpc,
    );
  }

  @override
  Future<CommandResult<ExchangeRequest>> cancelPendingRequest(
    String requestId, {
    required String idempotencyKey,
  }) {
    final String normalizedRequestId = requestId.trim();
    final String key = idempotencyKey.trim();

    if (normalizedRequestId.isEmpty || key.isEmpty) {
      return Future<CommandResult<ExchangeRequest>>.value(
        const CommandError<ExchangeRequest>(
          DomainErrorCode.invalidInput,
          'Thiếu yêu cầu hoặc mã thao tác.',
        ),
      );
    }

    return _rpc.receiptCommand<ExchangeRequest>(
      'cancel_pending_request',
      <String, dynamic>{
        'p_request_id': normalizedRequestId,
        'p_idempotency_key': key,
      },
      _requestFromRpc,
    );
  }
}

ExchangeRequest _requestFromRpc(Object? raw) {
  final Map<String, dynamic> value = WorkflowJson.object(raw);

  return ExchangeRequest(
    id: WorkflowJson.text(value['id']),
    listingId: WorkflowJson.text(value['listingId']),
    requesterId: WorkflowJson.text(value['requesterId']),
    status: ExchangeRequestStatus.fromWire(WorkflowJson.text(value['status'])),
    createdAt: WorkflowJson.timestamp(value['createdAt']),
    requestedBorrowDays: WorkflowJson.optionalInteger(
      value['requestedBorrowDays'],
    ),
  );
}

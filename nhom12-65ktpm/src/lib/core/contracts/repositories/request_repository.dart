// Duyệt request phải nguyên tử trên server; interface không tự tạo Transaction.
import '../command_inputs.dart';
import '../command_result.dart';
import '../models/exchange_request.dart';
import '../models/transaction.dart';

abstract interface class RequestRepository {
  Future<List<ExchangeRequest>> getMyRequests();
  Future<CommandResult<ExchangeRequest>> createRequest(
    CreateRequestInput input, {required String idempotencyKey});
  Future<CommandResult<StudyTransaction>> approveRequest(
    String requestId, {required String idempotencyKey});
  Future<CommandResult<ExchangeRequest>> rejectRequest(
    String requestId, String reason, {required String idempotencyKey});
  Future<CommandResult<ExchangeRequest>> cancelPendingRequest(
    String requestId, {required String idempotencyKey});
}

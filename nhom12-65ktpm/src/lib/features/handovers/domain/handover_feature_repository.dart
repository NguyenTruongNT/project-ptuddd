import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/models/handover.dart';
import '../../../core/contracts/repositories/handover_repository.dart';

/// Hợp đồng mở rộng cho phân hệ Handover để dùng chung cho cả Mock và Supabase RPC.
abstract interface class HandoverFeatureRepository implements HandoverRepository {
  Future<CommandResult<Handover>> createHandover({
    required String transactionId,
    required String toUserId,
    String? deliveryTaskId,
    required String idempotencyKey,
  });

  Future<CommandResult<bool>> verifyWithFallback(
    String handoverId,
    String reason, {
    required String idempotencyKey,
  });
}

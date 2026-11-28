import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/models/delivery.dart';
import '../../../core/contracts/repositories/delivery_repository.dart';

/// Dữ liệu chi tiết bổ sung cho màn hình SCR-17 (ẩn với người ngoài / C chưa được duyệt).
class DeliveryTaskBundle {
  const DeliveryTaskBundle({
    required this.task,
    required this.applications,
    this.pickupDescription,
    this.dropoffDescription,
    this.returnHandoverId,
    this.leg1HandoverId,
    this.leg2HandoverId,
  });

  final DeliveryTask task;
  final List<DeliveryApplication> applications;
  final String? pickupDescription;
  final String? dropoffDescription;
  final String? returnHandoverId;
  final String? leg1HandoverId;
  final String? leg2HandoverId;
}

/// Hợp đồng mở rộng cho phân hệ Delivery để cả Mock và Supabase đều đáp ứng
/// đầy đủ luồng nghiệp vụ SS-BR v2.0 mà không sửa đổi shared contracts chung.
abstract interface class DeliveryFeatureRepository
    implements DeliveryQueryRepository, DeliveryRepository {
  Future<List<DeliveryTask>> getAllRelatedTasks();
  Future<DeliveryTask?> getTask(String taskId);
  Future<List<DeliveryApplication>> getApplications(String taskId);
  Future<DeliveryTaskBundle?> getTaskBundle(String taskId);

  Future<CommandResult<DeliveryTask>> createTaskWithDescriptions({
    required String transactionId,
    required String finalReceiverId,
    required String pickupDescription,
    required String dropoffDescription,
    required String idempotencyKey,
  });

  Future<CommandResult<DeliveryTask>> withdrawApplication(
    String taskId, {
    required String idempotencyKey,
  });

  Future<CommandResult<DeliveryTask>> failTask(
    String taskId,
    String reason, {
    required String idempotencyKey,
  });

  Future<CommandResult<int>> rateCourier(String taskId, int stars);
}

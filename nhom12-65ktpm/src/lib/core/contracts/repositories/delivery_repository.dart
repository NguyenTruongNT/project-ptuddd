// Chọn courier do người tạo Task quyết định; không tự động phân công.
import '../command_inputs.dart';
import '../command_result.dart';
import '../models/delivery.dart';

abstract interface class DeliveryQueryRepository {
  Future<List<DeliveryTaskSummary>> getAvailableTasks();
  Future<List<DeliveryTask>> getMyTasks();
}

abstract interface class DeliveryRepository {
  Future<CommandResult<DeliveryTask>> createTask(
    CreateDeliveryTaskInput input, {required String idempotencyKey});
  Future<CommandResult<DeliveryApplication>> applyForTask(
    String taskId, {required String idempotencyKey});
  Future<CommandResult<DeliveryTask>> selectCourier(
    String taskId, String applicationId, {required String idempotencyKey});
}

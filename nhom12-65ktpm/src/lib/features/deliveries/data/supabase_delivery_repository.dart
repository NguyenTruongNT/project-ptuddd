import '../../../core/backend/workflow_json.dart';
import '../../../core/backend/workflow_rpc.dart';
import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/delivery.dart';
import '../domain/delivery_feature_repository.dart';

DeliveryTask _deliveryTaskFromJson(Object? raw) {
  final map = WorkflowJson.object(raw);
  return DeliveryTask(
    id: WorkflowJson.text(map['id']),
    transactionId: WorkflowJson.text(map['transaction_id']),
    senderId: WorkflowJson.text(map['sender_id']),
    finalReceiverId: WorkflowJson.text(map['final_receiver_id']),
    assignedCourierId: WorkflowJson.optionalText(map['assigned_courier_id']),
    status: DeliveryTaskStatus.fromWire(WorkflowJson.text(map['status'])),
  );
}

DeliveryTaskSummary _deliverySummaryFromJson(Object? raw) {
  final map = WorkflowJson.object(raw);
  return DeliveryTaskSummary(
    id: WorkflowJson.text(map['id']),
    publicTitle: WorkflowJson.text(map['public_title']),
    status: DeliveryTaskStatus.fromWire(WorkflowJson.text(map['status'])),
  );
}

DeliveryApplication _deliveryAppFromJson(Object? raw) {
  final map = WorkflowJson.object(raw);
  return DeliveryApplication(
    id: WorkflowJson.text(map['id']),
    taskId: WorkflowJson.text(map['task_id']),
    applicantId: WorkflowJson.text(map['applicant_id']),
    status: DeliveryApplicationStatus.fromWire(WorkflowJson.text(map['status'])),
  );
}

/// Triển khai kết nối Supabase RPC thật cho phân hệ DeliveryTask.
class SupabaseDeliveryRepository implements DeliveryFeatureRepository {
  const SupabaseDeliveryRepository(this.rpc);

  final WorkflowRpc rpc;

  @override
  Future<List<DeliveryTaskSummary>> getAvailableTasks() => rpc.read(
        'get_available_delivery_tasks',
        {},
        (raw) => List.unmodifiable(
          WorkflowJson.list(raw).map(_deliverySummaryFromJson),
        ),
      );

  @override
  Future<List<DeliveryTask>> getMyTasks() => getAllRelatedTasks();

  @override
  Future<List<DeliveryTask>> getAllRelatedTasks() => rpc.read(
        'get_my_delivery_tasks',
        {},
        (raw) => List.unmodifiable(
          WorkflowJson.list(raw).map(_deliveryTaskFromJson),
        ),
      );

  @override
  Future<DeliveryTaskBundle?> getTaskBundle(String taskId) => rpc.read(
        'get_delivery_task_details',
        {'p_task_id': taskId},
        (raw) {
          if (raw == null) return null;
          final map = WorkflowJson.object(raw);
          final taskMap = WorkflowJson.object(map['task']);
          return DeliveryTaskBundle(
            task: _deliveryTaskFromJson(taskMap),
            applications: List.unmodifiable(
              WorkflowJson.list(map['applications']).map(_deliveryAppFromJson),
            ),
            pickupDescription: WorkflowJson.optionalText(taskMap['pickup_description']),
            dropoffDescription: WorkflowJson.optionalText(taskMap['dropoff_description']),
            returnHandoverId: WorkflowJson.optionalText(taskMap['return_handover_id']),
            leg1HandoverId: WorkflowJson.optionalText(map['leg1_handover_id']),
            leg2HandoverId: WorkflowJson.optionalText(map['leg2_handover_id']),
          );
        },
      );

  @override
  Future<DeliveryTask?> getTask(String taskId) async {
    final bundle = await getTaskBundle(taskId);
    return bundle?.task;
  }

  @override
  Future<List<DeliveryApplication>> getApplications(String taskId) async {
    final bundle = await getTaskBundle(taskId);
    return bundle?.applications ?? const [];
  }

  @override
  Future<CommandResult<DeliveryTask>> createTask(
    CreateDeliveryTaskInput input, {
    required String idempotencyKey,
  }) =>
      createTaskWithDescriptions(
        transactionId: input.transactionId,
        finalReceiverId: input.finalReceiverId,
        pickupDescription: 'Điểm hẹn lấy tài liệu',
        dropoffDescription: 'Điểm hẹn giao tài liệu',
        idempotencyKey: idempotencyKey,
      );

  @override
  Future<CommandResult<DeliveryTask>> createTaskWithDescriptions({
    required String transactionId,
    required String finalReceiverId,
    required String pickupDescription,
    required String dropoffDescription,
    required String idempotencyKey,
  }) =>
      rpc.command(
        'create_delivery_task',
        {
          'p_transaction_id': transactionId,
          'p_final_receiver_id': finalReceiverId,
          'p_pickup_description': pickupDescription,
          'p_dropoff_description': dropoffDescription,
          'p_idempotency_key': idempotencyKey,
        },
        _deliveryTaskFromJson,
      );

  @override
  Future<CommandResult<DeliveryApplication>> applyForTask(
    String taskId, {
    required String idempotencyKey,
  }) =>
      rpc.command(
        'apply_for_delivery',
        {
          'p_task_id': taskId,
          'p_idempotency_key': idempotencyKey,
        },
        _deliveryAppFromJson,
      );

  @override
  Future<CommandResult<DeliveryTask>> selectCourier(
    String taskId,
    String applicationId, {
    required String idempotencyKey,
  }) =>
      rpc.command(
        'select_courier',
        {
          'p_task_id': taskId,
          'p_application_id': applicationId,
          'p_idempotency_key': idempotencyKey,
        },
        _deliveryTaskFromJson,
      );

  @override
  Future<CommandResult<DeliveryTask>> withdrawApplication(
    String taskId, {
    required String idempotencyKey,
  }) =>
      rpc.command(
        'withdraw_delivery_application',
        {
          'p_task_id': taskId,
          'p_idempotency_key': idempotencyKey,
        },
        _deliveryTaskFromJson,
      );

  @override
  Future<CommandResult<DeliveryTask>> failTask(
    String taskId,
    String reason, {
    required String idempotencyKey,
  }) =>
      rpc.command(
        'fail_delivery_task',
        {
          'p_task_id': taskId,
          'p_reason': reason,
          'p_idempotency_key': idempotencyKey,
        },
        _deliveryTaskFromJson,
      );

  @override
  Future<CommandResult<int>> rateCourier(String taskId, int stars) =>
      rpc.command(
        'rate_courier',
        {
          'p_task_id': taskId,
          'p_stars': stars,
        },
        (raw) => WorkflowJson.integer(WorkflowJson.object(raw)['stars']),
      );
}

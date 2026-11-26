import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/delivery.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/mock/mock_fixtures.dart';
import '../domain/delivery_feature_repository.dart';

/// Triển khai Mock trong bộ nhớ cho phân hệ DeliveryTask.
class MockDeliveryRepository implements DeliveryFeatureRepository {
  MockDeliveryRepository({required this.actorId});

  final String actorId;

  static final Map<String, DeliveryTask> _tasks = {
    for (final task in MockFixtures.deliveryTasks) task.id: task,
  };

  static final Map<String, (String, String)> _descriptions = {
    'task-donate-01': ('Cổng Đại học Thủy Lợi, 175 Tây Sơn', 'Ký túc xá Thủy Lợi, P.304'),
  };

  static final Map<String, String> _returnHandovers = {};

  static final List<DeliveryApplication> _applications = [
    const DeliveryApplication(
      id: 'app-demo-c-01',
      taskId: 'task-donate-01',
      applicantId: MockFixtures.userC,
      status: DeliveryApplicationStatus.pending,
    ),
  ];

  static int _taskCounter = 10;
  static int _appCounter = 10;

  @override
  Future<List<DeliveryTaskSummary>> getAvailableTasks() async {
    return List.unmodifiable(
      _tasks.values
          .where((task) => task.status == DeliveryTaskStatus.open)
          .map(
            (task) => DeliveryTaskSummary(
              id: task.id,
              publicTitle: 'Giao tài liệu học tập (${task.id})',
              status: task.status,
            ),
          ),
    );
  }

  @override
  Future<List<DeliveryTask>> getMyTasks() => getAllRelatedTasks();

  @override
  Future<List<DeliveryTask>> getAllRelatedTasks() async {
    final appliedTaskIds = _applications
        .where((app) => app.applicantId == actorId)
        .map((app) => app.taskId)
        .toSet();

    return List.unmodifiable(
      _tasks.values.where(
        (task) =>
            task.senderId == actorId ||
            task.finalReceiverId == actorId ||
            task.assignedCourierId == actorId ||
            appliedTaskIds.contains(task.id),
      ),
    );
  }

  @override
  Future<DeliveryTask?> getTask(String taskId) async => _tasks[taskId];

  @override
  Future<List<DeliveryApplication>> getApplications(String taskId) async {
    return List.unmodifiable(
      _applications.where((app) => app.taskId == taskId),
    );
  }

  @override
  Future<DeliveryTaskBundle?> getTaskBundle(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return null;
    final canSee = actorId == task.senderId ||
        actorId == task.finalReceiverId ||
        actorId == task.assignedCourierId;
    final desc = _descriptions[taskId];
    return DeliveryTaskBundle(
      task: task,
      applications: await getApplications(taskId),
      pickupDescription: canSee ? desc?.$1 : null,
      dropoffDescription: canSee ? desc?.$2 : null,
      returnHandoverId: _returnHandovers[taskId],
    );
  }

  @override
  Future<CommandResult<DeliveryTask>> createTask(
    CreateDeliveryTaskInput input, {
    required String idempotencyKey,
  }) =>
      createTaskWithDescriptions(
        transactionId: input.transactionId,
        finalReceiverId: input.finalReceiverId,
        pickupDescription: 'Cổng chính Đại học Thủy Lợi',
        dropoffDescription: 'Ký túc xá Thủy Lợi',
        idempotencyKey: idempotencyKey,
      );

  @override
  Future<CommandResult<DeliveryTask>> createTaskWithDescriptions({
    required String transactionId,
    required String finalReceiverId,
    required String pickupDescription,
    required String dropoffDescription,
    required String idempotencyKey,
  }) async {
    if (transactionId.trim().isEmpty ||
        finalReceiverId.trim().isEmpty ||
        pickupDescription.trim().isEmpty ||
        dropoffDescription.trim().isEmpty) {
      return CommandError(
        DomainErrorCode.invalidInput,
        'Vui lòng nhập đầy đủ thông tin giao dịch và điểm lấy/giao.',
      );
    }

    _taskCounter++;
    final newTask = DeliveryTask(
      id: 'task-delivery-$_taskCounter',
      transactionId: transactionId,
      senderId: actorId,
      finalReceiverId: finalReceiverId,
      status: DeliveryTaskStatus.open,
    );

    _tasks[newTask.id] = newTask;
    _descriptions[newTask.id] = (pickupDescription.trim(), dropoffDescription.trim());
    return CommandOk(newTask, 'evt-delivery-task-created-$_taskCounter');
  }

  @override
  Future<CommandResult<DeliveryApplication>> applyForTask(
    String taskId, {
    required String idempotencyKey,
  }) async {
    final task = _tasks[taskId];
    if (task == null) {
      return CommandError(DomainErrorCode.invalidInput, 'Không tìm thấy nhiệm vụ giao hộ.');
    }
    if (task.status != DeliveryTaskStatus.open) {
      return CommandError(
        DomainErrorCode.invalidTransactionTransition,
        'Nhiệm vụ này đã đóng ứng tuyển hoặc đã có người nhận.',
      );
    }
    if (actorId == task.senderId || actorId == task.finalReceiverId) {
      return CommandError(
        DomainErrorCode.forbidden,
        'Người gửi hoặc người nhận không được tự ứng tuyển giao hộ nhiệm vụ này.',
      );
    }
    final hasApplied = _applications.any(
      (app) => app.taskId == taskId && app.applicantId == actorId,
    );
    if (hasApplied) {
      return CommandError(
        DomainErrorCode.duplicateRequest,
        'Bạn đã gửi đơn ứng tuyển cho nhiệm vụ này rồi.',
      );
    }

    _appCounter++;
    final app = DeliveryApplication(
      id: 'app-courier-$_appCounter',
      taskId: taskId,
      applicantId: actorId,
      status: DeliveryApplicationStatus.pending,
    );
    _applications.add(app);
    return CommandOk(app, 'evt-delivery-application-$_appCounter');
  }

  @override
  Future<CommandResult<DeliveryTask>> selectCourier(
    String taskId,
    String applicationId, {
    required String idempotencyKey,
  }) async {
    final task = _tasks[taskId];
    if (task == null) {
      return CommandError(DomainErrorCode.invalidInput, 'Không tìm thấy nhiệm vụ giao hộ.');
    }
    if (task.senderId != actorId) {
      return CommandError(
        DomainErrorCode.forbidden,
        'Chỉ người gửi mới có quyền chọn người giao hộ.',
      );
    }
    if (task.status != DeliveryTaskStatus.open) {
      return CommandError(
        DomainErrorCode.invalidTransactionTransition,
        'Nhiệm vụ đã được phân công hoặc không còn mở.',
      );
    }

    final targetAppIndex = _applications.indexWhere(
      (app) => app.id == applicationId && app.taskId == taskId,
    );
    if (targetAppIndex == -1) {
      return CommandError(
        DomainErrorCode.invalidInput,
        'Đơn ứng tuyển không tồn tại trong nhiệm vụ này.',
      );
    }

    final selectedApp = _applications[targetAppIndex];
    for (var i = 0; i < _applications.length; i++) {
      if (_applications[i].taskId == taskId) {
        if (_applications[i].id == applicationId) {
          _applications[i] = DeliveryApplication(
            id: _applications[i].id,
            taskId: taskId,
            applicantId: _applications[i].applicantId,
            status: DeliveryApplicationStatus.accepted,
          );
        } else if (_applications[i].status == DeliveryApplicationStatus.pending) {
          _applications[i] = DeliveryApplication(
            id: _applications[i].id,
            taskId: taskId,
            applicantId: _applications[i].applicantId,
            status: DeliveryApplicationStatus.rejected,
          );
        }
      }
    }

    final updatedTask = DeliveryTask(
      id: task.id,
      transactionId: task.transactionId,
      senderId: task.senderId,
      finalReceiverId: task.finalReceiverId,
      assignedCourierId: selectedApp.applicantId,
      status: DeliveryTaskStatus.assigned,
    );
    _tasks[taskId] = updatedTask;
    return CommandOk(updatedTask, 'evt-courier-selected-$taskId');
  }

  @override
  Future<CommandResult<DeliveryTask>> withdrawApplication(
    String taskId, {
    required String idempotencyKey,
  }) async {
    final task = _tasks[taskId];
    if (task == null) {
      return CommandError(DomainErrorCode.invalidInput, 'Không tìm thấy nhiệm vụ.');
    }
    final idx = _applications.indexWhere(
      (a) => a.taskId == taskId && a.applicantId == actorId,
    );
    if (idx == -1) {
      return CommandError(DomainErrorCode.forbidden, 'Bạn không có đơn ứng tuyển ở nhiệm vụ này.');
    }
    final app = _applications[idx];
    if (app.status == DeliveryApplicationStatus.pending &&
        task.status == DeliveryTaskStatus.open) {
      _applications[idx] = DeliveryApplication(
        id: app.id,
        taskId: taskId,
        applicantId: actorId,
        status: DeliveryApplicationStatus.withdrawn,
      );
      return CommandOk(task, 'evt-withdraw-$taskId');
    }
    if (app.status == DeliveryApplicationStatus.accepted &&
        task.status == DeliveryTaskStatus.assigned) {
      final cancelled = DeliveryTask(
        id: task.id,
        transactionId: task.transactionId,
        senderId: task.senderId,
        finalReceiverId: task.finalReceiverId,
        assignedCourierId: task.assignedCourierId,
        status: DeliveryTaskStatus.cancelled,
      );
      _tasks[taskId] = cancelled;
      return CommandOk(cancelled, 'evt-cancel-before-pickup-$taskId');
    }
    return CommandError(
      DomainErrorCode.invalidTransactionTransition,
      'Không thể rút đơn ở trạng thái hiện tại.',
    );
  }

  @override
  Future<CommandResult<DeliveryTask>> failTask(
    String taskId,
    String reason, {
    required String idempotencyKey,
  }) async {
    final task = _tasks[taskId];
    if (task == null || task.assignedCourierId != actorId) {
      return CommandError(
        DomainErrorCode.forbidden,
        'Chỉ người giao hộ đang giữ sách mới được báo giao thất bại.',
      );
    }
    if (reason.trim().isEmpty) {
      return CommandError(DomainErrorCode.invalidInput, 'Vui lòng nhập lý do giao thất bại.');
    }
    if (task.status != DeliveryTaskStatus.pickedUp &&
        task.status != DeliveryTaskStatus.deliveryPendingConfirmation) {
      return CommandError(
        DomainErrorCode.invalidTransactionTransition,
        'Chỉ báo thất bại sau khi đã nhận sách.',
      );
    }
    final failed = DeliveryTask(
      id: task.id,
      transactionId: task.transactionId,
      senderId: task.senderId,
      finalReceiverId: task.finalReceiverId,
      assignedCourierId: task.assignedCourierId,
      status: DeliveryTaskStatus.failed,
    );
    _tasks[taskId] = failed;
    _returnHandovers[taskId] = 'handover-return-$taskId';
    return CommandOk(failed, 'evt-delivery-failed-$taskId');
  }

  @override
  Future<CommandResult<int>> rateCourier(String taskId, int stars) async {
    if (stars < 1 || stars > 5) {
      return CommandError(DomainErrorCode.invalidInput, 'Số sao phải từ 1 đến 5.');
    }
    return CommandOk(stars, 'evt-rate-courier-$taskId');
  }
}

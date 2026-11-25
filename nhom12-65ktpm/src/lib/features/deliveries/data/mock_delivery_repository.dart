import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/delivery.dart';
import '../../../core/contracts/repositories/delivery_repository.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/mock/mock_fixtures.dart';

/// Triển khai Mock trong bộ nhớ cho phân hệ DeliveryTask.
/// Hỗ trợ cả truy vấn và thực thi lệnh chọn Courier, ứng tuyển, tạo nhiệm vụ.
class MockDeliveryRepository implements DeliveryQueryRepository, DeliveryRepository {
  MockDeliveryRepository({required this.actorId});

  final String actorId;

  // Dùng bộ nhớ tĩnh dùng chung để các instance (người gửi, ứng viên, người nhận) thấy cùng dữ liệu
  static final Map<String, DeliveryTask> _tasks = {
    for (final task in MockFixtures.deliveryTasks) task.id: task,
  };

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

  // ---------- TRUY VẤN (QUERY) ----------

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
  Future<List<DeliveryTask>> getMyTasks() async {
    return List.unmodifiable(
      _tasks.values.where(
        (task) =>
            task.senderId == actorId ||
            task.finalReceiverId == actorId ||
            task.assignedCourierId == actorId,
      ),
    );
  }

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

  Future<DeliveryTask?> getTask(String taskId) async {
    return _tasks[taskId];
  }

  Future<List<DeliveryApplication>> getApplications(String taskId) async {
    return List.unmodifiable(
      _applications.where((app) => app.taskId == taskId),
    );
  }

  // ---------- LỆNH NGHIỆP VỤ (COMMANDS) ----------

  @override
  Future<CommandResult<DeliveryTask>> createTask(
    CreateDeliveryTaskInput input, {
    required String idempotencyKey,
  }) async {
    if (input.transactionId.trim().isEmpty || input.finalReceiverId.trim().isEmpty) {
      return CommandError(
        DomainErrorCode.invalidInput,
        'Thông tin giao dịch hoặc người nhận không hợp lệ.',
      );
    }

    _taskCounter++;
    final newTask = DeliveryTask(
      id: 'task-delivery-$_taskCounter',
      transactionId: input.transactionId,
      senderId: actorId,
      finalReceiverId: input.finalReceiverId,
      status: DeliveryTaskStatus.open,
    );

    _tasks[newTask.id] = newTask;
    return CommandOk(newTask, 'evt-delivery-task-created-$_taskCounter');
  }

  @override
  Future<CommandResult<DeliveryApplication>> applyForTask(
    String taskId, {
    required String idempotencyKey,
  }) async {
    final task = _tasks[taskId];
    if (task == null) {
      return CommandError(
        DomainErrorCode.invalidInput,
        'Không tìm thấy nhiệm vụ giao hộ.',
      );
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
      return CommandError(
        DomainErrorCode.invalidInput,
        'Không tìm thấy nhiệm vụ giao hộ.',
      );
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
}

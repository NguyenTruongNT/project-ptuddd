import '../domain_enums.dart';

class DeliveryTask {
  const DeliveryTask({
    required this.id,
    required this.transactionId,
    required this.senderId,
    required this.finalReceiverId,
    required this.status,
    this.assignedCourierId,
  });

  final String id;
  final String transactionId;
  final String senderId;
  final String finalReceiverId;
  final String? assignedCourierId;
  final DeliveryTaskStatus status;
}

// Chỉ dùng khi hiển thị danh sách Task OPEN. Không lộ A/B hoặc điểm hẹn.
class DeliveryTaskSummary {
  const DeliveryTaskSummary({
    required this.id,
    required this.publicTitle,
    required this.status,
  });

  final String id;
  final String publicTitle;
  final DeliveryTaskStatus status;
}

class DeliveryApplication {
  const DeliveryApplication({
    required this.id,
    required this.taskId,
    required this.applicantId,
    required this.status,
  });

  final String id;
  final String taskId;
  final String applicantId;
  final DeliveryApplicationStatus status;
}

import '../domain_enums.dart';

class Handover {
  const Handover({
    required this.id,
    required this.transactionId,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    this.deliveryTaskId,
    this.evidencePhotoCount = 0,
  });

  final String id;
  final String transactionId;
  final String fromUserId;
  final String toUserId;
  final String? deliveryTaskId;
  final HandoverStatus status;
  final int evidencePhotoCount;
  // Không đặt đường dẫn private evidence hoặc QR token vào DTO công khai.
}

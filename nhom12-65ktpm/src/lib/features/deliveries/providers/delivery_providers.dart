import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/models/delivery.dart';
import '../../../core/providers/mock_query_providers.dart';
import '../data/mock_delivery_repository.dart';

/// Provider cung cấp MockDeliveryRepository dùng chung
final deliveryRepositoryProvider = Provider<MockDeliveryRepository>((ref) {
  final actorId = ref.watch(demoViewerIdProvider);
  return MockDeliveryRepository(actorId: actorId);
});

/// Danh sách các nhiệm vụ giao hộ đang mở tìm Courier
final availableDeliveryTasksProvider =
    FutureProvider<List<DeliveryTaskSummary>>((ref) async {
  final repo = ref.watch(deliveryRepositoryProvider);
  return repo.getAvailableTasks();
});

/// Danh sách nhiệm vụ liên quan đến tôi (tôi gửi, tôi nhận, hoặc tôi làm Courier)
final myDeliveryTasksProvider = FutureProvider<List<DeliveryTask>>((ref) async {
  final repo = ref.watch(deliveryRepositoryProvider);
  return repo.getAllRelatedTasks();
});

/// Chi tiết một nhiệm vụ giao hộ cụ thể
final deliveryTaskDetailsProvider =
    FutureProvider.family<DeliveryTask?, String>((ref, taskId) async {
  final repo = ref.watch(deliveryRepositoryProvider);
  return repo.getTask(taskId);
});

/// Danh sách đơn ứng tuyển của một nhiệm vụ
final deliveryApplicationsProvider =
    FutureProvider.family<List<DeliveryApplication>, String>((ref, taskId) async {
  final repo = ref.watch(deliveryRepositoryProvider);
  return repo.getApplications(taskId);
});

/// Hàm làm mới dữ liệu sau khi thực hiện lệnh nghiệp vụ
void refreshDeliveries(WidgetRef ref, {String? taskId}) {
  ref.invalidate(availableDeliveryTasksProvider);
  ref.invalidate(myDeliveryTasksProvider);
  if (taskId != null) {
    ref.invalidate(deliveryTaskDetailsProvider(taskId));
    ref.invalidate(deliveryApplicationsProvider(taskId));
  }
}

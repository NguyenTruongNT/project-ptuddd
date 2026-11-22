// Mock công khai Task OPEN chỉ trả DTO an toàn, không có thông tin A/B.
import '../contracts/domain_enums.dart';
import '../contracts/models/delivery.dart';
import '../contracts/repositories/delivery_repository.dart';
import 'mock_fixtures.dart';

class MockDeliveryQueryRepository implements DeliveryQueryRepository {
  const MockDeliveryQueryRepository({required this.demoViewerId});

  final String demoViewerId;

  @override
  Future<List<DeliveryTaskSummary>> getAvailableTasks() async =>
      List.unmodifiable(MockFixtures.deliveryTasks
          .where((task) => task.status == DeliveryTaskStatus.open)
          .map((task) => DeliveryTaskSummary(
              id: task.id, status: task.status,
              publicTitle: 'Nhiệm vụ giao hộ tài liệu')));

  @override
  Future<List<DeliveryTask>> getMyTasks() async =>
      List.unmodifiable(MockFixtures.deliveryTasks.where((task) =>
          task.senderId == demoViewerId ||
          task.finalReceiverId == demoViewerId ||
          task.assignedCourierId == demoViewerId));
}

import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/mock/mock_repositories.dart';

void main() {
  test('Người ngoài không xem được giao dịch của A và B', () async {
    final repository = MockTransactionQueryRepository(
      demoViewerId: MockFixtures.outsider,
    );
    expect(await repository.getMyTransactions(), isEmpty);
    expect(await repository.getTransactionDetails('txn-sell-01'), isNull);
  });

  test('C không được xem toàn bộ giao dịch chỉ vì là courier', () async {
    final repository = MockTransactionQueryRepository(
      demoViewerId: MockFixtures.userC,
    );
    expect(await repository.getTransactionDetails('txn-delivery-01'), isNull);
  });

  test('Task OPEN chỉ cung cấp summary an toàn khi tìm người giao', () async {
    final repository = MockDeliveryQueryRepository(demoViewerId: MockFixtures.userC);
    final openTasks = await repository.getAvailableTasks();
    expect(openTasks.length, 1);
    expect(openTasks.single.publicTitle, 'Nhiệm vụ giao hộ tài liệu');
    // DeliveryTaskSummary không mang senderId, finalReceiverId hoặc vị trí riêng tư.
  });

  test('Mỗi người chỉ thấy thông báo dành cho mình', () async {
    final b = MockNotificationQueryRepository(demoViewerId: MockFixtures.userB);
    final a = MockNotificationQueryRepository(demoViewerId: MockFixtures.userA);
    expect((await b.getMyNotifications()).length, 1);
    expect(await a.getMyNotifications(), isEmpty);
  });

  test('Chỉ owner lấy được tài liệu qua mock cá nhân', () async {
    final a = MockMaterialQueryRepository(demoViewerId: MockFixtures.userA);
    final c = MockMaterialQueryRepository(demoViewerId: MockFixtures.userC);
    expect((await a.getMyMaterials()).length, 5);
    expect(await c.getMyMaterial('mat-sell-01'), isNull);
  });
}

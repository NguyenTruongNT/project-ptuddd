// Mock minh họa filter theo tài khoản; Supabase phải dùng RLS thật.
import '../contracts/models/notification_item.dart';
import '../contracts/repositories/notification_repository.dart';
import 'mock_fixtures.dart';

class MockNotificationQueryRepository implements NotificationQueryRepository {
  const MockNotificationQueryRepository({required this.demoViewerId});
  final String demoViewerId;

  @override
  Future<List<AppNotification>> getMyNotifications() async =>
      List.unmodifiable(MockFixtures.notifications
          .where((notice) => notice.recipientId == demoViewerId));
}

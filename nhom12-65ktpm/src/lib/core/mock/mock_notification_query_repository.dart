// Mock minh họa filter theo tài khoản; Supabase phải dùng RLS thật.
import '../contracts/models/notification_item.dart';
import '../contracts/repositories/notification_repository.dart';
import 'mock_transaction_store.dart';

// Đọc chung store với Transaction/Issue để thông báo sinh ra từ lệnh mock
// xuất hiện ngay trong hộp thư của bên còn lại.
class MockNotificationQueryRepository implements NotificationQueryRepository {
  const MockNotificationQueryRepository({
    required this.demoViewerId,
    required this.store,
  });
  final String demoViewerId;
  final MockTransactionStore store;

  @override
  Future<List<AppNotification>> getMyNotifications() async =>
      store.notificationsFor(demoViewerId);
}

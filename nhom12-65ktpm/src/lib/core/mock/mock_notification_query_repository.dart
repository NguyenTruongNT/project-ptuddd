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
  Future<List<AppNotification>> getMyNotifications({
    int offset = 0,
    int limit = 100,
  }) async {
    final all = store.notificationsFor(demoViewerId);
    if (offset < 0 || limit <= 0 || offset >= all.length) return const [];
    final end = (offset + limit).clamp(0, all.length);
    return all.sublist(offset, end);
  }

  @override
  Future<int> getUnreadCount() async =>
      store.notificationsFor(demoViewerId).where((n) => !n.isRead).length;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/workflow_rpc.dart';
import '../../../core/contracts/models/notification_item.dart';
import '../../../core/contracts/repositories/notification_repository.dart';
import '../../../core/mock/mock_notification_query_repository.dart';
import '../../../core/providers/mock_query_providers.dart';
import '../data/mock_notification_repository.dart';
import '../data/supabase_notification_repository.dart';

// ---------- Repository (interface) ----------
// Có phiên Supabase thật thì đọc bảng notifications theo RLS; chỉ demo tường
// minh (không có SupabaseClient) mới dùng mock. Mock đọc chung store với
// Transaction/Issue để lệnh mock sinh thông báo cho bên còn lại.
final notificationQueryRepositoryProvider =
    Provider<NotificationQueryRepository>((ref) {
      final rpc = ref.watch(workflowRpcProvider);
      if (rpc != null) return SupabaseNotificationQueryRepository(rpc);
      return MockNotificationQueryRepository(
        demoViewerId: ref.watch(demoViewerIdProvider),
        store: ref.watch(mockTransactionStoreProvider),
      );
    });

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final rpc = ref.watch(workflowRpcProvider);
  if (rpc != null) return SupabaseNotificationRepository(rpc);
  return MockNotificationRepository(
    store: ref.watch(mockTransactionStoreProvider),
    actorId: ref.watch(demoViewerIdProvider),
  );
});

// ---------- Dữ liệu đọc ----------
final myNotificationsProvider = FutureProvider<List<AppNotification>>(
  (ref) => ref.watch(notificationQueryRepositoryProvider).getMyNotifications(),
);

// Số chưa đọc cho chuông; null khi đang tải hoặc lỗi (không hiện badge sai).
final unreadNotificationCountProvider = Provider<int?>((ref) {
  final items = ref.watch(myNotificationsProvider).asData?.value;
  return items?.where((notice) => !notice.isRead).length;
});

/// Sau mỗi lệnh (thành công hay lỗi) tải lại snapshot server, không tự sửa UI.
void refreshNotifications(WidgetRef ref) =>
    ref.invalidate(myNotificationsProvider);

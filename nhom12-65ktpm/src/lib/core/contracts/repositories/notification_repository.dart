// Người dùng chỉ được truy cập notification của chính mình.
import '../command_result.dart';
import '../models/notification_item.dart';

abstract interface class NotificationQueryRepository {
  // Mới nhất trước. Không có quyền/không có dữ liệu đều trả danh sách rỗng.
  Future<List<AppNotification>> getMyNotifications();
}

abstract interface class NotificationRepository {
  // Đánh dấu một thông báo đã đọc. Gọi lại khi đã đọc vẫn thành công và giữ
  // nguyên thời điểm đọc cũ (idempotent).
  Future<CommandResult<AppNotification>> markRead(
    String notificationId, {required String idempotencyKey});

  // Đánh dấu mọi thông báo chưa đọc của chính mình; trả số thông báo vừa đổi.
  Future<CommandResult<int>> markAllRead({required String idempotencyKey});
}

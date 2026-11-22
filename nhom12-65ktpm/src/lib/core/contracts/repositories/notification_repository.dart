// Người dùng chỉ được truy cập notification của chính mình.
import '../command_result.dart';
import '../models/notification_item.dart';

abstract interface class NotificationQueryRepository {
  Future<List<AppNotification>> getMyNotifications();
}

abstract interface class NotificationRepository {
  Future<CommandResult<AppNotification>> markRead(
    String notificationId, {required String idempotencyKey});
}

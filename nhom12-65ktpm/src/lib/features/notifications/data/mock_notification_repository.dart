import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/models/notification_item.dart';
import '../../../core/contracts/repositories/notification_repository.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/mock/mock_transaction_store.dart';

const notificationUnavailableMessage = 'Thông báo không còn khả dụng.';

// Giả lập lệnh đánh dấu đã đọc của server:
// 1) actor lấy từ "session", chỉ người nhận được đổi thông báo của mình;
// 2) không phân biệt "không tồn tại" và "không thuộc về bạn";
// 3) (actor, command, idempotency_key) + hash payload như command_receipts;
// 4) đọc lại khi đã đọc giữ nguyên mốc `read_at` cũ do server ghi.
// Không có TransactionEvent: đọc thông báo không đổi trạng thái nghiệp vụ,
// nên ACK là bản ghi server trả về (serverEventId = null), giống bản Supabase.
class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository({required this.store, required this.actorId});

  final MockTransactionStore store;
  final String actorId;

  static const _missingKey = 'Thiếu mã thao tác, vui lòng thử lại.';

  @override
  Future<CommandResult<AppNotification>> markRead(
    String notificationId, {required String idempotencyKey}) async {
    if (idempotencyKey.trim().isEmpty) {
      return const CommandError(DomainErrorCode.invalidInput, _missingKey);
    }
    final notice = store.notification(notificationId);
    if (notice == null || notice.recipientId != actorId) {
      return const CommandError(
          DomainErrorCode.forbidden, notificationUnavailableMessage);
    }
    const command = 'mark_notification_read';
    final payloadHash = '$command|$notificationId';
    final previous = store.receipt(actorId, command, idempotencyKey);
    if (previous != null && previous.payloadHash != payloadHash) {
      return const CommandError(DomainErrorCode.conflict,
          'Mã thao tác đã được dùng cho nội dung khác.');
    }
    final updated = store.markNotificationRead(notificationId);
    store.saveReceipt(actorId, command, idempotencyKey,
        MockCommandReceipt(payloadHash: payloadHash, eventId: notificationId));
    return CommandOk(updated, null);
  }

  @override
  Future<CommandResult<int>> markAllRead({required String idempotencyKey}) async {
    if (idempotencyKey.trim().isEmpty) {
      return const CommandError(DomainErrorCode.invalidInput, _missingKey);
    }
    const command = 'mark_all_notifications_read';
    const payloadHash = command;
    final previous = store.receipt(actorId, command, idempotencyKey);
    if (previous != null) {
      if (previous.payloadHash != payloadHash) {
        return const CommandError(DomainErrorCode.conflict,
            'Mã thao tác đã được dùng cho nội dung khác.');
      }
      // Retry sau timeout: trả lại số lượng của lần ghi đầu, không đếm lại.
      // Nghĩa của count (thống nhất với bản Supabase): số thông báo chưa đọc
      // lúc bắt đầu ý định nay đã ở trạng thái đã đọc; không có nghĩa hộp thư
      // đã hết thông báo chưa đọc (có thể vừa có thông báo mới).
      return CommandOk(int.parse(previous.entityId!), null);
    }
    final unread = store
        .notificationsFor(actorId)
        .where((notice) => !notice.isRead)
        .toList(growable: false);
    for (final notice in unread) {
      store.markNotificationRead(notice.id);
    }
    store.saveReceipt(actorId, command, idempotencyKey,
        MockCommandReceipt(
            payloadHash: payloadHash,
            eventId: command,
            entityId: '${unread.length}'));
    return CommandOk(unread.length, null);
  }
}

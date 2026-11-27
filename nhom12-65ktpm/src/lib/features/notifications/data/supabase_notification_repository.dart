import 'package:supabase_flutter/supabase_flutter.dart' show CountOption;

import '../../../core/backend/workflow_json.dart';
import '../../../core/backend/workflow_rpc.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/models/notification_item.dart';
import '../../../core/contracts/repositories/notification_repository.dart';
import '../../../core/errors/app_error.dart';
import 'mock_notification_repository.dart' show notificationUnavailableMessage;

// Cloud dev chưa có RPC cho thông báo (đã đối chiếu 27/11/2026), nên đọc/ghi
// thẳng bảng `notifications` trong phạm vi RLS đã mở:
//   - SELECT khi recipient_id = auth.uid();
//   - UPDATE chỉ cột read_at trên dòng của chính mình.
// Khi nhóm trưởng thêm RPC (get_my_notifications, mark_notification_read...),
// chỉ cần thay phần thân các hàm dưới đây, giữ nguyên interface.
const _table = 'notifications';
const _columns =
    'id,recipient_id,type,entity_type,entity_id,preview_safe,created_at,read_at';
// Hộp thư MVP chỉ cần các thông báo gần nhất; không tải toàn bộ lịch sử.
const notificationFetchLimit = 100;

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

AppNotification notificationFromRow(Object? raw) {
  final r = WorkflowJson.object(raw);
  return AppNotification(
    id: WorkflowJson.text(r['id']),
    recipientId: WorkflowJson.text(r['recipient_id']),
    type: WorkflowJson.text(r['type']),
    entityType: NotificationEntityType.parse(WorkflowJson.text(r['entity_type'])),
    entityId: WorkflowJson.text(r['entity_id']),
    safePreview: WorkflowJson.text(r['preview_safe']),
    createdAt: WorkflowJson.timestamp(r['created_at']),
    readAt: WorkflowJson.optionalTimestamp(r['read_at']),
  );
}

List<AppNotification> _rows(Object? raw) =>
    List.unmodifiable(WorkflowJson.list(raw).map(notificationFromRow));

List<String> _idList(Object? raw) => List.unmodifiable(
  WorkflowJson.list(raw).map((e) => WorkflowJson.text(WorkflowJson.object(e)['id'])),
);

class SupabaseNotificationQueryRepository
    implements NotificationQueryRepository {
  const SupabaseNotificationQueryRepository(this.rpc);
  final WorkflowRpc rpc;

  @override
  Future<List<AppNotification>> getMyNotifications({
    int offset = 0,
    int limit = notificationFetchLimit,
  }) => rpc.table(
    'notifications.select',
    // Lọc recipient_id thêm cho rõ ý; RLS vẫn là lớp chặn thật.
    (client, token) {
      final base = client
          .from(_table)
          .select(_columns)
          .eq('recipient_id', rpc.actor)
          .order('created_at', ascending: false)
          .order('id', ascending: false);
      final paged = offset <= 0
          ? base.limit(limit)
          : base.range(offset, offset + limit - 1);
      return paged.setHeader('Authorization', 'Bearer $token');
    },
    _rows,
  );

  @override
  Future<int> getUnreadCount() => rpc.table(
    'notifications.unread_count',
    (client, token) => client
        .from(_table)
        .count(CountOption.exact)
        .eq('recipient_id', rpc.actor)
        .isFilter('read_at', null)
        .setHeader('Authorization', 'Bearer $token'),
    (raw) => raw as int,
  );
}

class _MarkAllIntent {
  _MarkAllIntent(this.targetIds);
  final List<String> targetIds;
  int? acknowledgedCount;
}

// ACK của hai lệnh dưới đây là các dòng server trả về sau UPDATE (read_at do
// server ghi), không có TransactionEvent vì đọc thông báo không đổi nghiệp vụ.
// `markAllRead` cố định tập ID chưa đọc của lần thử đầu theo (actor, key)
// để khi mất ACK và retry sẽ không đánh dấu nhầm thông báo mới vừa đến.
class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this.rpc);
  final WorkflowRpc rpc;

  final Map<String, _MarkAllIntent> _markAllIntents = {};

  static const _missingKey = 'Thiếu mã thao tác, vui lòng thử lại.';
  static const _markAllPageSize = 1000;
  static const _markAllChunkSize = 200;

  @override
  Future<CommandResult<AppNotification>> markRead(
    String notificationId, {required String idempotencyKey}) async {
    if (idempotencyKey.trim().isEmpty) {
      return const CommandError(DomainErrorCode.invalidInput, _missingKey);
    }
    // ID sai định dạng không thể là thông báo của mình; trả lỗi chung thay vì
    // để Postgres báo lỗi kiểu dữ liệu.
    if (!_uuid.hasMatch(notificationId)) return _unavailable();
    try {
      final updated = await rpc.table(
        'notifications.mark_read',
        (client, token) => client
            .from(_table)
            // 'now' được Postgres hiểu là thời điểm của giao dịch server,
            // không dùng đồng hồ máy người dùng.
            .update({'read_at': 'now'})
            .eq('id', notificationId)
            .eq('recipient_id', rpc.actor)
            .isFilter('read_at', null)
            .select(_columns)
            .setHeader('Authorization', 'Bearer $token'),
        _rows,
        command: true,
      );
      if (updated.isNotEmpty) return CommandOk(updated.first, null);
      // Không dòng nào đổi: đã đọc từ trước, hoặc không tồn tại/không có quyền.
      final current = await rpc.table(
        'notifications.get',
        (client, token) => client
            .from(_table)
            .select(_columns)
            .eq('id', notificationId)
            .eq('recipient_id', rpc.actor)
            .limit(1)
            .setHeader('Authorization', 'Bearer $token'),
        _rows,
        command: true,
      );
      if (current.isEmpty) return _unavailable();
      return CommandOk(current.first, null);
    } on AppError catch (error) {
      return CommandError(error.code, error.safeMessage);
    }
  }

  @override
  Future<CommandResult<int>> markAllRead({
    required String idempotencyKey,
  }) async {
    if (idempotencyKey.trim().isEmpty) {
      return const CommandError(DomainErrorCode.invalidInput, _missingKey);
    }
    final intentKey = '${rpc.actor}|$idempotencyKey';
    try {
      var intent = _markAllIntents[intentKey];
      if (intent?.acknowledgedCount != null) {
        return CommandOk(intent!.acknowledgedCount!, null);
      }
      if (intent == null) {
        final ids = <String>[];
        for (var offset = 0; ; offset += _markAllPageSize) {
          final batch = await rpc.table(
            'notifications.unread_ids',
            (client, token) => client
                .from(_table)
                .select('id')
                .eq('recipient_id', rpc.actor)
                .isFilter('read_at', null)
                .order('created_at', ascending: true)
                .order('id', ascending: true)
                .range(offset, offset + _markAllPageSize - 1)
                .setHeader('Authorization', 'Bearer $token'),
            _idList,
            command: true,
          );
          ids.addAll(batch);
          if (batch.length < _markAllPageSize) break;
        }
        intent = _MarkAllIntent(List.unmodifiable(ids));
        _markAllIntents[intentKey] = intent;
      }
      if (intent.targetIds.isEmpty) {
        intent.acknowledgedCount = 0;
        return const CommandOk(0, null);
      }
      var updatedCount = 0;
      for (var i = 0; i < intent.targetIds.length; i += _markAllChunkSize) {
        final end = (i + _markAllChunkSize).clamp(0, intent.targetIds.length);
        final chunk = intent.targetIds.sublist(i, end);
        updatedCount += await rpc.table(
          'notifications.mark_all_read',
          (client, token) => client
              .from(_table)
              .update({'read_at': 'now'})
              .inFilter('id', chunk)
              .eq('recipient_id', rpc.actor)
              .isFilter('read_at', null)
              .select('id')
              .setHeader('Authorization', 'Bearer $token'),
          (raw) => WorkflowJson.list(raw).length,
          command: true,
        );
      }
      intent.acknowledgedCount = updatedCount;
      return CommandOk(updatedCount, null);
    } on AppError catch (error) {
      return CommandError(error.code, error.safeMessage);
    }
  }

  CommandError<T> _unavailable<T>() => CommandError<T>(
    DomainErrorCode.forbidden,
    notificationUnavailableMessage,
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/models/notification_item.dart';
import '../../../core/errors/app_error.dart';
import '../../../design_system/widgets/study_empty.dart';
import '../../../design_system/widgets/study_error.dart';
import '../../../design_system/widgets/study_loading.dart';
import '../../transactions/domain/idempotency_key.dart';
import '../domain/notification_labels.dart';
import '../providers/notification_providers.dart';
import 'widgets/notification_card.dart';

const _noTargetMessage = 'Thông báo này không có nội dung để mở.';

// SCR-24 – Thông báo (UI-17). Chủ trì: Sơn.
// Thông báo dẫn xuất từ Event của server: chạm vào chỉ đánh dấu đã đọc rồi mở
// màn đích; màn đích tự tải lại dữ liệu và kiểm tra quyền mới nhất.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  // Mỗi ý định "đánh dấu đã đọc" một key; retry sau timeout dùng lại key cũ.
  final Map<String, String> _pendingKeys = {};
  String? _busyId;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    // Mở hộp thư luôn lấy snapshot mới, không dùng bản cache lúc chuông tải.
    Future.microtask(() {
      if (mounted) refreshNotifications(ref);
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // Giữ key khi chưa rõ kết quả để lần thử sau server nhận ra cùng thao tác.
  void _settleKey(String operation, CommandResult<Object?> result) {
    switch (result) {
      case CommandOk():
        _pendingKeys.remove(operation);
      case CommandError(:final code):
        final retryable = code == DomainErrorCode.timeoutUnknown ||
            code == DomainErrorCode.networkUnavailable;
        if (!retryable) _pendingKeys.remove(operation);
    }
  }

  Future<void> _open(AppNotification notice) async {
    if (_busyId != null || _markingAll) return;
    String? readError;
    if (!notice.isRead) {
      final operation = 'read|${notice.id}';
      final key = _pendingKeys.putIfAbsent(operation, newIdempotencyKey);
      setState(() => _busyId = notice.id);
      CommandResult<AppNotification> result;
      try {
        result = await ref
            .read(notificationRepositoryProvider)
            .markRead(notice.id, idempotencyKey: key);
      } catch (_) {
        result = const CommandError(DomainErrorCode.timeoutUnknown,
            'Chưa rõ máy chủ đã ghi nhận hay chưa.');
      }
      if (!mounted) return;
      setState(() => _busyId = null);
      _settleKey(operation, result);
      if (result case CommandError(:final safeMessage)) readError = safeMessage;
      refreshNotifications(ref);
    }

    // Không đánh dấu được đã đọc vẫn cho mở nội dung: đọc thông báo không
    // phải điều kiện nghiệp vụ, chỉ báo cho người dùng biết.
    final target = notificationTargetRoute(notice);
    if (target == null) {
      _toast(readError ?? _noTargetMessage);
      return;
    }
    if (readError != null) _toast(readError);
    await context.push(target);
    // Quay lại hộp thư: tải lại vì có thể đã phát sinh thông báo mới.
    if (mounted) refreshNotifications(ref);
  }

  Future<void> _markAll() async {
    if (_busyId != null || _markingAll) return;
    const operation = 'read-all';
    final key = _pendingKeys.putIfAbsent(operation, newIdempotencyKey);
    setState(() => _markingAll = true);
    CommandResult<int> result;
    try {
      result = await ref
          .read(notificationRepositoryProvider)
          .markAllRead(idempotencyKey: key);
    } catch (_) {
      result = const CommandError(DomainErrorCode.timeoutUnknown,
          'Chưa rõ máy chủ đã ghi nhận hay chưa.');
    }
    if (!mounted) return;
    setState(() => _markingAll = false);
    _settleKey(operation, result);
    _toast(switch (result) {
      CommandOk(:final data) when data > 0 =>
        'Đã đánh dấu $data thông báo là đã đọc.',
      CommandOk() => 'Không còn thông báo chưa đọc.',
      CommandError(:final safeMessage) => safeMessage,
    });
    refreshNotifications(ref);
  }

  @override
  Widget build(BuildContext context) {
    final notices = ref.watch(myNotificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            tooltip: 'Đánh dấu tất cả đã đọc',
            onPressed: unread > 0 && !_markingAll && _busyId == null
                ? _markAll
                : null,
            icon: _markingAll
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all),
          ),
        ],
      ),
      body: notices.when(
        // Giữ danh sách cũ khi đang tải lại để không nháy màn hình.
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const StudyLoading(),
        error: (error, stackTrace) => Center(
          child: StudyError(
            message: error is AppError
                ? error.safeMessage
                : 'Không tải được thông báo. Kiểm tra kết nối và thử lại.',
            onRetry: () => refreshNotifications(ref),
          ),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(myNotificationsProvider.future),
          child: _NotificationList(
            items: items,
            busyId: _busyId,
            onOpen: _open,
          ),
        ),
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({
    required this.items,
    required this.busyId,
    required this.onOpen,
  });

  final List<AppNotification> items;
  final String? busyId;
  final ValueChanged<AppNotification> onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          StudyEmpty(
            message: 'Chưa có thông báo nào.\n'
                'Cập nhật về giao dịch, thanh toán và sự cố sẽ hiện ở đây.',
          ),
        ],
      );
    }
    final unread = items.where((n) => !n.isRead).toList(growable: false);
    final read = items.where((n) => n.isRead).toList(growable: false);

    Widget card(AppNotification notice) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NotificationCard(
        key: ValueKey('notification-${notice.id}'),
        notice: notice,
        busy: busyId == notice.id,
        onTap: () => onOpen(notice),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (unread.isNotEmpty) ...[
          _SectionHeader('Chưa đọc (${unread.length})'),
          for (final notice in unread) card(notice),
        ],
        if (read.isNotEmpty) ...[
          if (unread.isNotEmpty) const SizedBox(height: 8),
          const _SectionHeader('Đã đọc'),
          for (final notice in read) card(notice),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

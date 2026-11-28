import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/models/notification_item.dart';
import '../../../core/errors/app_error.dart';
import '../../../design_system/widgets/feature_scaffold.dart';
import '../../../design_system/widgets/study_empty.dart';
import '../../../design_system/widgets/study_error.dart';
import '../../../design_system/widgets/study_loading.dart';
import '../../transactions/domain/idempotency_key.dart';
import '../data/supabase_notification_repository.dart'
    show notificationFetchLimit;
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
  final List<AppNotification> _extraItems = [];
  String? _busyId;
  bool _markingAll = false;
  bool _loadingMore = false;
  bool? _hasMore;
  // Chủ hộp thư mà state cục bộ ở trên thuộc về.
  String? _owner;
  // Tăng mỗi khi bỏ snapshot cũ (tải lại hoặc đổi phiên); kết quả async của
  // thế hệ cũ trả về muộn sẽ bị bỏ qua.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    // Mở hộp thư luôn lấy snapshot mới, không dùng bản cache lúc chuông tải.
    Future.microtask(() {
      if (mounted) _reload();
    });
  }

  void _reload() {
    setState(_discardPages);
    refreshNotifications(ref);
  }

  void _discardPages() {
    _generation++;
    _extraItems.clear();
    _hasMore = null;
    _loadingMore = false;
  }

  // Đổi phiên khi màn còn mở: bỏ hết state của chủ cũ, kể cả key đang chờ
  // (key gắn với actor; dùng lại cho actor khác là sai ý định).
  void _bindOwner(String owner) {
    if (_owner == owner) return;
    _owner = owner;
    _discardPages();
    _pendingKeys.clear();
    _busyId = null;
    _markingAll = false;
  }

  // Kết quả async chỉ còn hiệu lực khi vẫn cùng thế hệ snapshot/phiên.
  bool _stale(int generation) => !mounted || generation != _generation;
  bool _otherOwner(String? owner) => !mounted || owner != _owner;

  Future<void> _loadMore(List<AppNotification> current) async {
    if (_loadingMore) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final next = await ref
          .read(notificationQueryRepositoryProvider)
          .getMyNotifications(
            offset: current.length,
            limit: notificationFetchLimit,
          );
      // Trang của snapshot/phiên cũ trả về muộn: bỏ, không ghép vào hộp thư mới.
      if (_stale(generation)) return;
      final existingIds = current.map((n) => n.id).toSet();
      setState(() {
        _extraItems.addAll(next.where((n) => !existingIds.contains(n.id)));
        _hasMore = next.length >= notificationFetchLimit;
        _loadingMore = false;
      });
    } catch (error) {
      if (_stale(generation)) return;
      setState(() => _loadingMore = false);
      _toast(
        error is AppError
            ? error.safeMessage
            : 'Không tải được thêm thông báo. Kiểm tra kết nối và thử lại.',
      );
    }
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
    final owner = _owner;
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
      // Đổi phiên trong lúc chờ: kết quả thuộc người trước, không hiện/điều hướng.
      if (_otherOwner(owner)) return;
      setState(() => _busyId = null);
      _settleKey(operation, result);
      if (result case CommandError(:final safeMessage)) readError = safeMessage;
      _reload();
    }

    // Không đánh dấu được đã đọc vẫn cho mở nội dung: đọc thông báo không
    // phải điều kiện nghiệp vụ, chỉ báo cho người dùng biết.
    final target = notificationTargetRoute(notice);
    if (target == null) {
      _toast(readError ?? _noTargetMessage);
      return;
    }
    if (readError != null) _toast(readError);
    if (!mounted) return;
    await context.push(target);
    // Quay lại hộp thư: tải lại vì có thể đã phát sinh thông báo mới.
    if (!_otherOwner(owner)) _reload();
  }

  Future<void> _markAll() async {
    if (_busyId != null || _markingAll) return;
    final owner = _owner;
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
    if (_otherOwner(owner)) return;
    setState(() => _markingAll = false);
    _settleKey(operation, result);
    _reload();
    if (result case CommandError(:final safeMessage)) {
      _toast(safeMessage);
      return;
    }
    final changed = (result as CommandOk<int>).data;
    // Số trả về chỉ nói về tập chưa đọc lúc bắt đầu thao tác; còn hay hết
    // thông báo chưa đọc phải hỏi lại server (có thể vừa có thông báo mới).
    int? remaining;
    try {
      remaining = await ref.read(unreadCountFromServerProvider.future);
    } catch (_) {
      remaining = null;
    }
    if (_otherOwner(owner)) return;
    final done = changed > 0
        ? 'Đã đánh dấu $changed thông báo là đã đọc.'
        : 'Không có thông báo nào cần đánh dấu thêm.';
    _toast(remaining != null && remaining > 0
        ? '$done Vẫn còn $remaining thông báo chưa đọc mới đến.'
        : done);
  }

  @override
  Widget build(BuildContext context) {
    // Gắn state cục bộ với chủ hộp thư trước khi ghép dữ liệu.
    _bindOwner(ref.watch(notificationInboxOwnerProvider));
    final notices = ref.watch(myNotificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider) ?? 0;

    return FeatureScaffold(
      title: 'Thông báo',
      fallbackLocation: AppRoutes.home,
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
      body: notices.when(
        // Tải lại cùng chủ (kéo để tải lại, sau lệnh): giữ danh sách cũ cho
        // khỏi nháy. Đổi phiên là "reload" vì phụ thuộc đổi: KHÔNG giữ dữ liệu
        // của người trước trong lúc hộp thư mới đang tải.
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: false,
        loading: () => const StudyLoading(),
        error: (error, stackTrace) => Center(
          child: StudyError(
            message: error is AppError
                ? error.safeMessage
                : 'Không tải được thông báo. Kiểm tra kết nối và thử lại.',
            onRetry: _reload,
          ),
        ),
        data: (items) {
          final firstIds = items.map((n) => n.id).toSet();
          final allItems = [
            ...items,
            ..._extraItems.where((n) => !firstIds.contains(n.id)),
          ];
          final hasMore = _hasMore ?? (items.length >= notificationFetchLimit);
          return RefreshIndicator(
            onRefresh: () async {
              if (mounted) setState(_discardPages);
              ref.invalidate(unreadCountFromServerProvider);
              ref.invalidate(myNotificationsProvider);
              await Future.wait([
                ref.read(unreadCountFromServerProvider.future),
                ref.read(myNotificationsProvider.future),
              ]);
            },
            child: _NotificationList(
              items: allItems,
              totalUnread: unread,
              hasMore: hasMore,
              loadingMore: _loadingMore,
              busyId: _busyId,
              onOpen: _open,
              onLoadMore: () => _loadMore(allItems),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({
    required this.items,
    required this.totalUnread,
    required this.hasMore,
    required this.loadingMore,
    required this.busyId,
    required this.onOpen,
    required this.onLoadMore,
  });

  final List<AppNotification> items;
  final int totalUnread;
  final bool hasMore;
  final bool loadingMore;
  final String? busyId;
  final ValueChanged<AppNotification> onOpen;
  final VoidCallback onLoadMore;

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
    final olderUnread = totalUnread - unread.length;

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
        if (olderUnread > 0 && hasMore) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Còn $olderUnread thông báo chưa đọc cũ hơn ngoài trang hiện tại.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
        if (unread.isNotEmpty) ...[
          _SectionHeader('Chưa đọc (${unread.length})'),
          for (final notice in unread) card(notice),
        ],
        if (read.isNotEmpty) ...[
          if (unread.isNotEmpty) const SizedBox(height: 8),
          const _SectionHeader('Đã đọc'),
          for (final notice in read) card(notice),
        ],
        if (hasMore) ...[
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton(
              onPressed: loadingMore ? null : onLoadMore,
              child: loadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Tải thêm thông báo'),
            ),
          ),
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

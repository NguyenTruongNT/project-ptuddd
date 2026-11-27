import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/exchange_request.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../../core/errors/app_error.dart';
import '../../../design_system/widgets/feature_scaffold.dart';
import '../../listings/providers/listing_providers.dart';
import '../../transactions/domain/idempotency_key.dart';
import '../domain/request_labels.dart';
import '../domain/request_view.dart';
import '../providers/request_providers.dart';

/// SCR-12: Trung tâm yêu cầu — yêu cầu nhận được (chủ tài liệu) và đã gửi.
///
/// Nút thao tác chỉ hiện theo `allowedActions` do server trả về.
/// Kết quả chỉ báo thành công sau ACK; sau mỗi lệnh luôn tải lại từ server.
class RequestCenterPage extends ConsumerStatefulWidget {
  const RequestCenterPage({super.key});

  @override
  ConsumerState<RequestCenterPage> createState() => _RequestCenterPageState();
}

class _RequestCenterPageState extends ConsumerState<RequestCenterPage> {
  // Key theo từng ý định (lệnh + request + nội dung); giữ khi timeout để retry an toàn.
  final Map<String, String> _pendingKeys = {};
  final Set<String> _busyIds = {};

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<CommandResult<T>?> _run<T>({
    required String requestId,
    required String intent,
    required Future<CommandResult<T>> Function(
      RequestCenterRepository repository,
      String key,
    )
    call,
  }) async {
    if (_busyIds.contains(requestId)) return null;
    final repository = _readRepository();
    if (repository == null) return null;
    final key = _pendingKeys.putIfAbsent(intent, newIdempotencyKey);
    setState(() => _busyIds.add(requestId));
    CommandResult<T> result;
    try {
      result = await call(repository, key);
    } catch (_) {
      result = const CommandError(
        DomainErrorCode.timeoutUnknown,
        'Chưa rõ máy chủ đã ghi nhận hay chưa. Hãy thử lại cùng thao tác.',
      );
    }
    if (!mounted) return null;
    setState(() => _busyIds.remove(requestId));

    if (result case CommandError(:final code, :final safeMessage)) {
      final retryable =
          code == DomainErrorCode.timeoutUnknown ||
          code == DomainErrorCode.networkUnavailable;
      if (!retryable) _pendingKeys.remove(intent);
      _showMessage(requestErrorMessage(code, safeMessage));
    } else {
      _pendingKeys.remove(intent);
    }
    refreshRequests(ref);
    return result;
  }

  RequestCenterRepository? _readRepository() {
    try {
      return ref.read(requestRepositoryProvider);
    } catch (error) {
      // Riverpod có thể bọc lỗi provider; luôn hiển thị thông báo an toàn.
      _showMessage(
        error is AppError
            ? error.safeMessage
            : 'Chức năng yêu cầu cần đăng nhập và kết nối Supabase.',
      );
      return null;
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _approve(RequestView view) async {
    final days = view.requestedBorrowDays;
    final ok = await _confirm(
      title: 'Duyệt yêu cầu?',
      message:
          'Duyệt yêu cầu ${requestOfferLabel(view.offerType).toLowerCase()} '
          'của ${view.requesterDisplayName}'
          '${days == null ? '' : ' trong $days ngày'}. '
          'Các yêu cầu khác đang chờ cho tài liệu này sẽ tự động bị từ chối.',
      confirmLabel: 'Duyệt',
    );
    if (!ok || !mounted) return;
    final result = await _run<StudyTransaction>(
      requestId: view.id,
      intent: 'approve:${view.id}',
      call: (repo, key) => repo.approveRequest(view.id, idempotencyKey: key),
    );
    if (!mounted || result is! CommandOk<StudyTransaction>) return;
    ref.invalidate(listingDetailsProvider(view.listingId));
    _showMessage('Đã duyệt. Giao dịch đã được tạo.');
    context.push(AppRoutes.transactionDetails(result.data.id));
  }

  Future<void> _reject(RequestView view) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectReasonDialog(),
    );
    if (reason == null || !mounted) return;
    final result = await _run<ExchangeRequest>(
      requestId: view.id,
      intent: 'reject:${view.id}:$reason',
      call: (repo, key) =>
          repo.rejectRequest(view.id, reason, idempotencyKey: key),
    );
    if (!mounted || result is! CommandOk) return;
    ref.invalidate(listingDetailsProvider(view.listingId));
    _showMessage('Đã từ chối yêu cầu.');
  }

  Future<void> _cancel(RequestView view) async {
    final ok = await _confirm(
      title: 'Rút yêu cầu?',
      message: 'Chủ tài liệu sẽ không thể duyệt yêu cầu này nữa.',
      confirmLabel: 'Rút yêu cầu',
    );
    if (!ok || !mounted) return;
    final result = await _run<ExchangeRequest>(
      requestId: view.id,
      intent: 'cancel:${view.id}',
      call: (repo, key) =>
          repo.cancelPendingRequest(view.id, idempotencyKey: key),
    );
    if (!mounted || result is! CommandOk) return;
    ref.invalidate(listingDetailsProvider(view.listingId));
    _showMessage('Đã rút yêu cầu.');
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(myRequestViewsProvider);
    return FeatureScaffold(
      title: 'Trung tâm yêu cầu',
      fallbackLocation: AppRoutes.explore,
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: () => refreshRequests(ref),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: error is AppError
              ? error.safeMessage
              : 'Không tải được danh sách yêu cầu. Hãy kiểm tra đăng nhập, '
                    'kết nối và thử lại.',
          onRetry: () => refreshRequests(ref),
        ),
        data: (views) {
          final incoming = views.where((v) => v.isIncoming).toList();
          final sent = views.where((v) => !v.isIncoming).toList();
          final pendingIncoming = incoming
              .where((v) => v.status == ExchangeRequestStatus.pending)
              .length;
          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  tabs: [
                    Tab(
                      key: const ValueKey('request-tab-incoming'),
                      text: pendingIncoming == 0
                          ? 'Nhận được'
                          : 'Nhận được ($pendingIncoming)',
                    ),
                    const Tab(
                      key: ValueKey('request-tab-sent'),
                      text: 'Đã gửi',
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildList(
                        incoming,
                        emptyMessage:
                            'Chưa có ai gửi yêu cầu cho tài liệu của bạn.',
                      ),
                      _buildList(
                        sent,
                        emptyMessage: 'Bạn chưa gửi yêu cầu nào. Hãy vào Khám phá để tìm tài liệu.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(List<RequestView> views, {required String emptyMessage}) {
    return RefreshIndicator(
      onRefresh: () async {
        refreshRequests(ref);
        await ref.read(myRequestViewsProvider.future);
      },
      child: views.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(32),
              children: [Text(emptyMessage, textAlign: TextAlign.center)],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: views.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final view = views[index];
                return _RequestCard(
                  view: view,
                  busy: _busyIds.contains(view.id),
                  onApprove: () => _approve(view),
                  onReject: () => _reject(view),
                  onCancel: () => _cancel(view),
                );
              },
            ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.view,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
  });

  final RequestView view;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (Color chipBg, Color chipFg) = switch (view.status) {
      ExchangeRequestStatus.pending => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      ExchangeRequestStatus.accepted => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      ExchangeRequestStatus.rejected => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      ExchangeRequestStatus.cancelled => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    final days = view.requestedBorrowDays;

    return Card(
      key: ValueKey('request-card-${view.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    view.materialTitle,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    requestStatusLabel(view.status),
                    style: textTheme.labelMedium?.copyWith(color: chipFg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${requestOfferLabel(view.offerType)}'
              '${days == null ? '' : ' · $days ngày'}'
              ' · ${view.materialSubject}',
            ),
            const SizedBox(height: 4),
            Text(
              view.isIncoming
                  ? 'Người gửi: ${view.requesterDisplayName}'
                  : 'Chủ tài liệu: ${view.ownerDisplayName}',
            ),
            Text(
              'Gửi lúc ${formatVnDateTime(view.createdAt)}',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (view.status == ExchangeRequestStatus.rejected &&
                view.rejectReason != null) ...[
              const SizedBox(height: 6),
              Text(
                'Lý do: ${view.rejectReason}',
                style: TextStyle(color: scheme.error),
              ),
            ],
            if (view.status == ExchangeRequestStatus.accepted) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => context.go(AppRoutes.transactions),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Xem trong Giao dịch'),
              ),
            ],
            if (view.allowedActions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (view.can(RequestAction.approve))
                    FilledButton(
                      key: ValueKey('request-approve-${view.id}'),
                      onPressed: busy ? null : onApprove,
                      child: const Text('Duyệt'),
                    ),
                  if (view.can(RequestAction.reject))
                    OutlinedButton(
                      key: ValueKey('request-reject-${view.id}'),
                      onPressed: busy ? null : onReject,
                      child: const Text('Từ chối'),
                    ),
                  if (view.can(RequestAction.cancel))
                    OutlinedButton(
                      key: ValueKey('request-cancel-${view.id}'),
                      onPressed: busy ? null : onCancel,
                      child: const Text('Rút yêu cầu'),
                    ),
                  if (busy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog();

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do từ chối.');
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Từ chối yêu cầu'),
      content: TextField(
        key: const ValueKey('request-reject-reason'),
        controller: _controller,
        maxLength: 500,
        maxLines: 3,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Lý do (người gửi sẽ thấy)',
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Để sau'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Từ chối')),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

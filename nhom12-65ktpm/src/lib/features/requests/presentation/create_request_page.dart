import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/listing_workspace.dart';
import '../../../core/contracts/models/exchange_request.dart';
import '../../../core/errors/app_error.dart';
import '../../../design_system/widgets/feature_scaffold.dart';
import '../../listings/providers/listing_providers.dart';
import '../../transactions/domain/idempotency_key.dart';
import '../../transactions/domain/transaction_labels.dart';
import '../domain/request_labels.dart';
import '../providers/request_providers.dart';

/// SCR-11: Gửi yêu cầu mượn / mua / nhận tặng cho một Listing công khai.
///
/// Chỉ gửi listingId, số ngày (BORROW) và idempotency key.
/// Quyền, khả dụng và số ngày được RPC `create_exchange_request` kiểm tra lại.
class CreateRequestPage extends ConsumerStatefulWidget {
  const CreateRequestPage({super.key, required this.listingId});
  final String listingId;

  @override
  ConsumerState<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends ConsumerState<CreateRequestPage> {
  final _daysController = TextEditingController();
  String? _daysError;
  bool _busy = false;

  // Key giữ lại khi timeout/mất mạng để retry đúng thao tác cũ.
  // Đổi số ngày là thao tác mới nên phải dùng key mới (tránh CONFLICT).
  String? _pendingKey;
  int? _pendingDays;

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit(ListingDetails details) async {
    if (_busy) return;
    final policy = details.borrowPolicy;
    int? days;
    if (policy != null) {
      days = int.tryParse(_daysController.text.trim());
      if (!policy.acceptsDays(days)) {
        setState(() {
          _daysError =
              'Số ngày mượn phải từ ${policy.minDays} đến ${policy.maxDays}.';
        });
        return;
      }
    }
    setState(() => _daysError = null);

    final repository = _tryRead(() => ref.read(requestRepositoryProvider));
    if (repository == null) return;

    if (_pendingKey == null || _pendingDays != days) {
      _pendingKey = newIdempotencyKey();
      _pendingDays = days;
    }
    final key = _pendingKey!;

    setState(() => _busy = true);
    CommandResult<ExchangeRequest> result;
    try {
      result = await repository.createRequest(
        CreateRequestInput(
          listingId: widget.listingId,
          requestedBorrowDays: days,
        ),
        idempotencyKey: key,
      );
    } catch (_) {
      // Không biết server đã ghi hay chưa: giữ key và không báo thành công.
      result = const CommandError(
        DomainErrorCode.timeoutUnknown,
        'Chưa rõ máy chủ đã ghi nhận hay chưa. Hãy bấm gửi lại để đối soát.',
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case CommandOk():
        _pendingKey = null;
        refreshRequests(ref);
        ref.invalidate(listingDetailsProvider(widget.listingId));
        _showMessage('Đã gửi yêu cầu. Chờ chủ tài liệu duyệt.');
        context.pushReplacement(AppRoutes.requestCenter);
      case CommandError(:final code, :final safeMessage):
        final retryable =
            code == DomainErrorCode.timeoutUnknown ||
            code == DomainErrorCode.networkUnavailable;
        if (!retryable) {
          _pendingKey = null;
          // Trạng thái tin có thể đã đổi (giữ chỗ, đã có yêu cầu...).
          ref.invalidate(listingDetailsProvider(widget.listingId));
        }
        _showMessage(requestErrorMessage(code, safeMessage));
    }
  }

  T? _tryRead<T>(T Function() read) {
    try {
      return read();
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

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(listingDetailsProvider(widget.listingId));
    return FeatureScaffold(
      title: 'Gửi yêu cầu',
      fallbackLocation: AppRoutes.listingDetails(widget.listingId),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _CenteredMessage(
          message: 'Không tải được tin đăng. Vui lòng thử lại.',
          actionLabel: 'Thử lại',
          onAction: () =>
              ref.invalidate(listingDetailsProvider(widget.listingId)),
        ),
        data: (details) {
          if (details == null) {
            return const _CenteredMessage(
              message: 'Tin đăng không còn được chia sẻ công khai.',
            );
          }
          return _buildForm(context, details);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, ListingDetails details) {
    final card = details.card;
    final policy = details.borrowPolicy;
    final blockedMessage = switch (details.requestBlockedReason) {
      'OWNER' => 'Đây là tài liệu của bạn, không thể gửi yêu cầu.',
      'RESERVED' => 'Tài liệu đang được giữ chỗ cho một giao dịch khác.',
      'REQUEST_PENDING' => 'Bạn đã có một yêu cầu đang chờ cho tin đăng này.',
      'MATERIAL_UNAVAILABLE' => 'Tài liệu hiện không thể nhận yêu cầu.',
      _ => null,
    };
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text('${card.subject} · ${card.condition}'),
                    const SizedBox(height: 8),
                    Text('Chủ tài liệu: ${details.ownerName}'),
                    if (details.meetingArea != null)
                      Text('Khu vực gặp: ${details.meetingArea}'),
                    const SizedBox(height: 8),
                    Chip(
                      label: Text(
                        'Hình thức: ${requestOfferLabel(card.offerType)}',
                      ),
                    ),
                    if (card.offerType == OfferType.sell &&
                        card.askingPriceVnd != null)
                      Text(
                        'Giá: ${formatVnd(card.askingPriceVnd!)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (blockedMessage != null) ...[
              Text(blockedMessage, style: TextStyle(color: scheme.error)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push(AppRoutes.requestCenter),
                child: const Text('Xem yêu cầu của tôi'),
              ),
            ] else ...[
              if (policy != null) ...[
                TextField(
                  key: const ValueKey('request-days'),
                  controller: _daysController,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 2,
                  decoration: InputDecoration(
                    labelText: 'Số ngày muốn mượn',
                    helperText:
                        'Từ ${policy.minDays} đến ${policy.maxDays} ngày. '
                        'Chủ tài liệu duyệt đúng số ngày bạn đề xuất.',
                    errorText: _daysError,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(_offerNote(card.offerType)),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('request-submit'),
                onPressed: _busy ? null : () => _submit(details),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  'Gửi yêu cầu ${requestOfferLabel(card.offerType).toLowerCase()}',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _offerNote(OfferType type) => switch (type) {
    OfferType.borrow =>
      'Khi được duyệt, giao dịch mượn được tạo và hai bên hẹn bàn giao.',
    OfferType.sell =>
      'Gửi yêu cầu chưa phải thanh toán. Chỉ chuyển khoản sau khi người bán '
          'duyệt và giao dịch hiển thị bước thanh toán.',
    OfferType.donate =>
      'Khi được duyệt, chủ tài liệu sẽ bàn giao miễn phí cho bạn.',
  };
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/contracts/command_result.dart';
import '../../../../core/contracts/domain_enums.dart';
import '../../../../core/contracts/models/transaction.dart';
import '../../../../core/errors/app_error.dart';
import '../../domain/idempotency_key.dart';
import '../../domain/transaction_labels.dart';
import '../../providers/transaction_providers.dart';

typedef _Command = Future<CommandResult<TransactionDetails>> Function(String key);

// Khu vực thao tác của SCR-14. Nút chỉ hiện theo allowedActions (gợi ý server);
// kết quả chỉ được hiển thị sau ACK, rồi tải lại snapshot từ server.
class TransactionActionsCard extends ConsumerStatefulWidget {
  const TransactionActionsCard({super.key, required this.details});
  final TransactionDetails details;

  @override
  ConsumerState<TransactionActionsCard> createState() =>
      _TransactionActionsCardState();
}

class _TransactionActionsCardState extends ConsumerState<TransactionActionsCard> {
  // Key của từng thao tác đang chờ; giữ lại khi timeout/mất mạng để retry an toàn.
  final Map<String, String> _pendingKeys = {};
  bool _busy = false;

  TransactionDetails get _details => widget.details;

  Future<void> _execute(
    String command,
    _Command call, {
    required String successMessage,
  }) async {
    if (_busy) return;
    final key = _pendingKeys.putIfAbsent(command, newIdempotencyKey);
    setState(() => _busy = true);
    CommandResult<TransactionDetails> result;
    try {
      result = await call(key);
    } catch (_) {
      // Không biết server đã ghi hay chưa: không báo thành công.
      result = const CommandError(DomainErrorCode.timeoutUnknown,
          'Chưa rõ kết quả. Đang tải lại trạng thái từ máy chủ.');
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final String message;
    switch (result) {
      case CommandOk():
        _pendingKeys.remove(command);
        message = successMessage;
      case CommandError(:final code, :final safeMessage):
        final retryable = code == DomainErrorCode.timeoutUnknown ||
            code == DomainErrorCode.networkUnavailable;
        if (!retryable) _pendingKeys.remove(command);
        message = safeMessage;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    refreshTransaction(ref, _details.id);
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

  String get _price {
    final price = _details.transaction.agreedPriceVnd;
    return price == null ? 'số tiền đã chốt' : formatVnd(price);
  }

  Future<void> _reportTransfer() async {
    final ok = await _confirm(
      title: 'Báo đã chuyển khoản?',
      message: 'Thao tác này chỉ thông báo cho người bán. Giao dịch tiếp tục khi '
          'người bán tự kiểm tra tài khoản và xác nhận đã nhận $_price.',
      confirmLabel: 'Tôi đã chuyển',
    );
    if (!ok) return;
    final repo = ref.read(sellerPaymentRepositoryProvider);
    await _execute('report_buyer_transfer',
        (key) => repo.reportBuyerTransfer(_details.id, idempotencyKey: key),
        successMessage: 'Đã báo người bán. Chờ người bán xác nhận đã nhận tiền.');
  }

  Future<void> _confirmPayment() async {
    final ok = await _confirm(
      title: 'Xác nhận đã nhận tiền?',
      message: 'Chỉ xác nhận khi bạn đã tự kiểm tra tài khoản ngân hàng và thấy '
          'đủ $_price. StudyShare không kiểm tra giao dịch ngân hàng. '
          'Sau khi xác nhận, giao dịch chuyển sang bước bàn giao.',
      confirmLabel: 'Đã nhận đủ tiền',
    );
    if (!ok) return;
    final repo = ref.read(sellerPaymentRepositoryProvider);
    await _execute('confirm_seller_payment',
        (key) => repo.confirmSellerPayment(_details.id, idempotencyKey: key),
        successMessage: 'Đã ghi nhận bạn nhận đủ tiền. Có thể bắt đầu bàn giao.');
  }

  Future<void> _reportRefund() async {
    final ok = await _confirm(
      title: 'Báo đã hoàn tiền?',
      message: 'Chỉ bấm khi bạn đã chuyển trả $_price cho người mua ngoài ứng dụng. '
          'Người mua sẽ tự kiểm tra và xác nhận.',
      confirmLabel: 'Tôi đã hoàn tiền',
    );
    if (!ok) return;
    final repo = ref.read(sellerPaymentRepositoryProvider);
    await _execute('report_seller_refund',
        (key) => repo.reportSellerRefund(_details.id, idempotencyKey: key),
        successMessage: 'Đã báo hoàn tiền. Chờ người mua xác nhận.');
  }

  Future<void> _confirmRefund() async {
    final ok = await _confirm(
      title: 'Xác nhận đã nhận lại tiền?',
      message: 'Chỉ bấm khi bạn đã kiểm tra tài khoản và nhận đủ $_price hoàn lại.',
      confirmLabel: 'Đã nhận lại tiền',
    );
    if (!ok) return;
    final repo = ref.read(sellerPaymentRepositoryProvider);
    await _execute('confirm_refund_received',
        (key) => repo.confirmRefundReceived(_details.id, idempotencyKey: key),
        successMessage: 'Đã ghi nhận bạn nhận lại tiền.');
  }

  Future<void> _proposeCancellation() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _CancellationReasonDialog(details: _details),
    );
    if (reason == null) return;
    final repo = ref.read(transactionCancellationRepositoryProvider);
    // Mỗi lần gửi lý do là một ý định mới -> key mới nếu lần trước đã xong.
    await _execute('propose_transaction_cancellation',
        (key) => repo.proposeCancellation(_details.id, reason, idempotencyKey: key),
        successMessage: 'Đã gửi đề nghị hủy. Chờ bên còn lại phản hồi.');
  }

  Future<void> _withdrawCancellation() async {
    final repo = ref.read(transactionCancellationRepositoryProvider);
    await _execute('withdraw_transaction_cancellation',
        (key) => repo.withdrawCancellation(_details.id, idempotencyKey: key),
        successMessage: 'Đã rút lại đề nghị hủy.');
  }

  Future<void> _declineCancellation() async {
    final repo = ref.read(transactionCancellationRepositoryProvider);
    await _execute('decline_transaction_cancellation',
        (key) => repo.declineCancellation(_details.id, idempotencyKey: key),
        successMessage: 'Bạn đã không đồng ý hủy. Giao dịch tiếp tục.');
  }

  Future<void> _acceptCancellation() async {
    final ok = await _confirm(
      title: 'Đồng ý hủy giao dịch?',
      message: 'Giao dịch chỉ được hủy khi tài liệu đã ở người đăng, không còn tiền '
          'cần hoàn và không có sự cố đang mở. Lịch sử giao dịch vẫn được giữ.',
      confirmLabel: 'Đồng ý hủy',
    );
    if (!ok) return;
    final repo = ref.read(transactionCancellationRepositoryProvider);
    await _execute('accept_transaction_cancellation',
        (key) => repo.acceptCancellation(_details.id, idempotencyKey: key),
        successMessage: 'Giao dịch đã được hủy.');
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final id = Uri.encodeComponent(details.id);
    VoidCallback? guard(Future<void> Function() action) =>
        _busy ? null : () => action();

    final primary = <Widget>[
      if (details.can(TransactionAction.confirmSellerPayment))
        FilledButton.icon(
          onPressed: guard(_confirmPayment),
          icon: const Icon(Icons.price_check),
          label: const Text('Xác nhận đã nhận tiền'),
        ),
      if (details.can(TransactionAction.reportBuyerTransfer))
        FilledButton.icon(
          onPressed: guard(_reportTransfer),
          icon: const Icon(Icons.send_to_mobile_outlined),
          label: const Text('Tôi đã chuyển khoản'),
        ),
      if (details.can(TransactionAction.reportSellerRefund))
        FilledButton.icon(
          onPressed: guard(_reportRefund),
          icon: const Icon(Icons.undo),
          label: const Text('Tôi đã hoàn tiền'),
        ),
      if (details.can(TransactionAction.confirmRefundReceived))
        FilledButton.icon(
          onPressed: guard(_confirmRefund),
          icon: const Icon(Icons.price_check),
          label: const Text('Tôi đã nhận lại tiền'),
        ),
      if (details.can(TransactionAction.startHandover))
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => context.push('${AppRoutes.createDelivery}?transactionId=$id'),
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('Tạo nhiệm vụ giao hộ'),
        ),
    ];
    final secondary = <Widget>[
      if (details.can(TransactionAction.respondCancellation)) ...[
        FilledButton.tonal(
          onPressed: guard(_acceptCancellation),
          child: const Text('Đồng ý hủy'),
        ),
        OutlinedButton(
          onPressed: guard(_declineCancellation),
          child: const Text('Không đồng ý hủy'),
        ),
      ],
      if (details.can(TransactionAction.withdrawCancellation))
        OutlinedButton(
          onPressed: guard(_withdrawCancellation),
          child: const Text('Rút đề nghị hủy'),
        ),
      if (details.can(TransactionAction.reportIssue))
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => context.push('${AppRoutes.createIssue}?transactionId=$id'),
          icon: const Icon(Icons.report_outlined),
          label: const Text('Báo sự cố'),
        ),
      if (details.can(TransactionAction.proposeCancellation))
        TextButton.icon(
          onPressed: guard(_proposeCancellation),
          icon: const Icon(Icons.block),
          label: const Text('Đề nghị hủy'),
        ),
    ];
    if (primary.isEmpty && secondary.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Thao tác', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (_busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (primary.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: primary),
            if (primary.isNotEmpty && secondary.isNotEmpty)
              const SizedBox(height: 8),
            if (secondary.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: secondary),
          ],
        ),
      ),
    );
  }
}

class _CancellationReasonDialog extends StatefulWidget {
  const _CancellationReasonDialog({required this.details});
  final TransactionDetails details;

  @override
  State<_CancellationReasonDialog> createState() =>
      _CancellationReasonDialogState();
}

class _CancellationReasonDialogState extends State<_CancellationReasonDialog> {
  static const _maxLength = 500;
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _moneyWarning {
    final details = widget.details;
    final payment = details.payment;
    if (details.transaction.type != OfferType.sell || payment == null) return null;
    if (payment.isSellerConfirmed) {
      return 'Người bán đã nhận tiền: cần hoàn tiền ngoài ứng dụng và người mua '
          'xác nhận đã nhận lại thì mới hủy được.';
    }
    if (payment.buyerReportedAt != null) {
      return 'Người mua đã báo chuyển khoản. Nếu tiền đã chuyển, hãy thống nhất '
          'hoàn tiền trước khi đồng ý hủy.';
    }
    return null;
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Vui lòng nhập lý do hủy.');
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    final warning = _moneyWarning;
    return AlertDialog(
      title: const Text('Đề nghị hủy giao dịch'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bên còn lại cần đồng ý thì giao dịch mới được hủy.'),
          if (warning != null) ...[
            const SizedBox(height: 8),
            Text(warning, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const Key('cancellation-reason'),
            controller: _controller,
            maxLength: _maxLength,
            maxLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Lý do',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Để sau'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Gửi đề nghị')),
      ],
    );
  }
}

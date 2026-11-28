import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../../core/contracts/repositories/transaction_repository.dart';
import '../../../core/errors/app_error.dart';
import '../../transactions/domain/idempotency_key.dart';
import '../../transactions/providers/transaction_providers.dart';
import '../providers/borrow_providers.dart';

/// Nút "Yêu cầu trả tài liệu" cho người đang mượn (module Khanh).
///
/// Chỉ hiển thị khi server trả `CAN_REQUEST_RETURN`; RPC `request_borrow_return`
/// chỉ ghi ý định trả (BORROWING -> RETURN_PENDING), không đổi holder hay hạn trả.
class RequestReturnButton extends ConsumerStatefulWidget {
  const RequestReturnButton({super.key, required this.transactionId});
  final String transactionId;

  @override
  ConsumerState<RequestReturnButton> createState() =>
      _RequestReturnButtonState();
}

class _RequestReturnButtonState extends ConsumerState<RequestReturnButton> {
  // Giữ key khi timeout/mất mạng để bấm lại không tạo yêu cầu trả thứ hai.
  String? _pendingKey;
  bool _busy = false;

  BorrowRepository? _readRepository() {
    try {
      return ref.read(borrowRepositoryProvider);
    } catch (error) {
      // Không có backend/phiên: báo rõ, không giả là timeout và không dùng mock.
      _showMessage(
        error is AppError
            ? error.safeMessage
            : 'Chức năng mượn/trả cần đăng nhập và kết nối Supabase.',
      );
      return null;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requestReturn() async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yêu cầu trả tài liệu?'),
        content: const Text(
          'Chủ tài liệu sẽ được thông báo. Bạn vẫn là người giữ sách cho đến khi '
          'bàn giao trả được xác nhận.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yêu cầu trả'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final repository = _readRepository();
    if (repository == null) return;

    final key = _pendingKey ??= newIdempotencyKey();
    setState(() => _busy = true);
    CommandResult<StudyTransaction> result;
    try {
      result = await repository.requestReturn(
        widget.transactionId,
        idempotencyKey: key,
      );
    } catch (_) {
      result = const CommandError(
        DomainErrorCode.timeoutUnknown,
        'Chưa rõ máy chủ đã ghi nhận hay chưa. Hãy thử lại cùng thao tác.',
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final String message;
    switch (result) {
      case CommandOk():
        _pendingKey = null;
        message = 'Đã gửi yêu cầu trả. Hãy hẹn bàn giao trả với chủ tài liệu.';
      case CommandError(:final code, :final safeMessage):
        final retryable =
            code == DomainErrorCode.timeoutUnknown ||
            code == DomainErrorCode.networkUnavailable;
        if (!retryable) _pendingKey = null;
        message = safeMessage;
    }
    _showMessage(message);
    refreshTransaction(ref, widget.transactionId);
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const ValueKey('borrow-request-return'),
      onPressed: _busy ? null : _requestReturn,
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.assignment_return_outlined),
      label: const Text('Yêu cầu trả tài liệu'),
    );
  }
}

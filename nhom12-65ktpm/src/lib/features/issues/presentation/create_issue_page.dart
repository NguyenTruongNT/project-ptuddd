import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/issue.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../../core/errors/app_error.dart';
import '../../../design_system/widgets/study_async_view.dart';
import '../../transactions/domain/idempotency_key.dart';
import '../domain/issue_labels.dart';
import '../providers/issue_providers.dart';

// SCR-22 – Báo cáo sự cố (UI-09/UI-14, màn con). Chủ trì: Sơn + Đăng.
// Giao dịch (và lượt bàn giao nếu có) được CỐ ĐỊNH từ ngữ cảnh gọi tới, người dùng
// không chọn lại. Gửi Issue không đổi owner/holder/hạn trả/thanh toán.
class CreateIssuePage extends ConsumerWidget {
  const CreateIssuePage({super.key, this.transactionId, this.handoverId});

  final String? transactionId;
  final String? handoverId;

  static const noAccessMessage =
      'Không tìm thấy giao dịch hoặc bạn không có quyền báo sự cố.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = transactionId;
    return Scaffold(
      appBar: AppBar(title: const Text('Báo sự cố')),
      body: id == null || id.isEmpty
          ? const _Message(noAccessMessage)
          : StudyAsyncView<TransactionDetails?>(
              value: ref.watch(issueTransactionContextProvider(id)),
              onRetry: () => ref.invalidate(issueTransactionContextProvider(id)),
              // Không phân biệt "không tồn tại" và "không có quyền" để tránh lộ dữ liệu.
              isEmpty: (data) => data == null,
              emptyMessage: noAccessMessage,
              builder: (details) => details!.can(TransactionAction.reportIssue)
                  ? _IssueForm(details: details, handoverId: handoverId)
                  : const _Message('Giao dịch này hiện không nhận báo sự cố.'),
            ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}

class _IssueForm extends ConsumerStatefulWidget {
  const _IssueForm({required this.details, this.handoverId});

  final TransactionDetails details;
  final String? handoverId;

  @override
  ConsumerState<_IssueForm> createState() => _IssueFormState();
}

class _IssueFormState extends ConsumerState<_IssueForm> {
  static const _maxLength = 1000;

  final _controller = TextEditingController();
  IssueType _type = IssueType.wrongCondition;
  String? _error;
  bool _busy = false;

  // Giữ key khi timeout/mất mạng để retry không tạo Issue thứ hai; đổi nội dung
  // thì là ý định mới nên phải dùng key mới.
  String? _pendingKey;
  String? _pendingPayload;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final reason = _controller.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Vui lòng mô tả sự cố.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });

    final payload = '${_type.wire}|$reason|${widget.handoverId ?? ''}';
    if (_pendingPayload != payload) {
      _pendingKey = newIdempotencyKey();
      _pendingPayload = payload;
    }
    final input = CreateIssueInput(
      transactionId: widget.details.id,
      type: _type,
      reason: reason,
      handoverId: widget.handoverId,
    );

    final repo = ref.read(issueRepositoryProvider);
    CommandResult<IssueDetails> result;
    try {
      result = await repo.reportIssue(input, idempotencyKey: _pendingKey!);
    } catch (_) {
      // Không biết server đã ghi hay chưa: không báo thành công.
      result = const CommandError(DomainErrorCode.timeoutUnknown,
          'Chưa rõ kết quả. Hãy bấm gửi lại để kiểm tra với máy chủ.');
    }
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case CommandOk(:final data):
        _pendingKey = null;
        _pendingPayload = null;
        refreshIssue(ref, issueId: data.id, transactionId: widget.details.id);
        // Sau ACK mới chuyển sang chi tiết sự cố (SCR-23), thay thế màn gửi.
        context.pushReplacement(AppRoutes.issueDetails(data.id));
      case CommandError(:final code, :final safeMessage):
        final retryable = code == DomainErrorCode.timeoutUnknown ||
            code == DomainErrorCode.networkUnavailable;
        if (!retryable) {
          _pendingKey = null;
          _pendingPayload = null;
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(safeMessage)));
        refreshIssue(ref, transactionId: widget.details.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final details = widget.details;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(details.materialTitle),
            subtitle: Text(
              widget.handoverId == null
                  ? 'Sự cố của giao dịch này'
                  : 'Sự cố của một lượt bàn giao trong giao dịch này',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Loại sự cố', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in IssueType.values)
              ChoiceChip(
                label: Text(issueTypeLabelVi(type)),
                selected: _type == type,
                onSelected: _busy ? null : (_) => setState(() => _type = type),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('issue-reason'),
          controller: _controller,
          enabled: !_busy,
          maxLength: _maxLength,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: 'Mô tả sự cố',
            alignLabelWithHint: true,
            errorText: _error,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        const _Notice(
          icon: Icons.info_outline,
          text: 'Báo sự cố không thay đổi người sở hữu, người đang giữ tài liệu, '
              'hạn trả hay thanh toán. Các bên sẽ cùng thống nhất phương án giải quyết.',
        ),
        const SizedBox(height: 8),
        const _Notice(
          icon: Icons.photo_camera_outlined,
          text: 'Ảnh bằng chứng (tùy chọn) sẽ được bổ sung cùng phần bàn giao. '
              'Ảnh luôn được lưu riêng tư, chỉ các bên liên quan mới xem được.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: const Text('Gửi báo cáo'),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: textTheme.bodySmall)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contracts/command_result.dart';
import '../../../../core/contracts/models/issue.dart';
import '../../../../core/errors/app_error.dart';
import '../../../transactions/domain/idempotency_key.dart';
import '../../providers/issue_providers.dart';

typedef _Command = Future<CommandResult<IssueDetails>> Function(String key);

// Khu vực thao tác của SCR-23. Nút chỉ hiện theo allowedActions (gợi ý server);
// kết quả chỉ được hiển thị sau ACK, rồi tải lại snapshot từ server.
// Không có nút "đóng sự cố": chỉ khi các bên cùng xác nhận server mới RESOLVED.
class IssueActionsCard extends ConsumerStatefulWidget {
  const IssueActionsCard({super.key, required this.details});
  final IssueDetails details;

  @override
  ConsumerState<IssueActionsCard> createState() => _IssueActionsCardState();
}

class _IssueActionsCardState extends ConsumerState<IssueActionsCard> {
  // Key của từng thao tác đang chờ; giữ lại khi timeout/mất mạng để retry an toàn.
  // Khóa gồm cả nội dung để đổi nội dung thì dùng key mới.
  final Map<String, String> _pendingKeys = {};
  bool _busy = false;

  IssueDetails get _details => widget.details;

  Future<void> _execute(
    String operation,
    _Command call, {
    required String successMessage,
  }) async {
    if (_busy) return;
    final key = _pendingKeys.putIfAbsent(operation, newIdempotencyKey);
    setState(() => _busy = true);
    CommandResult<IssueDetails> result;
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
        _pendingKeys.remove(operation);
        message = successMessage;
      case CommandError(:final code, :final safeMessage):
        final retryable = code == DomainErrorCode.timeoutUnknown ||
            code == DomainErrorCode.networkUnavailable;
        if (!retryable) _pendingKeys.remove(operation);
        message = safeMessage;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    refreshIssue(ref,
        issueId: _details.id, transactionId: _details.issue.transactionId);
  }

  Future<void> _propose() async {
    final summary = await showDialog<String>(
      context: context,
      builder: (context) => const _ProposalDialog(),
    );
    if (summary == null) return;
    final repo = ref.read(issueRepositoryProvider);
    await _execute('propose|$summary',
        (key) => repo.proposeResolution(_details.id, summary, idempotencyKey: key),
        successMessage: 'Đã gửi phương án. Các bên cần xác nhận để giải quyết sự cố.');
  }

  Future<void> _confirm(IssueResolutionProposal proposal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận phương án?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phương án (bản ${proposal.revision}):',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(proposal.summary),
            const SizedBox(height: 12),
            const Text(
              'Sự cố chỉ được đóng khi tất cả các bên cùng xác nhận. Việc xác nhận '
              'không thay đổi người sở hữu, người đang giữ tài liệu, hạn trả hay '
              'thanh toán.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tôi đồng ý'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(issueRepositoryProvider);
    // Gắn đúng revision đang hiển thị; phương án đổi giữa chừng sẽ bị server từ chối.
    await _execute('confirm|${proposal.revision}',
        (key) => repo.confirmResolution(_details.id, proposal.revision,
            idempotencyKey: key),
        successMessage: 'Đã ghi nhận xác nhận của bạn.');
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final proposal = details.proposal;
    final canPropose = details.can(IssueAction.proposeResolution);
    final canConfirm = proposal != null && details.can(IssueAction.confirmResolution);
    if (!canPropose && !canConfirm) return const SizedBox.shrink();

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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canConfirm)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _confirm(proposal),
                    icon: const Icon(Icons.check),
                    label: const Text('Xác nhận phương án'),
                  ),
                if (canPropose)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _propose,
                    icon: const Icon(Icons.edit_note),
                    label: Text(proposal == null
                        ? 'Đề xuất phương án'
                        : 'Đề xuất phương án khác'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProposalDialog extends StatefulWidget {
  const _ProposalDialog();

  @override
  State<_ProposalDialog> createState() => _ProposalDialogState();
}

class _ProposalDialogState extends State<_ProposalDialog> {
  static const _maxLength = 1000;
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final summary = _controller.text.trim();
    if (summary.isEmpty) {
      setState(() => _error = 'Vui lòng nhập phương án.');
      return;
    }
    Navigator.of(context).pop(summary);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đề xuất phương án giải quyết'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Phương án mới sẽ thay thế phương án cũ và các xác nhận trước đó '
            'phải làm lại. Bạn cũng cần tự xác nhận sau khi đề xuất.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('resolution-summary'),
            controller: _controller,
            maxLength: _maxLength,
            maxLines: 4,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Phương án',
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
        FilledButton(onPressed: _submit, child: const Text('Gửi đề xuất')),
      ],
    );
  }
}

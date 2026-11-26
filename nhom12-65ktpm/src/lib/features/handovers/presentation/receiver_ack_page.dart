import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/handover.dart';
import '../../../core/providers/mock_query_providers.dart';
import '../../../design_system/widgets/feature_scaffold.dart';
import '../../../design_system/widgets/study_empty.dart';
import '../../../design_system/widgets/study_error.dart';
import '../../../design_system/widgets/study_loading.dart';
import '../domain/handover_labels.dart';
import '../providers/handover_providers.dart';

/// SCR-20 – Xác nhận nhận tài liệu (UI-14). Phụ trách: Vũ Hải Đăng.
/// Người nhận (Receiver) kiểm tra ảnh minh chứng của người giao,
/// bấm "Xác nhận đã nhận" hoặc "Từ chối / Báo sự cố".
class ReceiverAckPage extends ConsumerStatefulWidget {
  const ReceiverAckPage({
    super.key,
    required this.handoverId,
  });

  final String handoverId;

  @override
  ConsumerState<ReceiverAckPage> createState() => _ReceiverAckPageState();
}

class _ReceiverAckPageState extends ConsumerState<ReceiverAckPage> {
  bool _isActionInProgress = false;
  String? _errorMessage;

  Future<void> _handleConfirmReceipt(Handover handover) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận nhận tài liệu'),
        content: const Text(
          'Bạn xác nhận đã gặp người giao, nhận đúng tài liệu và kiểm tra tình trạng sách?\n\n'
          'Sau khi xác nhận, quyền giữ sách (holder) sẽ chính thức được chuyển sang bạn.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xác nhận đã nhận')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isActionInProgress = true;
      _errorMessage = null;
    });

    final repo = ref.read(handoverRepositoryProvider);
    final idempotencyKey = 'confirm-receipt-${widget.handoverId}-${DateTime.now().millisecondsSinceEpoch}';

    final result = await repo.confirmReceipt(widget.handoverId, idempotencyKey: idempotencyKey);

    if (!mounted) return;
    setState(() => _isActionInProgress = false);

    switch (result) {
      case CommandOk():
        refreshHandover(ref, widget.handoverId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Xác nhận nhận tài liệu thành công!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        context.pop();
      case CommandError(:final safeMessage):
        setState(() {
          _errorMessage = safeMessage;
        });
    }
  }

  Future<void> _handleRefuseReceipt(Handover handover) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Từ chối nhận tài liệu & Báo sự cố'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vui lòng nhập rõ lý do từ chối (sai sách, sách hư hỏng, chưa gặp người giao...):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Lý do từ chối *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập lý do từ chối cụ thể.')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Xác nhận từ chối'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isActionInProgress = true;
      _errorMessage = null;
    });

    final repo = ref.read(handoverRepositoryProvider);
    final idempotencyKey = 'refuse-${widget.handoverId}-${DateTime.now().millisecondsSinceEpoch}';

    final result = await repo.refuseReceipt(
      RefuseHandoverInput(
        handoverId: widget.handoverId,
        reason: reasonController.text.trim(),
      ),
      idempotencyKey: idempotencyKey,
    );

    if (!mounted) return;
    setState(() => _isActionInProgress = false);

    switch (result) {
      case CommandOk(:final data):
        refreshHandover(ref, widget.handoverId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã từ chối nhận và ghi nhận sự cố: ${data.id}'),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 3),
          ),
        );
        context.pushReplacement(AppRoutes.issues);
      case CommandError(:final safeMessage):
        setState(() {
          _errorMessage = safeMessage;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(demoViewerIdProvider);
    final handoverAsync = ref.watch(handoverDetailsProvider(widget.handoverId));

    return FeatureScaffold(
      title: 'Xác nhận nhận tài liệu',
      fallbackLocation: AppRoutes.deliveries,
      body: handoverAsync.when(
        loading: () => const StudyLoading(),
        error: (err, stack) => StudyError(
          onRetry: () => ref.invalidate(handoverDetailsProvider(widget.handoverId)),
        ),
        data: (handover) {
          if (handover == null) {
            return const StudyEmpty(message: 'Không tìm thấy lượt bàn giao này.');
          }

          final isReceiver = handover.toUserId == currentUserId;
          final statusColor = handoverStatusColor(handover.status);
          final statusLabel = handoverStatusLabelVi(handover.status);

          final hasEvidence = handover.evidencePhotoCount > 0;
          final canConfirm = handover.status == HandoverStatus.awaitingReceiverConfirmation;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thẻ thông tin chặng
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Lượt giao: ${handover.id}',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(
                                statusLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildInfoRow('Người giao:', handover.fromUserId),
                        const SizedBox(height: 8),
                        _buildInfoRow('Người nhận:', handover.toUserId),
                        const SizedBox(height: 8),
                        _buildInfoRow('Giao dịch liên kết:', handover.transactionId),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(height: 16),
                ],

                // Ảnh minh chứng người giao đã nộp
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Ảnh minh chứng người giao',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              hasEvidence
                                  ? '${handover.evidencePhotoCount} ảnh minh chứng'
                                  : 'Chưa có ảnh',
                              style: TextStyle(
                                color: hasEvidence ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (hasEvidence) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var i = 1; i <= handover.evidencePhotoCount; i++)
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade300),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.verified, color: Colors.green, size: 32),
                                      const SizedBox(height: 4),
                                      Text('Minh chứng $i', style: const TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber, color: Colors.amber),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Người giao chưa nộp ảnh minh chứng thực tế. Bạn không nên xác nhận nhận sách trước khi có ảnh.',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Các nút hành động cho bên nhận
                if (isReceiver && handover.status != HandoverStatus.confirmed) ...[
                  // Nút 1: Xác nhận đã nhận
                  FilledButton.icon(
                    onPressed: (_isActionInProgress || !canConfirm)
                        ? null
                        : () => _handleConfirmReceipt(handover),
                    icon: _isActionInProgress
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Xác nhận đã nhận tài liệu'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF16A34A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nút 2: Từ chối / Báo sự cố
                  OutlinedButton.icon(
                    onPressed: _isActionInProgress ? null : () => _handleRefuseReceipt(handover),
                    icon: const Icon(Icons.report_problem_outlined, color: Colors.red),
                    label: const Text('Từ chối / Báo sự cố', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ] else if (handover.status == HandoverStatus.confirmed) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Lượt bàn giao này đã hoàn tất thành công.',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(color: Colors.grey)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

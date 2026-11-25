import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/providers/mock_query_providers.dart';
import '../../../design_system/widgets/study_empty.dart';
import '../../../design_system/widgets/study_error.dart';
import '../../../design_system/widgets/study_loading.dart';
import '../domain/delivery_labels.dart';
import '../providers/delivery_providers.dart';

/// SCR-17 – Chi tiết nhiệm vụ giao hộ (UI-12). Phụ trách: Vũ Hải Đăng.
/// Xem chi tiết nhiệm vụ, duyệt ứng viên Courier (chọn 1 C duy nhất),
/// theo dõi tiến độ các chặng bàn giao H1 & H2, chỉ đường và đánh giá.
class DeliveryDetailsPage extends ConsumerStatefulWidget {
  const DeliveryDetailsPage({
    super.key,
    required this.taskId,
  });

  final String taskId;

  @override
  ConsumerState<DeliveryDetailsPage> createState() => _DeliveryDetailsPageState();
}

class _DeliveryDetailsPageState extends ConsumerState<DeliveryDetailsPage> {
  bool _isActionInProgress = false;
  int _selectedStars = 5;
  bool _hasRated = false;

  Future<void> _handleApply() async {
    setState(() => _isActionInProgress = true);
    final repo = ref.read(deliveryRepositoryProvider);
    final idempotencyKey = 'apply-${widget.taskId}-${DateTime.now().millisecondsSinceEpoch}';

    final result = await repo.applyForTask(widget.taskId, idempotencyKey: idempotencyKey);
    if (!mounted) return;
    setState(() => _isActionInProgress = false);

    switch (result) {
      case CommandOk():
        refreshDeliveries(ref, taskId: widget.taskId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi đơn ứng tuyển giao hộ thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      case CommandError(:final safeMessage):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(safeMessage),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  Future<void> _handleSelectCourier(String applicationId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận chọn người giao hộ'),
        content: const Text(
          'Bạn chỉ có thể chọn đúng một sinh viên giao hộ. Các đơn ứng tuyển khác sẽ bị từ chối.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đồng ý')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionInProgress = true);
    final repo = ref.read(deliveryRepositoryProvider);
    final idempotencyKey = 'select-courier-${widget.taskId}-$applicationId';

    final result = await repo.selectCourier(
      widget.taskId,
      applicationId,
      idempotencyKey: idempotencyKey,
    );

    if (!mounted) return;
    setState(() => _isActionInProgress = false);

    switch (result) {
      case CommandOk():
        refreshDeliveries(ref, taskId: widget.taskId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã chọn người giao hộ thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      case CommandError(:final safeMessage):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(safeMessage), backgroundColor: Colors.red),
        );
    }
  }

  void _showDirectionsDialog(String pointName, String pointDesc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.navigation, color: Colors.blue),
            const SizedBox(width: 8),
            Text(pointName),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Địa chỉ hẹn: $pointDesc', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'Ứng dụng sẽ mở bản đồ ngoài (Google Maps) để chỉ đường cho bạn theo quy định MVP.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đang mở bản đồ chỉ đường tới: $pointDesc')),
              );
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Mở Google Maps'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(demoViewerIdProvider);
    final taskAsync = ref.watch(deliveryTaskDetailsProvider(widget.taskId));
    final appsAsync = ref.watch(deliveryApplicationsProvider(widget.taskId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Nhiệm vụ: ${widget.taskId}'),
      ),
      body: taskAsync.when(
        loading: () => const StudyLoading(),
        error: (err, stack) => StudyError(
          onRetry: () => ref.invalidate(deliveryTaskDetailsProvider(widget.taskId)),
        ),
        data: (task) {
          if (task == null) {
            return const StudyEmpty(message: 'Không tìm thấy nhiệm vụ giao hộ này.');
          }

          final isSender = task.senderId == currentUserId;
          final isCourier = task.assignedCourierId == currentUserId;
          final isReceiver = task.finalReceiverId == currentUserId;
          final isParticipant = isSender || isCourier || isReceiver;

          final statusColor = deliveryStatusColor(task.status);
          final statusLabel = deliveryStatusLabelVi(task.status);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header trạng thái
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
                            Text(
                              'Trạng thái nhiệm vụ',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Chip(
                              label: Text(
                                statusLabel,
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: statusColor.withValues(alpha: 0.1),
                              side: BorderSide(color: statusColor),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildInfoRow('Người gửi:', task.senderId),
                        const SizedBox(height: 8),
                        _buildInfoRow('Người nhận cuối:', task.finalReceiverId),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Người giao hộ (C):',
                          task.assignedCourierId == null ? 'Chưa phân công' : task.assignedCourierId!,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Điểm hẹn lấy và giao sách
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Điểm hẹn và tuyến đường',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.arrow_upward, color: Colors.white),
                          ),
                          title: const Text('Điểm lấy (Pickup)'),
                          subtitle: const Text('Cổng Đại học Thủy Lợi, 175 Tây Sơn'),
                          trailing: IconButton(
                            icon: const Icon(Icons.directions, color: Colors.blue),
                            onPressed: () => _showDirectionsDialog(
                              'Điểm lấy',
                              'Cổng Đại học Thủy Lợi, 175 Tây Sơn',
                            ),
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(Icons.arrow_downward, color: Colors.white),
                          ),
                          title: const Text('Điểm giao (Dropoff)'),
                          subtitle: const Text('Ký túc xá Thủy Lợi, P.304'),
                          trailing: IconButton(
                            icon: const Icon(Icons.directions, color: Colors.green),
                            onPressed: () => _showDirectionsDialog(
                              'Điểm giao',
                              'Ký túc xá Thủy Lợi, P.304',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tiến trình 2 chặng bàn giao: H1 và H2
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tiến trình các chặng bàn giao',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _buildLegTile(
                          title: 'Chặng 1 (H1): Người gửi → Courier C',
                          subtitle: task.status == DeliveryTaskStatus.open || task.status == DeliveryTaskStatus.assigned
                              ? 'Chờ bàn giao sách cho C'
                              : 'Đã hoàn thành chặng 1',
                          handoverId: 'handover-delivery-h1',
                          isDone: task.status != DeliveryTaskStatus.open && task.status != DeliveryTaskStatus.assigned,
                          canPrepare: isSender && task.status == DeliveryTaskStatus.assigned,
                          canReceive: isCourier && task.status == DeliveryTaskStatus.assigned,
                        ),
                        const Divider(),
                        _buildLegTile(
                          title: 'Chặng 2 (H2): Courier C → Người nhận B',
                          subtitle: task.status == DeliveryTaskStatus.completed
                              ? 'Đã giao thành công'
                              : 'Chờ giao cho người nhận cuối',
                          handoverId: 'handover-delivery-h2',
                          isDone: task.status == DeliveryTaskStatus.completed,
                          canPrepare: isCourier && task.status == DeliveryTaskStatus.pickedUp,
                          canReceive: isReceiver && task.status == DeliveryTaskStatus.deliveryPendingConfirmation,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Danh sách đơn ứng tuyển của Courier C
                appsAsync.when(
                  loading: () => const StudyLoading(),
                  error: (e, s) => Text('Lỗi tải ứng viên: $e'),
                  data: (apps) {
                    if (apps.isEmpty && task.status == DeliveryTaskStatus.open) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Chưa có sinh viên nào ứng tuyển nhiệm vụ này.'),
                        ),
                      );
                    }
                    if (apps.isEmpty) return const SizedBox.shrink();

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đơn ứng tuyển giao hộ (${apps.length})',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            for (final app in apps) ...[
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: app.status == DeliveryApplicationStatus.accepted
                                      ? Colors.green.shade100
                                      : Colors.grey.shade200,
                                  child: Icon(
                                    Icons.person,
                                    color: app.status == DeliveryApplicationStatus.accepted
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                ),
                                title: Text(
                                  'Ứng viên: ${app.applicantId}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text('Trạng thái: ${app.status.name}'),
                                trailing: (isSender && task.status == DeliveryTaskStatus.open && app.status == DeliveryApplicationStatus.pending)
                                    ? FilledButton(
                                        onPressed: _isActionInProgress
                                            ? null
                                            : () => _handleSelectCourier(app.id),
                                        child: const Text('Chọn người này'),
                                      )
                                    : null,
                              ),
                              const Divider(),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Đánh giá Courier sau khi hoàn thành
                if (task.status == DeliveryTaskStatus.completed) ...[
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đánh giá người giao hộ',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (_hasRated) ...[
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text('Bạn đã gửi đánh giá cho người giao hộ này!'),
                              ],
                            ),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 1; i <= 5; i++)
                                  IconButton(
                                    icon: Icon(
                                      i <= _selectedStars ? Icons.star : Icons.star_border,
                                      color: Colors.amber,
                                      size: 32,
                                    ),
                                    onPressed: () => setState(() => _selectedStars = i),
                                  ),
                              ],
                            ),
                            Center(
                              child: FilledButton(
                                onPressed: () {
                                  setState(() => _hasRated = true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Đã gửi đánh giá $_selectedStars sao cho Courier!')),
                                  );
                                },
                                child: const Text('Gửi đánh giá'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Nút ứng tuyển cho Courier (khi task OPEN và actor không phải người gửi/nhận)
                if (task.status == DeliveryTaskStatus.open && !isParticipant) ...[
                  FilledButton.icon(
                    onPressed: _isActionInProgress ? null : _handleApply,
                    icon: const Icon(Icons.how_to_reg),
                    label: const Text('Ứng tuyển nhận nhiệm vụ giao hộ này'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildLegTile({
    required String title,
    required String subtitle,
    required String handoverId,
    required bool isDone,
    required bool canPrepare,
    required bool canReceive,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isDone ? Colors.green.shade100 : Colors.amber.shade100,
        child: Icon(
          isDone ? Icons.check : Icons.hourglass_top,
          color: isDone ? Colors.green : Colors.amber.shade800,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: Wrap(
        spacing: 8,
        children: [
          if (canPrepare)
            OutlinedButton(
              onPressed: () => context.push(AppRoutes.prepareHandover(handoverId)),
              child: const Text('Chụp ảnh'),
            ),
          if (canReceive)
            FilledButton(
              onPressed: () => context.push(AppRoutes.receiverAck(handoverId)),
              child: const Text('Xác nhận nhận'),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/providers/mock_query_providers.dart';
import '../../../design_system/widgets/feature_scaffold.dart';
import '../../../design_system/widgets/study_empty.dart';
import '../../../design_system/widgets/study_error.dart';
import '../../../design_system/widgets/study_loading.dart';
import '../../handovers/providers/handover_providers.dart';
import '../domain/delivery_labels.dart';
import '../providers/delivery_providers.dart';

/// SCR-17 – Chi tiết nhiệm vụ giao hộ (UI-12). Phụ trách: Vũ Hải Đăng.
/// Hỗ trợ: duyệt 1 C nguyên tử, C ứng tuyển, rút đơn (MVP-D04),
/// báo giao thất bại tạo chặng hoàn trả (INV-08), chỉ đường và đánh giá 1-5 sao.
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
          SnackBar(content: Text(safeMessage), backgroundColor: Colors.red),
        );
    }
  }

  Future<void> _handleWithdraw() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận rút đơn giao hộ'),
        content: const Text(
          'Nếu bạn chưa nhận sách, đơn ứng tuyển sẽ rút (hoặc nhiệm vụ bị hủy nếu đã được phân công).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Đóng')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xác nhận rút')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isActionInProgress = true);
    final repo = ref.read(deliveryRepositoryProvider);
    final result = await repo.withdrawApplication(
      widget.taskId,
      idempotencyKey: 'withdraw-${widget.taskId}-${DateTime.now().millisecondsSinceEpoch}',
    );
    if (!mounted) return;
    setState(() => _isActionInProgress = false);

    switch (result) {
      case CommandOk():
        refreshDeliveries(ref, taskId: widget.taskId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã rút đơn giao hộ thành công.'),
            backgroundColor: Colors.orange,
          ),
        );
      case CommandError(:final safeMessage):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(safeMessage), backgroundColor: Colors.red),
        );
    }
  }

  Future<void> _handleFailDelivery() async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Báo giao thất bại'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bạn đã nhận sách nhưng không thể giao được cho người nhận cuối? Hệ thống sẽ đánh dấu nhiệm vụ THẤT BẠI và mở lượt bàn giao trả lại cho người đã giao sách cho bạn.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Lý do giao thất bại *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Đóng')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập lý do giao thất bại.')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Xác nhận thất bại'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isActionInProgress = true);
    final repo = ref.read(deliveryRepositoryProvider);
    final result = await repo.failTask(
      widget.taskId,
      reasonController.text.trim(),
      idempotencyKey: 'fail-${widget.taskId}-${DateTime.now().millisecondsSinceEpoch}',
    );
    if (!mounted) return;
    setState(() => _isActionInProgress = false);

    switch (result) {
      case CommandOk():
        refreshDeliveries(ref, taskId: widget.taskId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã ghi nhận giao thất bại. Vui lòng bàn giao trả lại sách cho người gửi.'),
            backgroundColor: Colors.red,
          ),
        );
      case CommandError(:final safeMessage):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(safeMessage), backgroundColor: Colors.red),
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
    final result = await repo.selectCourier(
      widget.taskId,
      applicationId,
      idempotencyKey: 'select-courier-${widget.taskId}-$applicationId',
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

  Future<void> _handleStartHandoverLeg({
    required String transactionId,
    required String toUserId,
  }) async {
    setState(() => _isActionInProgress = true);
    final handoverRepo = ref.read(handoverRepositoryProvider);
    final result = await handoverRepo.createHandover(
      transactionId: transactionId,
      toUserId: toUserId,
      deliveryTaskId: widget.taskId,
      idempotencyKey: 'leg-${widget.taskId}-$toUserId-${DateTime.now().millisecondsSinceEpoch}',
    );
    if (!mounted) return;
    setState(() => _isActionInProgress = false);

    switch (result) {
      case CommandOk(:final data):
        context.push(AppRoutes.prepareHandover(data.id));
      case CommandError(:final safeMessage):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(safeMessage), backgroundColor: Colors.red),
        );
    }
  }

  Future<void> _handleRateCourier() async {
    setState(() => _isActionInProgress = true);
    final repo = ref.read(deliveryRepositoryProvider);
    final result = await repo.rateCourier(widget.taskId, _selectedStars);
    if (!mounted) return;
    setState(() => _isActionInProgress = false);

    switch (result) {
      case CommandOk():
        setState(() => _hasRated = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gửi đánh giá $_selectedStars sao cho Courier!')),
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
    final bundleAsync = ref.watch(deliveryTaskBundleProvider(widget.taskId));

    return FeatureScaffold(
      title: 'Nhiệm vụ: ${widget.taskId}',
      fallbackLocation: AppRoutes.deliveries,
      body: bundleAsync.when(
        loading: () => const StudyLoading(),
        error: (err, stack) => StudyError(
          onRetry: () => ref.invalidate(deliveryTaskBundleProvider(widget.taskId)),
        ),
        data: (bundle) {
          if (bundle == null) {
            return const StudyEmpty(message: 'Không tìm thấy nhiệm vụ giao hộ này.');
          }

          final task = bundle.task;
          final apps = bundle.applications;

          final isSender = task.senderId == currentUserId;
          final isCourier = task.assignedCourierId == currentUserId;
          final isReceiver = task.finalReceiverId == currentUserId;
          final isParticipant = isSender || isCourier || isReceiver;

          final myApp = apps.where((a) => a.applicantId == currentUserId).firstOrNull;
          final canWithdraw = myApp != null &&
              ((myApp.status == DeliveryApplicationStatus.pending &&
                      task.status == DeliveryTaskStatus.open) ||
                  (myApp.status == DeliveryApplicationStatus.accepted &&
                      task.status == DeliveryTaskStatus.assigned));

          final statusColor = deliveryStatusColor(task.status);
          final statusLabel = deliveryStatusLabelVi(task.status);

          final pickupDesc = bundle.pickupDescription ?? 'Được hiển thị sau khi được duyệt';
          final dropoffDesc = bundle.dropoffDescription ?? 'Được hiển thị sau khi được duyệt';
          final canSeeAddress = bundle.pickupDescription != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                                'Trạng thái nhiệm vụ',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
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
                          task.assignedCourierId ?? 'Chưa phân công',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

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
                          subtitle: Text(pickupDesc),
                          trailing: canSeeAddress
                              ? IconButton(
                                  icon: const Icon(Icons.directions, color: Colors.blue),
                                  onPressed: () => _showDirectionsDialog('Điểm lấy', pickupDesc),
                                )
                              : null,
                        ),
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(Icons.arrow_downward, color: Colors.white),
                          ),
                          title: const Text('Điểm giao (Dropoff)'),
                          subtitle: Text(dropoffDesc),
                          trailing: canSeeAddress
                              ? IconButton(
                                  icon: const Icon(Icons.directions, color: Colors.green),
                                  onPressed: () => _showDirectionsDialog('Điểm giao', dropoffDesc),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

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
                          subtitle: task.status == DeliveryTaskStatus.open ||
                                  task.status == DeliveryTaskStatus.assigned
                              ? 'Chờ bàn giao sách cho C'
                              : 'Đã hoàn thành chặng 1',
                          isDone: task.status != DeliveryTaskStatus.open &&
                              task.status != DeliveryTaskStatus.assigned,
                          canPrepare: isSender &&
                              task.status == DeliveryTaskStatus.assigned &&
                              task.assignedCourierId != null,
                          onPrepare: () => _handleStartHandoverLeg(
                            transactionId: task.transactionId,
                            toUserId: task.assignedCourierId!,
                          ),
                          canReceive: isCourier && task.status == DeliveryTaskStatus.assigned,
                          onReceive: () => context.push(AppRoutes.receiverAck('handover-delivery-h1')),
                        ),
                        const Divider(),
                        _buildLegTile(
                          title: 'Chặng 2 (H2): Courier C → Người nhận B',
                          subtitle: task.status == DeliveryTaskStatus.completed
                              ? 'Đã giao thành công'
                              : 'Chờ giao cho người nhận cuối',
                          isDone: task.status == DeliveryTaskStatus.completed,
                          canPrepare: isCourier && task.status == DeliveryTaskStatus.pickedUp,
                          onPrepare: () => _handleStartHandoverLeg(
                            transactionId: task.transactionId,
                            toUserId: task.finalReceiverId,
                          ),
                          canReceive: isReceiver &&
                              task.status == DeliveryTaskStatus.deliveryPendingConfirmation,
                          onReceive: () => context.push(AppRoutes.receiverAck('handover-delivery-h2')),
                        ),
                        if (task.status == DeliveryTaskStatus.failed &&
                            bundle.returnHandoverId != null) ...[
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              backgroundColor: Colors.red,
                              child: Icon(Icons.assignment_return, color: Colors.white),
                            ),
                            title: const Text('Chặng hoàn trả (Giao thất bại)'),
                            subtitle: const Text('C phải bàn giao trả lại cho người gửi'),
                            trailing: isCourier
                                ? FilledButton(
                                    onPressed: () => context.push(
                                      AppRoutes.prepareHandover(bundle.returnHandoverId!),
                                    ),
                                    child: const Text('Trả sách'),
                                  )
                                : (isSender
                                    ? FilledButton(
                                        onPressed: () => context.push(
                                          AppRoutes.receiverAck(bundle.returnHandoverId!),
                                        ),
                                        child: const Text('Nhận lại'),
                                      )
                                    : null),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (apps.isEmpty && task.status == DeliveryTaskStatus.open)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Chưa có sinh viên nào ứng tuyển nhiệm vụ này.'),
                    ),
                  )
                else if (apps.isNotEmpty)
                  Card(
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
                              trailing: (isSender &&
                                      task.status == DeliveryTaskStatus.open &&
                                      app.status == DeliveryApplicationStatus.pending)
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
                  ),
                const SizedBox(height: 16),

                if (task.status == DeliveryTaskStatus.completed && (isSender || isReceiver)) ...[
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
                                onPressed: _isActionInProgress ? null : _handleRateCourier,
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

                if (task.status == DeliveryTaskStatus.open && !isParticipant && myApp == null) ...[
                  FilledButton.icon(
                    onPressed: _isActionInProgress ? null : _handleApply,
                    icon: const Icon(Icons.how_to_reg),
                    label: const Text('Ứng tuyển nhận nhiệm vụ giao hộ này'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],

                if (canWithdraw) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _isActionInProgress ? null : _handleWithdraw,
                    icon: const Icon(Icons.cancel_outlined, color: Colors.orange),
                    label: const Text('Rút đơn giao hộ', style: TextStyle(color: Colors.orange)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.orange),
                    ),
                  ),
                ],

                if (isCourier &&
                    (task.status == DeliveryTaskStatus.pickedUp ||
                        task.status == DeliveryTaskStatus.deliveryPendingConfirmation)) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _isActionInProgress ? null : _handleFailDelivery,
                    icon: const Icon(Icons.report_off, color: Colors.red),
                    label: const Text('Báo giao thất bại (Trả sách lại)',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red),
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
    required bool isDone,
    required bool canPrepare,
    required VoidCallback onPrepare,
    required bool canReceive,
    required VoidCallback onReceive,
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
              onPressed: _isActionInProgress ? null : onPrepare,
              child: const Text('Bàn giao'),
            ),
          if (canReceive)
            FilledButton(
              onPressed: _isActionInProgress ? null : onReceive,
              child: const Text('Xác nhận nhận'),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/mock/mock_fixtures.dart';
import '../providers/delivery_providers.dart';

/// SCR-16 – Tạo nhiệm vụ giao hộ (UI-10 + UI-12). Phụ trách: Vũ Hải Đăng.
/// Lập nhiệm vụ giao hộ mới liên kết với Transaction hiện hành.
class CreateDeliveryPage extends ConsumerStatefulWidget {
  const CreateDeliveryPage({
    super.key,
    required this.transactionId,
  });

  final String transactionId;

  @override
  ConsumerState<CreateDeliveryPage> createState() => _CreateDeliveryPageState();
}

class _CreateDeliveryPageState extends ConsumerState<CreateDeliveryPage> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isDirectHandover = false; // false = Giao hộ, true = Giao trực tiếp
  bool _attachGps = false;
  String? _gpsCoords;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _handleToggleGps(bool value) {
    setState(() {
      _attachGps = value;
      if (value) {
        // Tọa độ mẫu mô phỏng khuôn viên trường Đại học Thủy Lợi theo MVP-D07
        _gpsCoords = '21.0074° N, 105.8239° E (Đại học Thủy Lợi)';
      } else {
        _gpsCoords = null;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final repo = ref.read(deliveryRepositoryProvider);
    final idempotencyKey = 'create-delivery-${widget.transactionId}-${DateTime.now().millisecondsSinceEpoch}';

    final result = await repo.createTask(
      CreateDeliveryTaskInput(
        transactionId: widget.transactionId,
        finalReceiverId: MockFixtures.userB,
      ),
      idempotencyKey: idempotencyKey,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    switch (result) {
      case CommandOk(:final data):
        refreshDeliveries(ref, taskId: data.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã tạo nhiệm vụ giao hộ thành công: ${data.id}'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo nhiệm vụ giao hộ'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thông tin giao dịch liên kết
              Card(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Liên kết giao dịch: ${widget.transactionId}',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Lựa chọn phương thức bàn giao (UI-10: Giao trực tiếp hoặc Giao hộ)
              Text(
                'Hình thức giao nhận tài liệu',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Giao hộ (Courier)'),
                    icon: Icon(Icons.delivery_dining),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Giao trực tiếp'),
                    icon: Icon(Icons.people_outline),
                  ),
                ],
                selected: {_isDirectHandover},
                onSelectionChanged: (newSelection) {
                  setState(() => _isDirectHandover = newSelection.first);
                },
              ),
              const SizedBox(height: 16),

              if (_isDirectHandover) ...[
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.handshake_outlined, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Quy trình giao nhận trực tiếp', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Hai bạn sẽ hẹn gặp mặt trực tiếp để bàn giao tài liệu. Người giao sẽ chụp ít nhất 1 ảnh minh chứng và đối chiếu QR.',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            context.push(AppRoutes.prepareHandover('handover-borrow-01'));
                          },
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Bắt đầu chuẩn bị bàn giao trực tiếp'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Điểm hẹn lấy tài liệu (Bắt buộc)
              TextFormField(
                controller: _pickupController,
                decoration: const InputDecoration(
                  labelText: 'Điểm lấy tài liệu (Pickup) *',
                  hintText: 'VD: Cổng chính Đại học Thủy Lợi, 175 Tây Sơn',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập địa điểm lấy tài liệu cụ thể.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Điểm hẹn giao tài liệu (Bắt buộc)
              TextFormField(
                controller: _dropoffController,
                decoration: const InputDecoration(
                  labelText: 'Điểm giao tài liệu (Dropoff) *',
                  hintText: 'VD: Ký túc xá K1, phòng 402',
                  prefixIcon: Icon(Icons.flag_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập địa điểm giao tài liệu cụ thể.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Tùy chọn GPS tọa độ
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Đính kèm tọa độ GPS hiện tại'),
                subtitle: Text(
                  _gpsCoords ?? 'Hỗ trợ người giao hộ định vị chính xác điểm hẹn',
                  style: TextStyle(
                    color: _attachGps ? theme.colorScheme.primary : Colors.grey,
                    fontSize: 13,
                  ),
                ),
                value: _attachGps,
                onChanged: _handleToggleGps,
              ),
              const SizedBox(height: 16),

              // Ghi chú thêm
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú cho người giao hộ (Tùy chọn)',
                  hintText: 'Thời gian có thể gặp, số điện thoại liên hệ nhanh...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Nút Submit
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _handleSubmit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_task),
                label: Text(_isSubmitting ? 'Đang tạo nhiệm vụ...' : 'Tạo nhiệm vụ giao hộ'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

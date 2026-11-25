import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/models/handover.dart';
import '../../../design_system/widgets/study_empty.dart';
import '../../../design_system/widgets/study_error.dart';
import '../../../design_system/widgets/study_loading.dart';
import '../domain/handover_labels.dart';
import '../providers/handover_providers.dart';

/// SCR-18 – Chuẩn bị Handover (UI-13). Phụ trách: Vũ Hải Đăng.
/// Người giao (Giver) xem thông tin, chụp ít nhất 1 ảnh minh chứng,
/// đối chiếu QR và gửi minh chứng lên server.
class PrepareHandoverPage extends ConsumerStatefulWidget {
  const PrepareHandoverPage({
    super.key,
    required this.handoverId,
  });

  final String handoverId;

  @override
  ConsumerState<PrepareHandoverPage> createState() => _PrepareHandoverPageState();
}

class _PrepareHandoverPageState extends ConsumerState<PrepareHandoverPage> {
  final List<String> _localEvidencePhotos = [];
  bool _isQrVerified = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  void _handleTakePhoto() {
    // Mô phỏng chụp ảnh bằng camera của thiết bị
    setState(() {
      _localEvidencePhotos.add('evidence-photo-${_localEvidencePhotos.length + 1}.jpg');
      _errorMessage = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã chụp ảnh minh chứng ${_localEvidencePhotos.length} thành công!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleRemovePhoto(int index) {
    setState(() {
      _localEvidencePhotos.removeAt(index);
    });
  }

  Future<void> _handleOpenQrScanner() async {
    final result = await context.push<bool>(AppRoutes.scanQr(widget.handoverId));
    if (result == true) {
      setState(() {
        _isQrVerified = true;
      });
    }
  }

  Future<void> _handleSubmitEvidence(Handover handover) async {
    if (_localEvidencePhotos.isEmpty) {
      setState(() {
        _errorMessage = 'Bất biến INV-04: Bắt buộc phải chụp ít nhất 1 ảnh minh chứng trước khi giao sách.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final repo = ref.read(handoverRepositoryProvider);
    final idempotencyKey = 'evidence-${widget.handoverId}-${DateTime.now().millisecondsSinceEpoch}';

    final result = await repo.submitEvidence(
      SubmitHandoverEvidenceInput(
        handoverId: widget.handoverId,
        uploadedEvidenceIds: _localEvidencePhotos,
      ),
      idempotencyKey: idempotencyKey,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    switch (result) {
      case CommandOk():
        refreshHandover(ref, widget.handoverId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã nộp minh chứng bàn giao thành công! Chờ người nhận xác nhận.'),
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
    final handoverAsync = ref.watch(handoverDetailsProvider(widget.handoverId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chuẩn bị bàn giao'),
      ),
      body: handoverAsync.when(
        loading: () => const StudyLoading(),
        error: (err, stack) => StudyError(
          onRetry: () => ref.invalidate(handoverDetailsProvider(widget.handoverId)),
        ),
        data: (handover) {
          if (handover == null) {
            return const StudyEmpty(message: 'Không tìm thấy lượt bàn giao này.');
          }

          final statusColor = handoverStatusColor(handover.status);
          final statusLabel = handoverStatusLabelVi(handover.status);

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
                                'Lượt bàn giao: ${handover.id}',
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
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Phần 1: Chụp ảnh minh chứng tình trạng sách (Bắt buộc >= 1 ảnh)
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
                                '1. Ảnh minh chứng bàn giao *',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              '${_localEvidencePhotos.length} ảnh (Tối thiểu 1)',
                              style: TextStyle(
                                color: _localEvidencePhotos.isEmpty ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Người giao bắt buộc phải chụp ảnh tình trạng sách thực tế ngay tại thời điểm giao.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),

                        // Grid ảnh đã chụp
                        if (_localEvidencePhotos.isNotEmpty) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var i = 0; i < _localEvidencePhotos.length; i++)
                                Stack(
                                  children: [
                                    Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade400),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.image, size: 36, color: Colors.grey),
                                          Text('Ảnh ${i + 1}', style: const TextStyle(fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: GestureDetector(
                                        onTap: () => _handleRemovePhoto(i),
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(2),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],

                        OutlinedButton.icon(
                          onPressed: _handleTakePhoto,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Chụp thêm ảnh minh chứng'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Phần 2: Đối chiếu mã QR tài liệu (SCR-19)
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '2. Đối chiếu mã QR tài liệu',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Quét mã QR dán trên bản sách vật lý để đối chiếu chính xác tài liệu.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: _isQrVerified ? Colors.green.shade100 : Colors.blue.shade100,
                            child: Icon(
                              _isQrVerified ? Icons.check_circle : Icons.qr_code_scanner,
                              color: _isQrVerified ? Colors.green : Colors.blue,
                            ),
                          ),
                          title: Text(
                            _isQrVerified ? 'Đã đối chiếu mã QR thành công' : 'Chưa đối chiếu mã QR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isQrVerified ? Colors.green : Colors.black87,
                            ),
                          ),
                          subtitle: Text(_isQrVerified ? 'Mã khớp với giao dịch.' : 'Bấm để mở máy ảnh quét QR.'),
                          trailing: FilledButton.tonal(
                            onPressed: _handleOpenQrScanner,
                            child: Text(_isQrVerified ? 'Quét lại' : 'Quét mã'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Nút hoàn tất nộp minh chứng
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : () => _handleSubmitEvidence(handover),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(_isSubmitting ? 'Đang tải lên...' : 'Nộp minh chứng & Chờ xác nhận'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
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

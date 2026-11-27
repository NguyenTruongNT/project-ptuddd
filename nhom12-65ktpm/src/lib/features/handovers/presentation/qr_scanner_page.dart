import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contracts/command_result.dart';
import '../../../app/app_routes.dart';
import '../../../core/auth/auth_session_providers.dart';
import '../../../core/errors/app_error.dart';
import '../../transactions/domain/idempotency_key.dart';
import '../providers/handover_providers.dart';

/// SCR-19 – Quét QR (UI-13). Phụ trách: Vũ Hải Đăng.
/// Đối chiếu QR của bản sách vật lý, không nhận ID lượt bàn giao thay token.
/// BẤT BIẾN INV-05: QR sai mã là HARD BLOCK, cấm vượt qua thủ công!
class QrScannerPage extends ConsumerStatefulWidget {
  const QrScannerPage({super.key, required this.handoverId});

  final String handoverId;

  @override
  ConsumerState<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends ConsumerState<QrScannerPage> {
  final _manualCodeController = TextEditingController();
  final _fallbackReasonController = TextEditingController();

  bool _isFlashOn = false;
  bool _isVerifying = false;
  String? _verificationSuccessMessage;
  String? _mismatchErrorMessage;
  bool _showFallbackForm = false;
  bool _hasMismatch = false;
  String? _lastCode, _verificationKey, _lastReason, _fallbackKey;

  @override
  void dispose() {
    _manualCodeController.dispose();
    _fallbackReasonController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isVerifying = true;
      _verificationSuccessMessage = null;
      _mismatchErrorMessage = null;
    });

    final repo = ref.read(handoverRepositoryProvider);
    // Key không được chứa payload QR; retry cùng chuỗi giữ nguyên key để
    // server không ghi trùng Event sau mất ACK.
    if (_lastCode != trimmed) {
      _lastCode = trimmed;
      _verificationKey = newIdempotencyKey();
    }
    final idempotencyKey = _verificationKey!;

    final result = await repo.verifyMaterialCode(
      widget.handoverId,
      trimmed,
      idempotencyKey: idempotencyKey,
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    switch (result) {
      case CommandOk():
        setState(() {
          _verificationSuccessMessage = 'Đã đối chiếu đúng QR tài liệu.';
          _mismatchErrorMessage = null;
          _hasMismatch = false;
        });
      case CommandError(:final safeMessage, :final code):
        // BẤT BIẾN: QR Mismatch là hard block
        setState(() {
          _mismatchErrorMessage = safeMessage;
          _verificationSuccessMessage = null;
          _hasMismatch = _hasMismatch || code == DomainErrorCode.qrMismatch;
        });
    }
    ref.invalidate(handoverDetailsProvider(widget.handoverId));
  }

  void _handleConfirmSuccess() {
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final demo = ref.watch(sessionBoundaryProvider) == 'demo';
    final serverBlocked =
        ref
            .watch(handoverDetailsProvider(widget.handoverId))
            .asData
            ?.value
            ?.qrMismatchBlocked ??
        false;
    final blocked = _hasMismatch || serverBlocked;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.prepareHandover(widget.handoverId));
            }
          },
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Quét mã QR tài liệu'),
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: !demo
                ? null
                : () {
                    setState(() => _isFlashOn = !_isFlashOn);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _isFlashOn ? 'Đã bật đèn Flash' : 'Đã tắt đèn Flash',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          // Khung ngắm Camera Scanner Viewfinder
          Expanded(
            flex: 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Nền camera mô phỏng
                Container(
                  color: Colors.black87,
                  width: double.infinity,
                  height: double.infinity,
                  child: Center(
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: 80,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ),

                // Khung ngắm quét mã QR với 4 góc viền
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _mismatchErrorMessage != null
                          ? Colors.red
                          : (_verificationSuccessMessage != null
                                ? Colors.green
                                : Colors.white),
                      width: 2.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      _isVerifying
                          ? 'Đang đối chiếu mã...'
                          : 'Đưa mã QR tài liệu\nvào giữa khung ngắm',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Vùng điều khiển & thông báo kết quả
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Thông báo thành công
                    if (_verificationSuccessMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _verificationSuccessMessage!,
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _handleConfirmSuccess,
                        child: const Text('Xác nhận mã và Tiếp tục'),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Thông báo QR_MISMATCH (Hard block)
                    if (_mismatchErrorMessage != null || blocked) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.shade400,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.dangerous, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    blocked
                                        ? 'CẢNH BÁO: QR_MISMATCH'
                                        : 'Chưa đối chiếu được',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _mismatchErrorMessage ?? 'Mã đã đọc không khớp tài liệu. Hãy quét lại đúng mã để tiếp tục.',
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 6),
                            if (blocked)
                              const Text(
                                'Quy tắc bất biến: Không cho phép bỏ qua mã sai. Vui lòng kiểm tra lại đúng cuốn sách!',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Chip fixture chỉ hiện trong demo; không đưa ID mẫu vào
                    // giao diện đang dùng JWT thật rồi giả làm mã vật lý.
                    if (demo) ...[
                      Text(
                        'Thử nghiệm quét mã (Mô phỏng camera):',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            avatar: const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.green,
                            ),
                            label: const Text('Mã đúng: mat-borrow-01'),
                            onPressed: () => _handleVerifyCode('mat-borrow-01'),
                          ),
                          ActionChip(
                            avatar: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.red,
                            ),
                            label: const Text('Mã sai: mat-wrong-isbn'),
                            onPressed: () =>
                                _handleVerifyCode('mat-wrong-isbn'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _manualCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Nhập chuỗi mã QR thủ công',
                              hintText: 'studyshare:material:1:…',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _isVerifying
                              ? null
                              : () => _handleVerifyCode(
                                  _manualCodeController.text,
                                ),
                          child: const Text('Kiểm tra'),
                        ),
                      ],
                    ),
                    const Divider(height: 32),

                    // Fallback chỉ khi QR mờ / không đọc được
                    TextButton.icon(
                      onPressed: blocked
                          ? null
                          : () {
                              setState(
                                () => _showFallbackForm = !_showFallbackForm,
                              );
                            },
                      icon: Icon(
                        _showFallbackForm
                            ? Icons.expand_less
                            : Icons.help_outline,
                      ),
                      label: const Text('Mã QR bị mờ/rách không quét được?'),
                    ),

                    if (_showFallbackForm && !blocked) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nhập lý do đối chiếu thủ công (Chỉ dùng khi mã hỏng):',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _fallbackReasonController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                hintText: 'VD: Mã QR trên bìa sau bị xước mờ không thể đọc camera.',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonal(
                              onPressed: _isVerifying
                                  ? null
                                  : () async {
                                      final reason = _fallbackReasonController
                                          .text
                                          .trim();
                                      if (_lastReason != reason) {
                                        _lastReason = reason;
                                        _fallbackKey = newIdempotencyKey();
                                      }
                                      if (reason.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Vui lòng nhập lý do giải trình cụ thể.',
                                                ),
                                              ),
                                            );
                                        return;
                                      }
                                      setState(() => _isVerifying = true);
                                      final repo = ref.read(
                                        handoverRepositoryProvider,
                                      );
                                      final res = await repo.verifyWithFallback(
                                        widget.handoverId,
                                        reason,
                                        idempotencyKey: _fallbackKey!,
                                      );
                                      if (!context.mounted) return;
                                      setState(() => _isVerifying = false);
                                      switch (res) {
                                        case CommandOk():
                                          context.pop(true);
                                        case CommandError(
                                          :final safeMessage,
                                          :final code,
                                        ):
                                          if (code ==
                                              DomainErrorCode.qrMismatch) {
                                            setState(() => _hasMismatch = true);
                                          }
                                          ref.invalidate(
                                            handoverDetailsProvider(
                                              widget.handoverId,
                                            ),
                                          );
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                SnackBar(
                                                  content: Text(safeMessage),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                      }
                                    },
                              child: const Text(
                                'Xác nhận dùng đối chiếu thủ công',
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
          ),
        ],
      ),
    );
  }
}

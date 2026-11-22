import 'package:flutter/material.dart';

// Không hiển thị trực tiếp lỗi kỹ thuật/chi tiết server cho người dùng.
class StudyError extends StatelessWidget {
  const StudyError({
    super.key,
    this.message = 'Không tải được dữ liệu. Vui lòng thử lại.',
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ],
      ),
    );
  }
}

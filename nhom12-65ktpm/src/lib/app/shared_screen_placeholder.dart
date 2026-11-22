import 'package:flutter/material.dart';

// Trang tạm dành cho những màn hình CHƯA được thành viên triển khai.
// Không chứa nút giả lập duyệt, thanh toán, xác nhận QR hay đổi trạng thái.
class SharedScreenPlaceholder extends StatelessWidget {
  const SharedScreenPlaceholder({
    super.key,
    required this.code,
    required this.title,
    this.recordId,
  });

  final String code;
  final String title;
  final String? recordId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_outlined, size: 48),
              const SizedBox(height: 12),
              Text(code, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text(
                'Đây là màn hình mẫu để kiểm tra điều hướng. '
                'Chức năng nghiệp vụ chưa được triển khai.',
                textAlign: TextAlign.center,
              ),
              if (recordId != null) ...[
                const SizedBox(height: 12),
                Text('ID thử nghiệm: $recordId'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

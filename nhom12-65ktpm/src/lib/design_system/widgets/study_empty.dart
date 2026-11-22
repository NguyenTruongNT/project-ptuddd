import 'package:flutter/material.dart';

// Hiển thị khi API trả về danh sách rỗng, KHÔNG phải lỗi.
class StudyEmpty extends StatelessWidget {
  const StudyEmpty({super.key, this.message = 'Chưa có dữ liệu.'});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 40),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

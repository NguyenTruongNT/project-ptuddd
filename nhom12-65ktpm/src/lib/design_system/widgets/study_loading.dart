import 'package:flutter/material.dart';

// Hiển thị khi đang chờ dữ liệu từ repository.
class StudyLoading extends StatelessWidget {
  const StudyLoading({super.key, this.message = 'Đang tải dữ liệu...'});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(message),
        ],
      ),
    );
  }
}

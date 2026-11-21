import 'package:flutter/material.dart';

/// Các tab này chỉ là màn hình tạm để kiểm thử navigation.
/// Không tạo dữ liệu Material, Request hay Transaction.
class TabContent extends StatelessWidget {
  const TabContent({
    super.key,
    required this.title,
    required this.icon,
  });

  final String title;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_rounded, size: 52),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Giao diện tạm – chưa kết nối nghiệp vụ'),
        ],
      ),
    );
  }
}

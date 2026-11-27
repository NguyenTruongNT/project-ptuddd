import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Khung màn con: luôn có đường quay về, kể cả khi mở bằng deep link.
/// Form có dữ liệu chưa lưu dùng PopScope riêng trước khi rời màn.
class FeatureScaffold extends StatelessWidget {
  const FeatureScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.fallbackLocation,
    this.actions,
  });
  final String title;
  final Widget body;
  final String fallbackLocation;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    void back() {
      if (router.canPop()) {
        router.pop();
      } else {
        // Không push thêm màn cha gây vòng lặp khi mở đường dẫn trực tiếp.
        router.go(fallbackLocation);
      }
    }

    return PopScope(
      canPop: router.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: back),
          title: Text(title),
          actions: actions,
        ),
        body: SafeArea(child: body),
      ),
    );
  }
}

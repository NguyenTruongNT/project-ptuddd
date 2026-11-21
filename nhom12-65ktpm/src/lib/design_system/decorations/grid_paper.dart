import 'package:flutter/material.dart';

/// Hoa văn chỉ dành cho các màn khám phá/trang chủ, không dùng ở camera.
class GridPaperPainter extends CustomPainter {
  const GridPaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x260FA241)
      ..strokeWidth = 0.5;
    const cell = 24.0;
    for (double x = 0; x < size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPaperPainter oldDelegate) => false;
}

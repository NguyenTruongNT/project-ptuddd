import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lớp trang trí, không nhận thao tác chạm và chỉ gắn ở Home.
/// Không dùng tại QR scanner, evidence, form hay xác nhận giao nhận.
class LeafFallOverlay extends StatefulWidget {
  const LeafFallOverlay({super.key});

  @override
  State<LeafFallOverlay> createState() => _LeafFallOverlayState();
}

class _LeafFallOverlayState extends State<LeafFallOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _LeafPainter(progress: animation.value),
        );
      },
    );
  }
}

class _LeafPainter extends CustomPainter {
  const _LeafPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0x770FA241),
      Color(0x77B5C94D),
      Color(0x6617411B),
      Color(0x66CBD873),
    ];
    for (var i = 0; i < 4; i++) {
      final fall = (progress + i * 0.27) % 1.0;
      final x = size.width * (0.14 + i * 0.23) +
          math.sin(fall * math.pi * 2 + i) * 22;
      final y = (size.height + 60) * fall - 30;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(fall * 2 * math.pi + i);
      final paint = Paint()..color = colors[i];
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 9, height: 17),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _LeafPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

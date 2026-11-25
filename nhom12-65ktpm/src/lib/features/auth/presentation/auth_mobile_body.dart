
import 'package:flutter/material.dart';

/// Giao diện chung cho màn hình Đăng nhập và Đăng ký.
///
/// Chỉ thay đổi header thương hiệu.
/// Không tác động đến logic xác thực hay các form.
class AuthMobileBody extends StatelessWidget {
  const AuthMobileBody({
    super.key,
    required this.form,
    required this.showMessage,
    this.compact = false,
  });

  final Widget form;
  final bool showMessage;
  final bool compact;

  // Màu xanh gần với nền logo_dark_original.png.
  // Dùng màu nền đồng nhất để hạn chế viền quanh ảnh.
  static const Color _logoBackground = Color(0xFF01351A);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Thu gọn header khi bàn phím mở hoặc màn hình thấp.
    final compressed =
        compact ||
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        MediaQuery.sizeOf(context).height < 700 ||
        MediaQuery.textScalerOf(context).scale(16) > 22;

    // Màn đăng nhập được phép có header cao hơn.
    final expanded = showMessage && !compressed;

    final double headerHeight = compressed
        ? 164
        : expanded
            ? 220
            : 180;

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: CustomScrollView(
        keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          // HEADER STUDYSHARE
          SliverToBoxAdapter(
            child: SizedBox(
              height: headerHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Logo rộng gần một nửa header.
                  final logoWidth =
                      (constraints.maxWidth * 0.46)
                          .clamp(120.0, 210.0)
                          .toDouble();

                  return Stack(
                    children: [
                      // 1. Nền xanh đồng bộ với logo gốc.
                      const Positioned.fill(
                        child: ColoredBox(
                          color: _logoBackground,
                        ),
                      ),

                      // 2. GIỮ NGUYÊN họa tiết ban đầu:
                      // sách xếp chồng, dấu trang, vòng tròn.
                      const Positioned.fill(
                        child: ExcludeSemantics(
                          child: IgnorePointer(
                            child: ClipRect(
                              child: CustomPaint(
                                painter: _BookPattern(),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 3. Logo xanh StudyShare ở bên trái.
                      // Không thêm logo trắng hoặc tagline.
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            24,
                            8,
                            20,
                            28,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Image.asset(
                              'assets/branding/logo_dark_original.png',
                              width: logoWidth,
                              fit: BoxFit.contain,
                              alignment: Alignment.centerLeft,
                              filterQuality: FilterQuality.high,
                              semanticLabel: 'StudyShare',
                            ),
                          ),
                        ),
                      ),

                      // 4. Giữ nguyên mép bo tròn phía dưới.
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 28,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius:
                                const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // FORM ĐĂNG NHẬP / ĐĂNG KÝ
          // Giữ nguyên cấu trúc ban đầu.
          SliverToBoxAdapter(
            child: ColoredBox(
              color: theme.colorScheme.surface,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Theme(
                    data: theme.copyWith(
                      cardTheme: theme.cardTheme.copyWith(
                        shape: const RoundedRectangleBorder(),
                        elevation: 0,
                        margin: EdgeInsets.zero,
                      ),
                    ),
                    child: form,
                  ),
                ),
              ),
            ),
          ),

          // Họa tiết ô vở ở vùng trống dưới form.
          SliverFillRemaining(
            hasScrollBody: false,
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _NotebookPattern(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Họa tiết ô vở phía dưới form.
/// Giữ nguyên từ phiên bản ban đầu.
class _NotebookPattern extends CustomPainter {
  const _NotebookPattern(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color.withValues(alpha: .045)
      ..strokeWidth = .7;

    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        line,
      );
    }

    for (var y = 0.0; y < size.height; y += 24) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _NotebookPattern oldDelegate,
  ) =>
      color != oldDelegate.color;
}

/// HỌA TIẾT GỐC CỦA HEADER.
///
/// Giữ nguyên sách xếp chồng bên phải,
/// hai vòng tròn và dấu trang xanh.
/// Không thay bằng biểu tượng sách mới.
class _BookPattern extends CustomPainter {
  const _BookPattern();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: .09);

    // Hai vòng tròn trang trí gốc.
    canvas.drawCircle(
      Offset(size.width - 26, 106),
      90,
      line,
    );

    canvas.drawCircle(
      Offset(size.width - 26, 106),
      114,
      line,
    );

    canvas.save();
    canvas.translate(size.width - 94, 112);
    canvas.rotate(-.16);

    // Ba lớp sách xếp chồng gốc.
    final cover = Paint()
      ..color = Colors.white.withValues(alpha: .09);

    for (final offset in [
      const Offset(20, -16),
      const Offset(10, -8),
      Offset.zero,
    ]) {
      final rect = Rect.fromLTWH(
        offset.dx,
        offset.dy,
        92,
        112,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(8),
        ),
        cover,
      );

      canvas.drawLine(
        Offset(offset.dx + 12, offset.dy + 8),
        Offset(offset.dx + 12, offset.dy + 104),
        line,
      );
    }

    // Dấu trang xanh gốc.
    final bookmark = Path()
      ..moveTo(62, 0)
      ..lineTo(75, 0)
      ..lineTo(75, 33)
      ..lineTo(68.5, 27)
      ..lineTo(62, 33)
      ..close();

    canvas.drawPath(
      bookmark,
      Paint()
        ..color = const Color(0xFFECF665)
            .withValues(alpha: .3),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(
    covariant _BookPattern oldDelegate,
  ) =>
      false;
}

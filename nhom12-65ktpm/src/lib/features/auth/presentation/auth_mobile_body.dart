import 'package:flutter/material.dart';

import '../../../design_system/theme/studyshare_theme.dart';
import '../../../l10n/app_localizations.dart';

/// A branded header and a continuous form surface, with room for the keyboard.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = AppLocalizations.of(context)!;
    final compressed =
        compact ||
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        MediaQuery.sizeOf(context).height < 700 ||
        MediaQuery.textScalerOf(context).scale(16) > 22;
    final expanded = showMessage && !compressed;
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [StudyShareTheme.darkGreen, Color(0xFF0D3929)],
                      ),
                    ),
                  ),
                ),
                if (expanded)
                  const Positioned.fill(
                    child: ExcludeSemantics(
                      child: IgnorePointer(
                        child: CustomPaint(painter: _BookPattern()),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 44),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 72,
                            height: 54,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Image.asset(
                              'assets/branding/logo_light_original.png',
                              fit: BoxFit.contain,
                              semanticLabel: 'StudyShare',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              text.brandTagline,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: .88),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (expanded) ...[
                        const SizedBox(height: 20),
                        Text(
                          text.brandHeading,
                          key: const ValueKey('auth-mobile-headline'),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 32,
                            height: 1.12,
                            color: Colors.white,
                            letterSpacing: -.8,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        ],
      ),
    );
  }
}

/// Decorative books, not a replacement for the approved logo.
class _BookPattern extends CustomPainter {
  const _BookPattern();
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: .09);
    canvas.drawCircle(Offset(size.width - 26, 106), 90, line);
    canvas.drawCircle(Offset(size.width - 26, 106), 114, line);
    canvas.save();
    canvas.translate(size.width - 94, 112);
    canvas.rotate(-.16);
    final cover = Paint()..color = Colors.white.withValues(alpha: .09);
    for (final offset in [
      const Offset(20, -16),
      const Offset(10, -8),
      Offset.zero,
    ]) {
      final rect = Rect.fromLTWH(offset.dx, offset.dy, 92, 112);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        cover,
      );
      canvas.drawLine(
        Offset(offset.dx + 12, offset.dy + 8),
        Offset(offset.dx + 12, offset.dy + 104),
        line,
      );
    }
    final bookmark = Path()
      ..moveTo(62, 0)
      ..lineTo(75, 0)
      ..lineTo(75, 33)
      ..lineTo(68.5, 27)
      ..lineTo(62, 33)
      ..close();
    canvas.drawPath(
      bookmark,
      Paint()..color = StudyShareTheme.lime.withValues(alpha: .3),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BookPattern oldDelegate) => false;
}

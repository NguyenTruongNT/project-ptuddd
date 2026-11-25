import 'dart:async';

import 'package:flutter/material.dart';

/// App-level feedback survives navigation and never covers the whole hit area.
class StudyFeedbackHost extends StatefulWidget {
  const StudyFeedbackHost({super.key, required this.child});
  final Widget child;

  static StudyFeedbackHostState? of(BuildContext context) =>
      context.findAncestorStateOfType<StudyFeedbackHostState>();

  @override
  State<StudyFeedbackHost> createState() => StudyFeedbackHostState();
}

class StudyFeedbackHostState extends State<StudyFeedbackHost> {
  Timer? _timer;
  String? _message;
  bool _error = false;

  void show(String message, {bool error = false}) {
    if (!mounted) return;
    _timer?.cancel();
    setState(() {
      _message = message;
      _error = error;
    });
    _timer = Timer(const Duration(milliseconds: 3500), dismiss);
  }

  void dismiss() {
    _timer?.cancel();
    if (mounted) setState(() => _message = null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_message != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            right: 16,
            width: (MediaQuery.sizeOf(context).width - 32).clamp(0, 380),
            child: Semantics(
              liveRegion: true,
              child: Material(
                key: const ValueKey('study-toast'),
                elevation: 8,
                shadowColor: Colors.black26,
                color: _error ? scheme.errorContainer : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    top: 6,
                    bottom: 6,
                    right: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _error
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color: _error
                            ? scheme.onErrorContainer
                            : scheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: _error
                                ? scheme.onErrorContainer
                                : scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Semantics(
                        label: MaterialLocalizations.of(context)
                            .closeButtonTooltip,
                        button: true,
                        child: IconButton(
                          key: const ValueKey('toast-close'),
                          onPressed: dismiss,
                          icon: Icon(
                            Icons.close,
                            size: 20,
                            color: _error
                                ? scheme.onErrorContainer
                                : scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

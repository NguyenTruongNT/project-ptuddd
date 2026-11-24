import 'package:flutter/material.dart';

import '../../../design_system/theme/studyshare_theme.dart';
import '../../../l10n/app_localizations.dart';

class AuthPageLayout extends StatelessWidget {
  const AuthPageLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.formKey,
    required this.children,
    this.onBack,
  });
  final String title;
  final String subtitle;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final VoidCallback? onBack;

  Widget _brand(BuildContext context) => Row(
    children: [
      Container(
        width: 80,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Image.asset(
          'assets/branding/logo_light_original.png',
          fit: BoxFit.contain,
          semanticLabel: 'StudyShare',
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          AppLocalizations.of(context)!.brandTagline,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final form = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!wide) ...[_brand(context), const SizedBox(height: 24)],
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(wide ? 32 : 24),
                      child: AutofillGroup(
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (onBack != null) ...[
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: onBack,
                                    icon: const Icon(
                                      Icons.arrow_back,
                                      size: 20,
                                    ),
                                    label: Text(text.authBackToLogin),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Text(
                                title,
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                subtitle,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 28),
                              ...children,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 40 : 20,
                vertical: wide ? 48 : 24,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(right: 48),
                                padding: const EdgeInsets.all(40),
                                decoration: BoxDecoration(
                                  color: StudyShareTheme.darkGreen,
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 128,
                                      height: 96,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Image.asset(
                                        'assets/branding/logo_light_original.png',
                                        fit: BoxFit.contain,
                                        semanticLabel: 'StudyShare',
                                      ),
                                    ),
                                    const SizedBox(height: 48),
                                    Text(
                                      text.brandHeading,
                                      style: theme.textTheme.displaySmall
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            height: 1.2,
                                          ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      text.brandDescription,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(color: Colors.white),
                                    ),
                                    const SizedBox(height: 40),
                                    for (final item in [
                                      (
                                        Icons.menu_book_outlined,
                                        text.brandBooks,
                                      ),
                                      (Icons.swap_horiz, text.brandExchange),
                                      (
                                        Icons.people_outline,
                                        text.brandCommunity,
                                      ),
                                    ])
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 20,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              item.$1,
                                              color: StudyShareTheme.lime,
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Text(
                                                item.$2,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(child: form),
                          ],
                        )
                      : form,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AuthMessage extends StatelessWidget {
  const AuthMessage(this.message, {super.key, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: error ? scheme.errorContainer : scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              error ? Icons.error_outline : Icons.info_outline,
              size: 20,
              color: error
                  ? scheme.onErrorContainer
                  : scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: error
                      ? scheme.onErrorContainer
                      : scheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

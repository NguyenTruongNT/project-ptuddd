import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/auth_validation.dart';

String passwordRequirementLabel(
  PasswordRequirement rule,
  AppLocalizations text,
) => switch (rule) {
  PasswordRequirement.length => text.authPasswordHint(
    AuthValidation.minimumPasswordLength,
  ),
  PasswordRequirement.uppercase => text.authPasswordUppercase,
  PasswordRequirement.lowercase => text.authPasswordLowercase,
  PasswordRequirement.digit => text.authPasswordDigit,
  PasswordRequirement.symbol => text.authPasswordSymbol,
};

class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({
    super.key,
    required this.password,
    required this.focusNode,
    required this.showErrors,
  });
  final TextEditingController password;
  final FocusNode focusNode;
  final bool showErrors;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([password, focusNode]),
      builder: (context, _) {
        if (!focusNode.hasFocus && password.text.isEmpty && !showErrors) {
          return const SizedBox.shrink();
        }
        final missing = AuthValidation.missingPasswordRequirements(
          password.text,
        );
        return Padding(
          key: const ValueKey('auth-password-requirements'),
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final rule in PasswordRequirement.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        missing.contains(rule)
                            ? Icons.radio_button_unchecked
                            : Icons.check_circle,
                        size: 16,
                        color: missing.contains(rule)
                            ? showErrors
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          passwordRequirementLabel(rule, text),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

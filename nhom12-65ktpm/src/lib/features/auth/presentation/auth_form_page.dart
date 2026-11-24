import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../app/auth_redirect.dart';
import '../../../core/auth/auth_session_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/auth_validation.dart';
import 'auth_error_message.dart';

enum AuthFlow { signIn, signUp, forgotPassword, checkEmail, resetPassword }

class AuthFormPage extends ConsumerStatefulWidget {
  const AuthFormPage({
    super.key,
    required this.flow,
    this.returnTo,
    this.email,
    this.notice,
  });
  final AuthFlow flow;
  final String? returnTo;
  final String? email;
  final String? notice;
  @override
  ConsumerState<AuthFormPage> createState() => _AuthFormPageState();
}

class _AuthFormPageState extends ConsumerState<AuthFormPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _message;
  Timer? _cooldown;

  @override
  void initState() {
    super.initState();
    _email.text = widget.email ?? '';
  }

  @override
  void dispose() {
    _cooldown?.cancel();
    _email.dispose();
    _name.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  String _location(String path) => Uri(
    path: path,
    queryParameters: widget.returnTo == null
        ? null
        : {'from': safeAuthDestination(widget.returnTo)},
  ).toString();

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    final repository = ref.read(authRepositoryProvider);
    if (repository == null) return;
    final text = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      switch (widget.flow) {
        case AuthFlow.signIn:
          await repository.signIn(
            email: _email.text.trim(),
            password: _password.text,
          );
          if (mounted) context.go(safeAuthDestination(widget.returnTo));
        case AuthFlow.signUp:
          final outcome = await repository.register(
            displayName: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          );
          if (!mounted) return;
          if (outcome.needsEmailConfirmation) {
            context.go(
              _location(AppRoutes.checkEmail),
              extra: _email.text.trim(),
            );
          } else {
            context.go(safeAuthDestination(widget.returnTo));
          }
        case AuthFlow.forgotPassword:
          await repository.requestPasswordReset(_email.text.trim());
          if (mounted) {
            setState(() => _message = text.authResetSent);
            _startCooldown();
          }
        case AuthFlow.checkEmail:
          await repository.resendConfirmation(_email.text.trim());
          if (mounted) {
            setState(() => _message = text.authConfirmationSent);
            _startCooldown();
          }
        case AuthFlow.resetPassword:
          await repository.completePasswordRecovery(_password.text);
          if (mounted) context.go(AppRoutes.signIn, extra: 'password-updated');
      }
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error, text));
    } finally {
      // Giữ email khi lỗi; không giữ plaintext password sau submit.
      if (mounted) {
        _password.clear();
        _confirmation.clear();
        setState(() => _busy = false);
      }
    }
  }

  void _startCooldown() {
    _cooldown?.cancel();
    _cooldown = Timer(const Duration(minutes: 1), () {
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final snapshot = ref.watch(authSnapshotProvider).asData?.value;
    final configured = ref.watch(authRepositoryProvider) != null;
    final signUp = widget.flow == AuthFlow.signUp;
    final reset = widget.flow == AuthFlow.resetPassword;
    final hasPassword = signUp || reset || widget.flow == AuthFlow.signIn;
    final checkEmail = widget.flow == AuthFlow.checkEmail;
    final title = switch (widget.flow) {
      AuthFlow.signIn => text.authWelcome,
      AuthFlow.signUp => text.authSignUp,
      AuthFlow.forgotPassword => text.authResetTitle,
      AuthFlow.checkEmail => text.authCheckEmail,
      AuthFlow.resetPassword => text.authUpdateTitle,
    };
    final button = switch (widget.flow) {
      AuthFlow.signIn => text.authSignIn,
      AuthFlow.signUp => text.authSignUp,
      AuthFlow.forgotPassword => text.authSendReset,
      AuthFlow.checkEmail => text.authResend,
      AuthFlow.resetPassword => text.authUpdatePassword,
    };
    return Scaffold(
      appBar: widget.flow == AuthFlow.signIn
          ? null
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: text.authBackToLogin,
                onPressed: _busy
                    ? null
                    : () => context.go(_location(AppRoutes.signIn)),
              ),
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: AutofillGroup(
              child: Form(
                key: _form,
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Image.asset(
                      'assets/branding/logo_light_original.png',
                      height: 96,
                      semanticLabel: 'StudyShare',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    if (!configured) ...[
                      Text(
                        snapshot?.failed == true
                            ? text.authInitializationError
                            : text.authNotConfigured,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (widget.notice == 'password-updated')
                      Text(text.authPasswordUpdated),
                    if (checkEmail) ...[
                      Text(text.authCheckEmailHint),
                      const SizedBox(height: 16),
                    ],
                    if (signUp) ...[
                      TextFormField(
                        key: const ValueKey('auth-name'),
                        controller: _name,
                        enabled: !_busy,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        decoration: InputDecoration(
                          labelText: text.authDisplayName,
                        ),
                        validator: (v) => AuthValidation.validName(v ?? '')
                            ? null
                            : text.authInvalidName,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!reset) ...[
                      TextFormField(
                        key: const ValueKey('auth-email'),
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(labelText: text.authEmail),
                        validator: (v) => AuthValidation.validEmail(v ?? '')
                            ? null
                            : text.authInvalidEmail,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (hasPassword) ...[
                      TextFormField(
                        key: const ValueKey('auth-password'),
                        controller: _password,
                        enabled: !_busy,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: [
                          signUp || reset
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        decoration: InputDecoration(
                          labelText: text.authPassword,
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? text.authShowPassword
                                : text.authHidePassword,
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (v) => (v ?? '').isEmpty
                            ? text.authRequiredPassword
                            : (signUp || reset) &&
                                  !AuthValidation.validNewPassword(v!)
                            ? text.authWeakPassword
                            : null,
                        onFieldSubmitted: (_) {
                          if (!signUp && !reset) _submit();
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (signUp || reset) ...[
                      TextFormField(
                        key: const ValueKey('auth-confirmation'),
                        controller: _confirmation,
                        enabled: !_busy,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: text.authConfirmPassword,
                        ),
                        validator: (v) => v == _password.text
                            ? null
                            : text.authPasswordMismatch,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_message!),
                      ),
                    if (_cooldown?.isActive ?? false) Text(text.authCooldown),
                    FilledButton(
                      key: const ValueKey('auth-submit'),
                      onPressed:
                          !_busy &&
                              configured &&
                              !(_cooldown?.isActive ?? false)
                          ? _submit
                          : null,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(button),
                    ),
                    const SizedBox(height: 12),
                    if (widget.flow == AuthFlow.signIn) ...[
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => context.go(
                                _location(AppRoutes.forgotPassword),
                              ),
                        child: Text(text.authForgot),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => context.go(_location(AppRoutes.signUp)),
                        child: Text(text.authSignUp),
                      ),
                      if (!configured && snapshot?.failed != true)
                        TextButton(
                          onPressed: () {
                            ref.read(demoModeProvider.notifier).enable();
                            context.go(AppRoutes.home);
                          },
                          child: Text(text.authDemo),
                        ),
                    ] else
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => context.go(_location(AppRoutes.signIn)),
                        child: Text(text.authBackToLogin),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

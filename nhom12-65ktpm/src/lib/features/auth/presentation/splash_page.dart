import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_session_providers.dart';
import '../../../l10n/app_localizations.dart';

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF17411B),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/branding/logo_dark_original.png',
                height: 160,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                text.authSplash,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => ref.invalidate(authSnapshotProvider),
                child: Text(
                  text.authRetry,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

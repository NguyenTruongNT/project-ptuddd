import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../l10n/app_localizations.dart';

String authErrorMessage(Object error, AppLocalizations text) {
  if (error is RecoverySessionRequired) return text.authRecoveryExpired;
  if (error is SocialAuthUnavailable) return text.authSocialUnavailable;
  if (error is SocketException || error is TimeoutException) {
    return text.authNetworkError;
  }
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return text.authInvalidCredentials;
      case 'email_not_confirmed':
        return text.authEmailUnconfirmed;
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return text.authRateLimit;
      case 'weak_password':
        return text.authWeakPassword;
      case 'otp_expired':
      case 'session_not_found':
      case 'refresh_token_not_found':
        return text.authRecoveryExpired;
    }
  }
  // Không hiện message thô từ server: có thể chứa PII hoặc tiết lộ tài khoản.
  return text.authGenericError;
}

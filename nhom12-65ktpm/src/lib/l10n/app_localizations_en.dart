// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Explore';

  @override
  String get navPublish => 'Post';

  @override
  String get navTransactions => 'Transactions';

  @override
  String get navProfile => 'Profile';

  @override
  String get welcomeMessage =>
      'Welcome to StudyShare. Business features will be implemented in subsequent pull requests.';

  @override
  String get placeholderMessage =>
      'Foundation placeholder; no Supabase connection or transaction actions yet.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get themeLabel => 'Display mode';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get paletteLabel => 'Color palette';

  @override
  String get languageLabel => 'Language';

  @override
  String get gridLabel => 'Grid paper background';

  @override
  String get leavesLabel => 'Falling leaves';

  @override
  String get leavesHint => 'Home only; hidden when reduced motion is enabled.';

  @override
  String get sessionOnlyNotice =>
      'Prototype: choices are stored in memory only. Local persistence will be added in a later task.';

  @override
  String get authWelcome => 'Welcome back';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authDisplayName => 'Display name';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignUp => 'Create account';

  @override
  String get authForgot => 'Forgot password?';

  @override
  String get authResetTitle => 'Recover password';

  @override
  String get authSendReset => 'Send recovery email';

  @override
  String get authUpdateTitle => 'Set a new password';

  @override
  String get authUpdatePassword => 'Save new password';

  @override
  String get authBackToLogin => 'Back to sign in';

  @override
  String get authCheckEmail => 'Check your email';

  @override
  String get authCheckEmailHint =>
      'Open the verification link in your email to finish registration, then sign in.';

  @override
  String get authResend => 'Resend verification email';

  @override
  String get authCooldown => 'Please wait one minute before sending again.';

  @override
  String get authResetSent =>
      'If the email is eligible, recovery instructions have been sent. Please check your inbox.';

  @override
  String get authConfirmationSent =>
      'If verification is required, a verification email has been sent.';

  @override
  String get authPasswordUpdated => 'Password updated. Please sign in again.';

  @override
  String get authInvalidEmail => 'Enter a valid email address.';

  @override
  String get authRequiredPassword => 'Enter your password.';

  @override
  String get authWeakPassword =>
      'The password does not meet the server\'s security policy.';

  @override
  String get authPasswordMismatch => 'The passwords do not match.';

  @override
  String get authInvalidName =>
      'Display name must contain 1 to 100 characters.';

  @override
  String get authInvalidCredentials => 'Invalid email or password.';

  @override
  String get authEmailUnconfirmed => 'Verify your email before signing in.';

  @override
  String get authRateLimit => 'Too many attempts. Please try again later.';

  @override
  String get authNetworkError =>
      'Unable to connect. Check your network and try again.';

  @override
  String get authGenericError =>
      'Unable to complete this action. Please try again.';

  @override
  String get authRecoveryExpired =>
      'The recovery link is no longer valid. Request a new email.';

  @override
  String get authNotConfigured =>
      'Sign in is not available yet. You can explore the demo.';

  @override
  String get authInitializationError =>
      'Unable to initialize sign in. Please reopen the app.';

  @override
  String get authDemo => 'Explore demo';

  @override
  String get authDemoNotice => 'Demo: simulated data; no Supabase sign-in.';

  @override
  String get authExitDemo => 'Exit demo';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authSplash => 'Starting StudyShare…';

  @override
  String get authRetry => 'Retry';

  @override
  String get profileTitle => 'My profile';

  @override
  String get profileEdit => 'Edit display name';

  @override
  String get profileSave => 'Save changes';

  @override
  String get profileSaved => 'Profile saved.';

  @override
  String get profileLoadError =>
      'Unable to load your profile. Please try again.';

  @override
  String get profileMyMaterials => 'My materials';

  @override
  String get profileMyTransactions => 'My transactions';

  @override
  String get profileMyDeliveries => 'Deliveries';

  @override
  String get profileMyIssues => 'Issues';

  @override
  String get profileLogout => 'Sign out';

  @override
  String get profileLogoutConfirm => 'Sign out of this device?';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get preferencesSavedNotice =>
      'Appearance choices are saved on this device.';

  @override
  String get preferencesSaveError =>
      'Unable to save this choice. Please try again.';

  @override
  String get authLoginNeeded => 'Sign in to view your profile.';

  @override
  String get brandTagline => 'A community for sharing study materials';

  @override
  String get brandHeading => 'Share a book.\nStart a new chapter.';

  @override
  String get brandDescription =>
      'Connect with students, share your books and keep learning together.';

  @override
  String get brandBooks => 'Find the materials you need';

  @override
  String get brandExchange => 'Buy, give and borrow books';

  @override
  String get brandCommunity => 'Connect with fellow students';

  @override
  String get authSignInSubtitle => 'Sign in to continue your sharing journey.';

  @override
  String get authSignUpSubtitle =>
      'One account. More opportunities to learn together.';

  @override
  String get authResetSubtitle =>
      'Enter your account email to receive recovery instructions.';

  @override
  String get authNewPasswordSubtitle =>
      'Choose a new password to protect your account.';

  @override
  String get authCreateConfirm => 'Confirm account creation';

  @override
  String authCreateConfirmBody(String name, String email) {
    return 'Create an account as “$name” with email $email?';
  }

  @override
  String get authPasswordConfirm => 'Confirm password change';

  @override
  String get authPasswordConfirmBody =>
      'You will need to sign in again with your new password after saving.';

  @override
  String get authCreated => 'Account created successfully.';

  @override
  String get authSignedIn => 'Signed in successfully.';

  @override
  String authPasswordHint(int count) {
    return 'At least $count characters';
  }

  @override
  String get commonBack => 'Back';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonDiscardTitle => 'Discard unsaved changes?';

  @override
  String get commonDiscardBody => 'Your changes will not be saved.';

  @override
  String get commonDiscard => 'Discard changes';

  @override
  String get profileSubtitle => 'Manage your details and sharing activity.';

  @override
  String get profileActivity => 'My activity';

  @override
  String get profileAccount => 'Account';

  @override
  String get profileEditHint =>
      'This name is visible to the people you exchange with.';

  @override
  String get profileEmailHint => 'Sign-in email';

  @override
  String profileNameConfirm(String name) {
    return 'Change your display name to “$name”?';
  }

  @override
  String get settingsSubtitle => 'Make your study space feel like your own.';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceHint =>
      'Choose a display mode and your favorite color.';

  @override
  String get settingsEffects => 'Effects';

  @override
  String get gridHint => 'Show subtle grid lines on Home.';

  @override
  String get settingsDraftHint =>
      'Changes apply only after you choose Save changes.';

  @override
  String get preferencesSaved => 'Settings saved.';

  @override
  String get preferencesSaving => 'Saving…';

  @override
  String get preferencesAutoSaveHint =>
      'Changes apply instantly and save on this device.';

  @override
  String get preferencesSaveRestored =>
      'Unable to save your choice. Your last saved settings have been restored.';

  @override
  String get authJoinPrompt => 'New to StudyShare?';

  @override
  String get authContinueSharing => 'Continue your sharing journey.';

  @override
  String get settingsConfirm => 'Apply your new settings?';

  @override
  String get settingsConfirmBody =>
      'Save the selected appearance, language and effects on this device.';

  @override
  String get paletteGreen => 'Green';

  @override
  String get paletteBlue => 'Blue';

  @override
  String get palettePurple => 'Purple';

  @override
  String get paletteOrange => 'Orange';

  @override
  String get profileMaterialsHint => 'The books and materials you manage';

  @override
  String get profileTransactionsHint => 'Track purchases, gifts and loans';

  @override
  String get profileDeliveriesHint => 'Your material deliveries';

  @override
  String get profileIssuesHint => 'Keep track of reported problems';
}

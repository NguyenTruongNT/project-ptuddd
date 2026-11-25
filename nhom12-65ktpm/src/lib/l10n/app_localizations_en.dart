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
  String get authPasswordUppercase => 'Uppercase letter (A–Z)';

  @override
  String get authPasswordLowercase => 'Lowercase letter (a–z)';

  @override
  String get authPasswordDigit => 'Digit (0–9)';

  @override
  String get authPasswordSymbol => 'Special character (for example !@#)';

  @override
  String authPasswordNeeds(String requirements) {
    return 'Password still needs: $requirements.';
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
  String get authOAuthDivider => 'Or continue with';

  @override
  String get authContinueGoogle => 'Google';

  @override
  String get authContinueGithub => 'GitHub';

  @override
  String get authSocialDeveloping => 'This feature is under development.';

  @override
  String get authPasswordsMatch => 'Passwords match';

  @override
  String get authSocialUnavailable =>
      'This sign-in method is currently unavailable. Please try again later.';

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

  @override
  String get matTitle => 'My materials';

  @override
  String get matSubtitle => 'Every book has a story to share.';

  @override
  String get matAdd => 'Add material';

  @override
  String get matEdit => 'Edit';

  @override
  String get matDetails => 'Material details';

  @override
  String get matSearch => 'Search title or ISBN';

  @override
  String get matAll => 'All';

  @override
  String get matReady => 'Ready to list';

  @override
  String get matActive => 'In a transaction';

  @override
  String get matEmpty => 'Start with a book';

  @override
  String get matEmptyBody => 'Add a book you own and get ready to share it.';

  @override
  String get matNoResults => 'No matching materials.';

  @override
  String get matTryAgain => 'Try again';

  @override
  String get matLoadMore => 'Load more';

  @override
  String get matNotFound =>
      'This material is unavailable or you do not have access.';

  @override
  String get matNoImage => 'No photos yet';

  @override
  String get matNoImageHint =>
      'Add at least one photo before publishing a listing.';

  @override
  String get matHeldByYou => 'In your possession';

  @override
  String get matHeldOther => 'Held by another person';

  @override
  String get matReserved => 'Reserved';

  @override
  String get matUnlisted => 'Not listed';

  @override
  String get matPublished => 'Published';

  @override
  String get matDraftListing => 'Draft listing';

  @override
  String get matHiddenListing => 'Hidden listing';

  @override
  String get matReadyLabel => 'Ready to share';

  @override
  String get matLockedTransaction =>
      'An active transaction prevents editing this material and its photos.';

  @override
  String get matLockedListing =>
      'Hide the published listing before editing this material.';

  @override
  String get matLockedRequest =>
      'Resolve pending requests before editing this material.';

  @override
  String get matLockedHolder =>
      'Editing is available once the owner holds the material.';

  @override
  String get matSave => 'Save material';

  @override
  String get matSaveChanges => 'Save changes';

  @override
  String get matSaved => 'Material saved.';

  @override
  String get matConfirmCreate => 'Confirm new material';

  @override
  String get matConfirmEdit => 'Confirm changes';

  @override
  String get matConfirmBody =>
      'The following details and photo order will be saved:';

  @override
  String get matName => 'Title';

  @override
  String get matSubject => 'Subject / category';

  @override
  String get matCondition => 'Condition';

  @override
  String get matDescription => 'Description';

  @override
  String get matIsbn => 'ISBN (optional)';

  @override
  String get matRequired200 => 'Enter 1–200 valid characters.';

  @override
  String get matRequired100 => 'Enter 1–100 valid characters.';

  @override
  String get matDescriptionLimit => 'Use up to 2,000 valid characters.';

  @override
  String get matInvalidIsbn => 'Enter a valid ISBN-10 or ISBN-13.';

  @override
  String get matImages => 'Material photos';

  @override
  String get matImagesHint => 'Up to 5 photos • JPEG, PNG, WebP • 5 MiB each';

  @override
  String get matAddImage => 'Add photo';

  @override
  String get matCamera => 'Take photo';

  @override
  String get matGallery => 'Choose from library';

  @override
  String get matCover => 'Cover';

  @override
  String get matMakeCover => 'Set as cover';

  @override
  String get matRemoveImage => 'Remove photo';

  @override
  String get matRemoveImageBody =>
      'This photo will be removed from the material when you save.';

  @override
  String get matImageInvalid =>
      'Invalid photo. Choose a JPEG, PNG or WebP up to 5 MiB.';

  @override
  String get matImageFailed =>
      'Photo upload failed. Your changes are kept; please retry.';

  @override
  String get matUploadProgress => 'Uploading photos';

  @override
  String get matSaveProgress => 'Saving material…';

  @override
  String get matConflict =>
      'This material changed. Reload before saving; your edits are kept.';

  @override
  String get matForbidden => 'You do not have permission for this action.';

  @override
  String get matNetwork =>
      'Connection failed. Check your network or save a draft.';

  @override
  String get matUnknown =>
      'The save result is unknown. Retry to check the same operation without creating a duplicate.';

  @override
  String get matRefresh => 'Reload data';

  @override
  String get matLeaveTitle => 'Unsaved changes';

  @override
  String get matLeaveBody => 'Keep a draft on this device to continue later.';

  @override
  String get matKeepEditing => 'Keep editing';

  @override
  String get matSaveDraft => 'Save device draft';

  @override
  String get matDiscard => 'Discard changes';

  @override
  String get matDraftSaved => 'Draft saved on this device.';

  @override
  String get matDraftFound => 'An unfinished draft is available';

  @override
  String get matResumeDraft => 'Resume draft';

  @override
  String get matNewInstead => 'Start over';

  @override
  String get matDraftError =>
      'Could not save the draft. Keep this screen open and try again.';

  @override
  String get matCopyId => 'Copy material ID';

  @override
  String get matIdCopied => 'Material ID copied.';

  @override
  String get matOwner => 'Owner';

  @override
  String get matHolder => 'Current holder';

  @override
  String get matYou => 'You';

  @override
  String get matDemo => 'Demo data • not saved to Supabase';

  @override
  String get matDetailsHint => 'One physical book, saved in your collection.';

  @override
  String get matReloadUrls => 'Reload photos';

  @override
  String get matTip =>
      'Show the cover and any marked pages so others can see the book\'s condition.';

  @override
  String get matNewTitle => 'Add a book.\nOpen a new chapter.';

  @override
  String get matFormHint =>
      'Save a physical book you own. You can publish a listing later.';

  @override
  String get matPhotoPermission =>
      'Could not open the camera or library. Check permissions and try again.';

  @override
  String get matSnapshotChanged =>
      'The latest version is loaded. You can edit this version.';

  @override
  String get matCached => 'Showing a device copy. Connect to refresh and edit.';
}

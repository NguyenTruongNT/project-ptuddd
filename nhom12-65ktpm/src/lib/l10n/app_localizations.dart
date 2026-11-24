import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @navHome.
  ///
  /// In vi, this message translates to:
  /// **'Trang chủ'**
  String get navHome;

  /// No description provided for @navExplore.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá'**
  String get navExplore;

  /// No description provided for @navPublish.
  ///
  /// In vi, this message translates to:
  /// **'Đăng tin'**
  String get navPublish;

  /// No description provided for @navTransactions.
  ///
  /// In vi, this message translates to:
  /// **'Giao dịch'**
  String get navTransactions;

  /// No description provided for @navProfile.
  ///
  /// In vi, this message translates to:
  /// **'Cá nhân'**
  String get navProfile;

  /// No description provided for @welcomeMessage.
  ///
  /// In vi, this message translates to:
  /// **'Chào mừng đến StudyShare. Các chức năng nghiệp vụ sẽ được triển khai ở các PR tiếp theo.'**
  String get welcomeMessage;

  /// No description provided for @placeholderMessage.
  ///
  /// In vi, this message translates to:
  /// **'Màn hình nền tảng tạm thời; chưa kết nối Supabase hoặc thực hiện giao dịch.'**
  String get placeholderMessage;

  /// No description provided for @settingsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get settingsTitle;

  /// No description provided for @themeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Chế độ hiển thị'**
  String get themeLabel;

  /// No description provided for @themeSystem.
  ///
  /// In vi, this message translates to:
  /// **'Theo hệ thống'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In vi, this message translates to:
  /// **'Sáng'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In vi, this message translates to:
  /// **'Tối'**
  String get themeDark;

  /// No description provided for @paletteLabel.
  ///
  /// In vi, this message translates to:
  /// **'Bảng màu giao diện'**
  String get paletteLabel;

  /// No description provided for @languageLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get languageLabel;

  /// No description provided for @gridLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nền lưới ô vuông'**
  String get gridLabel;

  /// No description provided for @leavesLabel.
  ///
  /// In vi, this message translates to:
  /// **'Hiệu ứng lá rơi'**
  String get leavesLabel;

  /// No description provided for @leavesHint.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ dùng trên Trang chủ và tự ẩn nếu giảm chuyển động.'**
  String get leavesHint;

  /// No description provided for @sessionOnlyNotice.
  ///
  /// In vi, this message translates to:
  /// **'Bản thử nghiệm: lựa chọn hiện chỉ lưu trong phiên ứng dụng. Lưu cục bộ sẽ được bổ sung ở nhiệm vụ tiếp theo.'**
  String get sessionOnlyNotice;

  /// No description provided for @authWelcome.
  ///
  /// In vi, this message translates to:
  /// **'Chào mừng trở lại'**
  String get authWelcome;

  /// No description provided for @authEmail.
  ///
  /// In vi, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu'**
  String get authPassword;

  /// No description provided for @authDisplayName.
  ///
  /// In vi, this message translates to:
  /// **'Tên hiển thị'**
  String get authDisplayName;

  /// No description provided for @authConfirmPassword.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận mật khẩu'**
  String get authConfirmPassword;

  /// No description provided for @authSignIn.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập'**
  String get authSignIn;

  /// No description provided for @authSignUp.
  ///
  /// In vi, this message translates to:
  /// **'Tạo tài khoản'**
  String get authSignUp;

  /// No description provided for @authForgot.
  ///
  /// In vi, this message translates to:
  /// **'Quên mật khẩu?'**
  String get authForgot;

  /// No description provided for @authResetTitle.
  ///
  /// In vi, this message translates to:
  /// **'Khôi phục mật khẩu'**
  String get authResetTitle;

  /// No description provided for @authSendReset.
  ///
  /// In vi, this message translates to:
  /// **'Gửi email khôi phục'**
  String get authSendReset;

  /// No description provided for @authUpdateTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đặt mật khẩu mới'**
  String get authUpdateTitle;

  /// No description provided for @authUpdatePassword.
  ///
  /// In vi, this message translates to:
  /// **'Lưu mật khẩu mới'**
  String get authUpdatePassword;

  /// No description provided for @authBackToLogin.
  ///
  /// In vi, this message translates to:
  /// **'Về đăng nhập'**
  String get authBackToLogin;

  /// No description provided for @authCheckEmail.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm tra email'**
  String get authCheckEmail;

  /// No description provided for @authCheckEmailHint.
  ///
  /// In vi, this message translates to:
  /// **'Mở liên kết xác minh trong email để hoàn tất đăng ký, sau đó đăng nhập.'**
  String get authCheckEmailHint;

  /// No description provided for @authResend.
  ///
  /// In vi, this message translates to:
  /// **'Gửi lại email xác minh'**
  String get authResend;

  /// No description provided for @authCooldown.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chờ một phút trước khi gửi lại.'**
  String get authCooldown;

  /// No description provided for @authResetSent.
  ///
  /// In vi, this message translates to:
  /// **'Nếu email đủ điều kiện, hướng dẫn khôi phục đã được gửi. Vui lòng kiểm tra hộp thư.'**
  String get authResetSent;

  /// No description provided for @authConfirmationSent.
  ///
  /// In vi, this message translates to:
  /// **'Nếu tài khoản cần xác minh, email xác minh đã được gửi.'**
  String get authConfirmationSent;

  /// No description provided for @authPasswordUpdated.
  ///
  /// In vi, this message translates to:
  /// **'Đã đổi mật khẩu. Vui lòng đăng nhập lại.'**
  String get authPasswordUpdated;

  /// No description provided for @authInvalidEmail.
  ///
  /// In vi, this message translates to:
  /// **'Nhập địa chỉ email hợp lệ.'**
  String get authInvalidEmail;

  /// No description provided for @authRequiredPassword.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mật khẩu.'**
  String get authRequiredPassword;

  /// No description provided for @authWeakPassword.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu chưa đáp ứng chính sách bảo mật của hệ thống.'**
  String get authWeakPassword;

  /// No description provided for @authPasswordMismatch.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu xác nhận chưa khớp.'**
  String get authPasswordMismatch;

  /// No description provided for @authInvalidName.
  ///
  /// In vi, this message translates to:
  /// **'Tên hiển thị phải có từ 1 đến 100 ký tự.'**
  String get authInvalidName;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In vi, this message translates to:
  /// **'Email hoặc mật khẩu không hợp lệ.'**
  String get authInvalidCredentials;

  /// No description provided for @authEmailUnconfirmed.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng xác minh email trước khi đăng nhập.'**
  String get authEmailUnconfirmed;

  /// No description provided for @authRateLimit.
  ///
  /// In vi, this message translates to:
  /// **'Bạn thao tác quá nhanh. Vui lòng thử lại sau.'**
  String get authRateLimit;

  /// No description provided for @authNetworkError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể kết nối. Kiểm tra mạng và thử lại.'**
  String get authNetworkError;

  /// No description provided for @authGenericError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể hoàn tất thao tác. Vui lòng thử lại.'**
  String get authGenericError;

  /// No description provided for @authRecoveryExpired.
  ///
  /// In vi, this message translates to:
  /// **'Liên kết khôi phục không còn hợp lệ. Hãy yêu cầu email mới.'**
  String get authRecoveryExpired;

  /// No description provided for @authNotConfigured.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập hiện chưa khả dụng. Bạn có thể xem bản demo.'**
  String get authNotConfigured;

  /// No description provided for @authInitializationError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể khởi tạo phiên đăng nhập. Vui lòng mở lại ứng dụng.'**
  String get authInitializationError;

  /// No description provided for @authDemo.
  ///
  /// In vi, this message translates to:
  /// **'Xem bản demo'**
  String get authDemo;

  /// No description provided for @authDemoNotice.
  ///
  /// In vi, this message translates to:
  /// **'Bản demo: dữ liệu mô phỏng, chưa đăng nhập Supabase.'**
  String get authDemoNotice;

  /// No description provided for @authExitDemo.
  ///
  /// In vi, this message translates to:
  /// **'Thoát demo'**
  String get authExitDemo;

  /// No description provided for @authShowPassword.
  ///
  /// In vi, this message translates to:
  /// **'Hiện mật khẩu'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn mật khẩu'**
  String get authHidePassword;

  /// No description provided for @authSplash.
  ///
  /// In vi, this message translates to:
  /// **'Đang khởi động StudyShare…'**
  String get authSplash;

  /// No description provided for @authRetry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get authRetry;

  /// No description provided for @profileTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ của tôi'**
  String get profileTitle;

  /// No description provided for @profileEdit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa tên hiển thị'**
  String get profileEdit;

  /// No description provided for @profileSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thay đổi'**
  String get profileSave;

  /// No description provided for @profileSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu hồ sơ.'**
  String get profileSaved;

  /// No description provided for @profileLoadError.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải hồ sơ. Vui lòng thử lại.'**
  String get profileLoadError;

  /// No description provided for @profileMyMaterials.
  ///
  /// In vi, this message translates to:
  /// **'Tài liệu của tôi'**
  String get profileMyMaterials;

  /// No description provided for @profileMyTransactions.
  ///
  /// In vi, this message translates to:
  /// **'Giao dịch của tôi'**
  String get profileMyTransactions;

  /// No description provided for @profileMyDeliveries.
  ///
  /// In vi, this message translates to:
  /// **'Giao hộ'**
  String get profileMyDeliveries;

  /// No description provided for @profileMyIssues.
  ///
  /// In vi, this message translates to:
  /// **'Sự cố'**
  String get profileMyIssues;

  /// No description provided for @profileLogout.
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất'**
  String get profileLogout;

  /// No description provided for @profileLogoutConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất khỏi thiết bị này?'**
  String get profileLogoutConfirm;

  /// No description provided for @commonCancel.
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get commonCancel;

  /// No description provided for @preferencesSavedNotice.
  ///
  /// In vi, this message translates to:
  /// **'Lựa chọn giao diện được lưu trên thiết bị.'**
  String get preferencesSavedNotice;

  /// No description provided for @preferencesSaveError.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được lựa chọn. Vui lòng thử lại.'**
  String get preferencesSaveError;

  /// No description provided for @authLoginNeeded.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để xem hồ sơ của bạn.'**
  String get authLoginNeeded;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

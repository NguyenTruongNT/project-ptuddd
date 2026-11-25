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

  /// No description provided for @brandTagline.
  ///
  /// In vi, this message translates to:
  /// **'Cộng đồng chia sẻ tài liệu học tập'**
  String get brandTagline;

  /// No description provided for @brandHeading.
  ///
  /// In vi, this message translates to:
  /// **'Trao tài liệu.\nNhận tri thức.'**
  String get brandHeading;

  /// No description provided for @brandDescription.
  ///
  /// In vi, this message translates to:
  /// **'Kết nối với sinh viên, chia sẻ những cuốn sách và tiếp nối hành trình học tập.'**
  String get brandDescription;

  /// No description provided for @brandBooks.
  ///
  /// In vi, this message translates to:
  /// **'Tìm tài liệu bạn cần'**
  String get brandBooks;

  /// No description provided for @brandExchange.
  ///
  /// In vi, this message translates to:
  /// **'Mua, tặng và mượn sách'**
  String get brandExchange;

  /// No description provided for @brandCommunity.
  ///
  /// In vi, this message translates to:
  /// **'Kết nối cộng đồng sinh viên'**
  String get brandCommunity;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để tiếp tục hành trình chia sẻ của bạn.'**
  String get authSignInSubtitle;

  /// No description provided for @authSignUpSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Một tài khoản, thêm nhiều cơ hội học tập cùng nhau.'**
  String get authSignUpSubtitle;

  /// No description provided for @authResetSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập email đăng ký để nhận hướng dẫn khôi phục.'**
  String get authResetSubtitle;

  /// No description provided for @authNewPasswordSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn mật khẩu mới để bảo vệ tài khoản của bạn.'**
  String get authNewPasswordSubtitle;

  /// No description provided for @authCreateConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận tạo tài khoản'**
  String get authCreateConfirm;

  /// No description provided for @authCreateConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Tạo tài khoản với tên “{name}” và email {email}?'**
  String authCreateConfirmBody(String name, String email);

  /// No description provided for @authPasswordConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận đổi mật khẩu'**
  String get authPasswordConfirm;

  /// No description provided for @authPasswordConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn sẽ cần đăng nhập lại bằng mật khẩu mới sau khi lưu.'**
  String get authPasswordConfirmBody;

  /// No description provided for @authCreated.
  ///
  /// In vi, this message translates to:
  /// **'Đã tạo tài khoản thành công.'**
  String get authCreated;

  /// No description provided for @authSignedIn.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập thành công.'**
  String get authSignedIn;

  /// No description provided for @authPasswordHint.
  ///
  /// In vi, this message translates to:
  /// **'Tối thiểu {count} ký tự'**
  String authPasswordHint(int count);

  /// No description provided for @authPasswordUppercase.
  ///
  /// In vi, this message translates to:
  /// **'Chữ hoa (A–Z)'**
  String get authPasswordUppercase;

  /// No description provided for @authPasswordLowercase.
  ///
  /// In vi, this message translates to:
  /// **'Chữ thường (a–z)'**
  String get authPasswordLowercase;

  /// No description provided for @authPasswordDigit.
  ///
  /// In vi, this message translates to:
  /// **'Chữ số (0–9)'**
  String get authPasswordDigit;

  /// No description provided for @authPasswordSymbol.
  ///
  /// In vi, this message translates to:
  /// **'Ký tự đặc biệt (ví dụ !@#)'**
  String get authPasswordSymbol;

  /// No description provided for @authPasswordNeeds.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu còn thiếu: {requirements}.'**
  String authPasswordNeeds(String requirements);

  /// No description provided for @commonBack.
  ///
  /// In vi, this message translates to:
  /// **'Quay lại'**
  String get commonBack;

  /// No description provided for @commonConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận'**
  String get commonConfirm;

  /// No description provided for @commonDiscardTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ thay đổi chưa lưu?'**
  String get commonDiscardTitle;

  /// No description provided for @commonDiscardBody.
  ///
  /// In vi, this message translates to:
  /// **'Những thay đổi của bạn sẽ không được lưu.'**
  String get commonDiscardBody;

  /// No description provided for @commonDiscard.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ thay đổi'**
  String get commonDiscard;

  /// No description provided for @profileSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý thông tin và hoạt động chia sẻ của bạn.'**
  String get profileSubtitle;

  /// No description provided for @profileActivity.
  ///
  /// In vi, this message translates to:
  /// **'Hoạt động của tôi'**
  String get profileActivity;

  /// No description provided for @profileAccount.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get profileAccount;

  /// No description provided for @profileEditHint.
  ///
  /// In vi, this message translates to:
  /// **'Tên này hiển thị với những người bạn giao dịch.'**
  String get profileEditHint;

  /// No description provided for @profileEmailHint.
  ///
  /// In vi, this message translates to:
  /// **'Email đăng nhập'**
  String get profileEmailHint;

  /// No description provided for @profileNameConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Đổi tên hiển thị thành “{name}”?'**
  String profileNameConfirm(String name);

  /// No description provided for @settingsSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Tùy chỉnh không gian học tập theo cách của bạn.'**
  String get settingsSubtitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In vi, this message translates to:
  /// **'Giao diện'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceHint.
  ///
  /// In vi, this message translates to:
  /// **'Chọn chế độ hiển thị và màu yêu thích.'**
  String get settingsAppearanceHint;

  /// No description provided for @settingsEffects.
  ///
  /// In vi, this message translates to:
  /// **'Hiệu ứng'**
  String get settingsEffects;

  /// No description provided for @gridHint.
  ///
  /// In vi, this message translates to:
  /// **'Thêm đường kẻ nhẹ ở nền Trang chủ.'**
  String get gridHint;

  /// No description provided for @settingsDraftHint.
  ///
  /// In vi, this message translates to:
  /// **'Thay đổi chỉ áp dụng khi bạn chọn Lưu thay đổi.'**
  String get settingsDraftHint;

  /// No description provided for @preferencesSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu cài đặt.'**
  String get preferencesSaved;

  /// No description provided for @preferencesSaving.
  ///
  /// In vi, this message translates to:
  /// **'Đang lưu…'**
  String get preferencesSaving;

  /// No description provided for @preferencesAutoSaveHint.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng ngay và tự lưu trên thiết bị này.'**
  String get preferencesAutoSaveHint;

  /// No description provided for @preferencesSaveRestored.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được lựa chọn. Đã khôi phục cài đặt đã lưu trước đó.'**
  String get preferencesSaveRestored;

  /// No description provided for @authJoinPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tài khoản?'**
  String get authJoinPrompt;

  /// No description provided for @authOAuthDivider.
  ///
  /// In vi, this message translates to:
  /// **'Hoặc tiếp tục với'**
  String get authOAuthDivider;

  /// No description provided for @authContinueGoogle.
  ///
  /// In vi, this message translates to:
  /// **'Google'**
  String get authContinueGoogle;

  /// No description provided for @authContinueGithub.
  ///
  /// In vi, this message translates to:
  /// **'GitHub'**
  String get authContinueGithub;

  /// No description provided for @authSocialDeveloping.
  ///
  /// In vi, this message translates to:
  /// **'Tính năng đang phát triển.'**
  String get authSocialDeveloping;

  /// No description provided for @authPasswordsMatch.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu trùng khớp'**
  String get authPasswordsMatch;

  /// No description provided for @authSocialUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Phương thức đăng nhập này hiện chưa khả dụng. Vui lòng thử lại sau.'**
  String get authSocialUnavailable;

  /// No description provided for @authContinueSharing.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục hành trình chia sẻ của bạn.'**
  String get authContinueSharing;

  /// No description provided for @settingsConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng cài đặt mới?'**
  String get settingsConfirm;

  /// No description provided for @settingsConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Lưu giao diện, ngôn ngữ và hiệu ứng đã chọn trên thiết bị này.'**
  String get settingsConfirmBody;

  /// No description provided for @paletteGreen.
  ///
  /// In vi, this message translates to:
  /// **'Xanh lá'**
  String get paletteGreen;

  /// No description provided for @paletteBlue.
  ///
  /// In vi, this message translates to:
  /// **'Xanh dương'**
  String get paletteBlue;

  /// No description provided for @palettePurple.
  ///
  /// In vi, this message translates to:
  /// **'Tím'**
  String get palettePurple;

  /// No description provided for @paletteOrange.
  ///
  /// In vi, this message translates to:
  /// **'Cam'**
  String get paletteOrange;

  /// No description provided for @profileMaterialsHint.
  ///
  /// In vi, this message translates to:
  /// **'Sách và tài liệu bạn đang quản lý'**
  String get profileMaterialsHint;

  /// No description provided for @profileTransactionsHint.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi mua, tặng và mượn'**
  String get profileTransactionsHint;

  /// No description provided for @profileDeliveriesHint.
  ///
  /// In vi, this message translates to:
  /// **'Các lượt giao tài liệu'**
  String get profileDeliveriesHint;

  /// No description provided for @profileIssuesHint.
  ///
  /// In vi, this message translates to:
  /// **'Theo dõi vấn đề cần giải quyết'**
  String get profileIssuesHint;

  /// No description provided for @matTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tài liệu của tôi'**
  String get matTitle;

  /// No description provided for @matSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Mỗi cuốn sách, một hành trình tri thức.'**
  String get matSubtitle;

  /// No description provided for @matAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm tài liệu'**
  String get matAdd;

  /// No description provided for @matEdit.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa'**
  String get matEdit;

  /// No description provided for @matDetails.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiết tài liệu'**
  String get matDetails;

  /// No description provided for @matSearch.
  ///
  /// In vi, this message translates to:
  /// **'Tìm tên tài liệu hoặc ISBN'**
  String get matSearch;

  /// No description provided for @matAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get matAll;

  /// No description provided for @matReady.
  ///
  /// In vi, this message translates to:
  /// **'Có thể đăng'**
  String get matReady;

  /// No description provided for @matActive.
  ///
  /// In vi, this message translates to:
  /// **'Đang giao dịch'**
  String get matActive;

  /// No description provided for @matEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu từ một cuốn sách'**
  String get matEmpty;

  /// No description provided for @matEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Thêm tài liệu bạn sở hữu để lưu giữ và sẵn sàng chia sẻ.'**
  String get matEmptyBody;

  /// No description provided for @matNoResults.
  ///
  /// In vi, this message translates to:
  /// **'Chưa tìm thấy tài liệu phù hợp.'**
  String get matNoResults;

  /// No description provided for @matTryAgain.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get matTryAgain;

  /// No description provided for @matLoadMore.
  ///
  /// In vi, this message translates to:
  /// **'Xem thêm'**
  String get matLoadMore;

  /// No description provided for @matNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Tài liệu không còn tồn tại hoặc bạn không có quyền xem.'**
  String get matNotFound;

  /// No description provided for @matNoImage.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có ảnh'**
  String get matNoImage;

  /// No description provided for @matNoImageHint.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ít nhất một ảnh để có thể đăng tin.'**
  String get matNoImageHint;

  /// No description provided for @matHeldByYou.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang giữ'**
  String get matHeldByYou;

  /// No description provided for @matHeldOther.
  ///
  /// In vi, this message translates to:
  /// **'Người khác đang giữ'**
  String get matHeldOther;

  /// No description provided for @matReserved.
  ///
  /// In vi, this message translates to:
  /// **'Đã được đặt'**
  String get matReserved;

  /// No description provided for @matUnlisted.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đăng tin'**
  String get matUnlisted;

  /// No description provided for @matPublished.
  ///
  /// In vi, this message translates to:
  /// **'Đang công khai'**
  String get matPublished;

  /// No description provided for @matDraftListing.
  ///
  /// In vi, this message translates to:
  /// **'Tin nháp'**
  String get matDraftListing;

  /// No description provided for @matHiddenListing.
  ///
  /// In vi, this message translates to:
  /// **'Đã ẩn tin'**
  String get matHiddenListing;

  /// No description provided for @matReadyLabel.
  ///
  /// In vi, this message translates to:
  /// **'Sẵn sàng chia sẻ'**
  String get matReadyLabel;

  /// No description provided for @matLockedTransaction.
  ///
  /// In vi, this message translates to:
  /// **'Tài liệu đang có giao dịch. Bạn có thể xem, nhưng chưa thể sửa thông tin và ảnh.'**
  String get matLockedTransaction;

  /// No description provided for @matLockedListing.
  ///
  /// In vi, this message translates to:
  /// **'Hãy ẩn tin đăng trước khi chỉnh sửa tài liệu.'**
  String get matLockedListing;

  /// No description provided for @matLockedRequest.
  ///
  /// In vi, this message translates to:
  /// **'Cần xử lý các yêu cầu đang chờ trước khi chỉnh sửa.'**
  String get matLockedRequest;

  /// No description provided for @matLockedHolder.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ chỉnh sửa khi tài liệu đã được ghi nhận về người sở hữu.'**
  String get matLockedHolder;

  /// No description provided for @matSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu tài liệu'**
  String get matSave;

  /// No description provided for @matSaveChanges.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thay đổi'**
  String get matSaveChanges;

  /// No description provided for @matSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu tài liệu.'**
  String get matSaved;

  /// No description provided for @matConfirmCreate.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận thêm tài liệu'**
  String get matConfirmCreate;

  /// No description provided for @matConfirmEdit.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận thay đổi'**
  String get matConfirmEdit;

  /// No description provided for @matConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin và thứ tự ảnh dưới đây sẽ được lưu:'**
  String get matConfirmBody;

  /// No description provided for @matName.
  ///
  /// In vi, this message translates to:
  /// **'Tên tài liệu'**
  String get matName;

  /// No description provided for @matSubject.
  ///
  /// In vi, this message translates to:
  /// **'Môn học / loại'**
  String get matSubject;

  /// No description provided for @matCondition.
  ///
  /// In vi, this message translates to:
  /// **'Tình trạng'**
  String get matCondition;

  /// No description provided for @matDescription.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả'**
  String get matDescription;

  /// No description provided for @matIsbn.
  ///
  /// In vi, this message translates to:
  /// **'ISBN (không bắt buộc)'**
  String get matIsbn;

  /// No description provided for @matRequired200.
  ///
  /// In vi, this message translates to:
  /// **'Nhập từ 1 đến 200 ký tự hợp lệ.'**
  String get matRequired200;

  /// No description provided for @matRequired100.
  ///
  /// In vi, this message translates to:
  /// **'Nhập từ 1 đến 100 ký tự hợp lệ.'**
  String get matRequired100;

  /// No description provided for @matDescriptionLimit.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả tối đa 2.000 ký tự hợp lệ.'**
  String get matDescriptionLimit;

  /// No description provided for @matInvalidIsbn.
  ///
  /// In vi, this message translates to:
  /// **'ISBN phải là mã ISBN-10 hoặc ISBN-13 hợp lệ.'**
  String get matInvalidIsbn;

  /// No description provided for @matImages.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh tài liệu'**
  String get matImages;

  /// No description provided for @matImagesHint.
  ///
  /// In vi, this message translates to:
  /// **'Tối đa 5 ảnh • JPEG, PNG, WebP • 5 MiB/ảnh'**
  String get matImagesHint;

  /// No description provided for @matAddImage.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ảnh'**
  String get matAddImage;

  /// No description provided for @matCamera.
  ///
  /// In vi, this message translates to:
  /// **'Chụp ảnh'**
  String get matCamera;

  /// No description provided for @matGallery.
  ///
  /// In vi, this message translates to:
  /// **'Chọn từ thư viện'**
  String get matGallery;

  /// No description provided for @matCover.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh bìa'**
  String get matCover;

  /// No description provided for @matMakeCover.
  ///
  /// In vi, this message translates to:
  /// **'Đặt làm ảnh bìa'**
  String get matMakeCover;

  /// No description provided for @matRemoveImage.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ ảnh'**
  String get matRemoveImage;

  /// No description provided for @matRemoveImageBody.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh sẽ được gỡ khỏi tài liệu khi bạn lưu thay đổi.'**
  String get matRemoveImageBody;

  /// No description provided for @matImageInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh không hợp lệ. Chọn JPEG, PNG hoặc WebP không quá 5 MiB.'**
  String get matImageInvalid;

  /// No description provided for @matImageFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tải ảnh. Nội dung đã được giữ lại; hãy thử lại.'**
  String get matImageFailed;

  /// No description provided for @matUploadProgress.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải ảnh'**
  String get matUploadProgress;

  /// No description provided for @matSaveProgress.
  ///
  /// In vi, this message translates to:
  /// **'Đang lưu tài liệu…'**
  String get matSaveProgress;

  /// No description provided for @matConflict.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu đã thay đổi. Tải lại bản mới trước khi lưu; nội dung bạn nhập vẫn được giữ.'**
  String get matConflict;

  /// No description provided for @matForbidden.
  ///
  /// In vi, this message translates to:
  /// **'Bạn không có quyền thực hiện thao tác này.'**
  String get matForbidden;

  /// No description provided for @matNetwork.
  ///
  /// In vi, this message translates to:
  /// **'Chưa kết nối được. Hãy kiểm tra mạng hoặc lưu bản nháp.'**
  String get matNetwork;

  /// No description provided for @matUnknown.
  ///
  /// In vi, this message translates to:
  /// **'Chưa xác định kết quả lưu. Thử lại để kiểm tra cùng thao tác, không tạo tài liệu trùng.'**
  String get matUnknown;

  /// No description provided for @matRefresh.
  ///
  /// In vi, this message translates to:
  /// **'Tải lại dữ liệu'**
  String get matRefresh;

  /// No description provided for @matLeaveTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có thay đổi chưa lưu'**
  String get matLeaveTitle;

  /// No description provided for @matLeaveBody.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có thể giữ bản nháp trên thiết bị để tiếp tục sau.'**
  String get matLeaveBody;

  /// No description provided for @matKeepEditing.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục sửa'**
  String get matKeepEditing;

  /// No description provided for @matSaveDraft.
  ///
  /// In vi, this message translates to:
  /// **'Lưu nháp trên máy'**
  String get matSaveDraft;

  /// No description provided for @matDiscard.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ thay đổi'**
  String get matDiscard;

  /// No description provided for @matDraftSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu nháp trên thiết bị.'**
  String get matDraftSaved;

  /// No description provided for @matDraftFound.
  ///
  /// In vi, this message translates to:
  /// **'Có bản nháp chưa hoàn tất'**
  String get matDraftFound;

  /// No description provided for @matResumeDraft.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục bản nháp'**
  String get matResumeDraft;

  /// No description provided for @matNewInstead.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu lại'**
  String get matNewInstead;

  /// No description provided for @matDraftError.
  ///
  /// In vi, this message translates to:
  /// **'Không lưu được bản nháp. Hãy giữ màn hình này và thử lại.'**
  String get matDraftError;

  /// No description provided for @matCopyId.
  ///
  /// In vi, this message translates to:
  /// **'Sao chép mã tài liệu'**
  String get matCopyId;

  /// No description provided for @matIdCopied.
  ///
  /// In vi, this message translates to:
  /// **'Đã sao chép mã tài liệu.'**
  String get matIdCopied;

  /// No description provided for @matOwner.
  ///
  /// In vi, this message translates to:
  /// **'Chủ sở hữu'**
  String get matOwner;

  /// No description provided for @matHolder.
  ///
  /// In vi, this message translates to:
  /// **'Người đang giữ'**
  String get matHolder;

  /// No description provided for @matYou.
  ///
  /// In vi, this message translates to:
  /// **'Bạn'**
  String get matYou;

  /// No description provided for @matDemo.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu mô phỏng • không lưu lên Supabase'**
  String get matDemo;

  /// No description provided for @matDetailsHint.
  ///
  /// In vi, this message translates to:
  /// **'Một bản sách riêng, được lưu cùng bạn.'**
  String get matDetailsHint;

  /// No description provided for @matReloadUrls.
  ///
  /// In vi, this message translates to:
  /// **'Tải lại ảnh'**
  String get matReloadUrls;

  /// No description provided for @matTip.
  ///
  /// In vi, this message translates to:
  /// **'Chụp rõ bìa và những trang có ghi chú để người nhận hiểu đúng tình trạng sách.'**
  String get matTip;

  /// No description provided for @matNewTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm một cuốn sách,\nmở thêm cơ hội sẻ chia.'**
  String get matNewTitle;

  /// No description provided for @matFormHint.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thông tin bản sách bạn sở hữu. Bạn có thể đăng tin sau.'**
  String get matFormHint;

  /// No description provided for @matPhotoPermission.
  ///
  /// In vi, this message translates to:
  /// **'Không mở được camera hoặc thư viện. Kiểm tra quyền truy cập và thử lại.'**
  String get matPhotoPermission;

  /// No description provided for @matSnapshotChanged.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung mới nhất đã được tải. Bạn có thể tiếp tục chỉnh sửa từ bản này.'**
  String get matSnapshotChanged;

  /// No description provided for @matCached.
  ///
  /// In vi, this message translates to:
  /// **'Đang xem dữ liệu lưu trên thiết bị. Kết nối mạng để tải dữ liệu mới và chỉnh sửa.'**
  String get matCached;
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

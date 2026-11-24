// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get navHome => 'Trang chủ';

  @override
  String get navExplore => 'Khám phá';

  @override
  String get navPublish => 'Đăng tin';

  @override
  String get navTransactions => 'Giao dịch';

  @override
  String get navProfile => 'Cá nhân';

  @override
  String get welcomeMessage =>
      'Chào mừng đến StudyShare. Các chức năng nghiệp vụ sẽ được triển khai ở các PR tiếp theo.';

  @override
  String get placeholderMessage =>
      'Màn hình nền tảng tạm thời; chưa kết nối Supabase hoặc thực hiện giao dịch.';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get themeLabel => 'Chế độ hiển thị';

  @override
  String get themeSystem => 'Theo hệ thống';

  @override
  String get themeLight => 'Sáng';

  @override
  String get themeDark => 'Tối';

  @override
  String get paletteLabel => 'Bảng màu giao diện';

  @override
  String get languageLabel => 'Ngôn ngữ';

  @override
  String get gridLabel => 'Nền lưới ô vuông';

  @override
  String get leavesLabel => 'Hiệu ứng lá rơi';

  @override
  String get leavesHint =>
      'Chỉ dùng trên Trang chủ và tự ẩn nếu giảm chuyển động.';

  @override
  String get sessionOnlyNotice =>
      'Bản thử nghiệm: lựa chọn hiện chỉ lưu trong phiên ứng dụng. Lưu cục bộ sẽ được bổ sung ở nhiệm vụ tiếp theo.';

  @override
  String get authWelcome => 'Chào mừng trở lại';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Mật khẩu';

  @override
  String get authDisplayName => 'Tên hiển thị';

  @override
  String get authConfirmPassword => 'Xác nhận mật khẩu';

  @override
  String get authSignIn => 'Đăng nhập';

  @override
  String get authSignUp => 'Tạo tài khoản';

  @override
  String get authForgot => 'Quên mật khẩu?';

  @override
  String get authResetTitle => 'Khôi phục mật khẩu';

  @override
  String get authSendReset => 'Gửi email khôi phục';

  @override
  String get authUpdateTitle => 'Đặt mật khẩu mới';

  @override
  String get authUpdatePassword => 'Lưu mật khẩu mới';

  @override
  String get authBackToLogin => 'Về đăng nhập';

  @override
  String get authCheckEmail => 'Kiểm tra email';

  @override
  String get authCheckEmailHint =>
      'Mở liên kết xác minh trong email để hoàn tất đăng ký, sau đó đăng nhập.';

  @override
  String get authResend => 'Gửi lại email xác minh';

  @override
  String get authCooldown => 'Vui lòng chờ một phút trước khi gửi lại.';

  @override
  String get authResetSent =>
      'Nếu email đủ điều kiện, hướng dẫn khôi phục đã được gửi. Vui lòng kiểm tra hộp thư.';

  @override
  String get authConfirmationSent =>
      'Nếu tài khoản cần xác minh, email xác minh đã được gửi.';

  @override
  String get authPasswordUpdated => 'Đã đổi mật khẩu. Vui lòng đăng nhập lại.';

  @override
  String get authInvalidEmail => 'Nhập địa chỉ email hợp lệ.';

  @override
  String get authRequiredPassword => 'Nhập mật khẩu.';

  @override
  String get authWeakPassword =>
      'Mật khẩu chưa đáp ứng chính sách bảo mật của hệ thống.';

  @override
  String get authPasswordMismatch => 'Mật khẩu xác nhận chưa khớp.';

  @override
  String get authInvalidName => 'Tên hiển thị phải có từ 1 đến 100 ký tự.';

  @override
  String get authInvalidCredentials => 'Email hoặc mật khẩu không hợp lệ.';

  @override
  String get authEmailUnconfirmed =>
      'Vui lòng xác minh email trước khi đăng nhập.';

  @override
  String get authRateLimit => 'Bạn thao tác quá nhanh. Vui lòng thử lại sau.';

  @override
  String get authNetworkError => 'Không thể kết nối. Kiểm tra mạng và thử lại.';

  @override
  String get authGenericError =>
      'Không thể hoàn tất thao tác. Vui lòng thử lại.';

  @override
  String get authRecoveryExpired =>
      'Liên kết khôi phục không còn hợp lệ. Hãy yêu cầu email mới.';

  @override
  String get authNotConfigured =>
      'Đăng nhập hiện chưa khả dụng. Bạn có thể xem bản demo.';

  @override
  String get authInitializationError =>
      'Không thể khởi tạo phiên đăng nhập. Vui lòng mở lại ứng dụng.';

  @override
  String get authDemo => 'Xem bản demo';

  @override
  String get authDemoNotice =>
      'Bản demo: dữ liệu mô phỏng, chưa đăng nhập Supabase.';

  @override
  String get authExitDemo => 'Thoát demo';

  @override
  String get authShowPassword => 'Hiện mật khẩu';

  @override
  String get authHidePassword => 'Ẩn mật khẩu';

  @override
  String get authSplash => 'Đang khởi động StudyShare…';

  @override
  String get authRetry => 'Thử lại';

  @override
  String get profileTitle => 'Hồ sơ của tôi';

  @override
  String get profileEdit => 'Sửa tên hiển thị';

  @override
  String get profileSave => 'Lưu thay đổi';

  @override
  String get profileSaved => 'Đã lưu hồ sơ.';

  @override
  String get profileLoadError => 'Không thể tải hồ sơ. Vui lòng thử lại.';

  @override
  String get profileMyMaterials => 'Tài liệu của tôi';

  @override
  String get profileMyTransactions => 'Giao dịch của tôi';

  @override
  String get profileMyDeliveries => 'Giao hộ';

  @override
  String get profileMyIssues => 'Sự cố';

  @override
  String get profileLogout => 'Đăng xuất';

  @override
  String get profileLogoutConfirm => 'Đăng xuất khỏi thiết bị này?';

  @override
  String get commonCancel => 'Hủy';

  @override
  String get preferencesSavedNotice =>
      'Lựa chọn giao diện được lưu trên thiết bị.';

  @override
  String get preferencesSaveError =>
      'Không lưu được lựa chọn. Vui lòng thử lại.';

  @override
  String get authLoginNeeded => 'Đăng nhập để xem hồ sơ của bạn.';

  @override
  String get brandTagline => 'Cộng đồng chia sẻ tài liệu học tập';

  @override
  String get brandHeading => 'Trao tài liệu.\nNhận tri thức.';

  @override
  String get brandDescription =>
      'Kết nối với sinh viên, chia sẻ những cuốn sách và tiếp nối hành trình học tập.';

  @override
  String get brandBooks => 'Tìm tài liệu bạn cần';

  @override
  String get brandExchange => 'Mua, tặng và mượn sách';

  @override
  String get brandCommunity => 'Kết nối cộng đồng sinh viên';

  @override
  String get authSignInSubtitle =>
      'Đăng nhập để tiếp tục hành trình chia sẻ của bạn.';

  @override
  String get authSignUpSubtitle =>
      'Một tài khoản, thêm nhiều cơ hội học tập cùng nhau.';

  @override
  String get authResetSubtitle =>
      'Nhập email đăng ký để nhận hướng dẫn khôi phục.';

  @override
  String get authNewPasswordSubtitle =>
      'Chọn mật khẩu mới để bảo vệ tài khoản của bạn.';

  @override
  String get authCreateConfirm => 'Xác nhận tạo tài khoản';

  @override
  String authCreateConfirmBody(String name, String email) {
    return 'Tạo tài khoản với tên “$name” và email $email?';
  }

  @override
  String get authPasswordConfirm => 'Xác nhận đổi mật khẩu';

  @override
  String get authPasswordConfirmBody =>
      'Bạn sẽ cần đăng nhập lại bằng mật khẩu mới sau khi lưu.';

  @override
  String get authCreated => 'Đã tạo tài khoản thành công.';

  @override
  String get authSignedIn => 'Đăng nhập thành công.';

  @override
  String authPasswordHint(int count) {
    return 'Tối thiểu $count ký tự';
  }

  @override
  String get authPasswordUppercase => 'Chữ hoa (A–Z)';

  @override
  String get authPasswordLowercase => 'Chữ thường (a–z)';

  @override
  String get authPasswordDigit => 'Chữ số (0–9)';

  @override
  String get authPasswordSymbol => 'Ký tự đặc biệt (ví dụ !@#)';

  @override
  String authPasswordNeeds(String requirements) {
    return 'Mật khẩu còn thiếu: $requirements.';
  }

  @override
  String get commonBack => 'Quay lại';

  @override
  String get commonConfirm => 'Xác nhận';

  @override
  String get commonDiscardTitle => 'Bỏ thay đổi chưa lưu?';

  @override
  String get commonDiscardBody => 'Những thay đổi của bạn sẽ không được lưu.';

  @override
  String get commonDiscard => 'Bỏ thay đổi';

  @override
  String get profileSubtitle =>
      'Quản lý thông tin và hoạt động chia sẻ của bạn.';

  @override
  String get profileActivity => 'Hoạt động của tôi';

  @override
  String get profileAccount => 'Tài khoản';

  @override
  String get profileEditHint =>
      'Tên này hiển thị với những người bạn giao dịch.';

  @override
  String get profileEmailHint => 'Email đăng nhập';

  @override
  String profileNameConfirm(String name) {
    return 'Đổi tên hiển thị thành “$name”?';
  }

  @override
  String get settingsSubtitle =>
      'Tùy chỉnh không gian học tập theo cách của bạn.';

  @override
  String get settingsAppearance => 'Giao diện';

  @override
  String get settingsAppearanceHint => 'Chọn chế độ hiển thị và màu yêu thích.';

  @override
  String get settingsEffects => 'Hiệu ứng';

  @override
  String get gridHint => 'Thêm đường kẻ nhẹ ở nền Trang chủ.';

  @override
  String get settingsDraftHint =>
      'Thay đổi chỉ áp dụng khi bạn chọn Lưu thay đổi.';

  @override
  String get preferencesSaved => 'Đã lưu cài đặt.';

  @override
  String get preferencesSaving => 'Đang lưu…';

  @override
  String get preferencesAutoSaveHint =>
      'Áp dụng ngay và tự lưu trên thiết bị này.';

  @override
  String get preferencesSaveRestored =>
      'Không lưu được lựa chọn. Đã khôi phục cài đặt đã lưu trước đó.';

  @override
  String get authJoinPrompt => 'Chưa có tài khoản?';

  @override
  String get authOAuthDivider => 'Hoặc tiếp tục với';

  @override
  String get authContinueGoogle => 'Google';

  @override
  String get authContinueGithub => 'GitHub';

  @override
  String get authSocialDeveloping => 'Tính năng đang phát triển.';

  @override
  String get authPasswordsMatch => 'Mật khẩu trùng khớp';

  @override
  String get authSocialUnavailable =>
      'Phương thức đăng nhập này hiện chưa khả dụng. Vui lòng thử lại sau.';

  @override
  String get authContinueSharing => 'Tiếp tục hành trình chia sẻ của bạn.';

  @override
  String get settingsConfirm => 'Áp dụng cài đặt mới?';

  @override
  String get settingsConfirmBody =>
      'Lưu giao diện, ngôn ngữ và hiệu ứng đã chọn trên thiết bị này.';

  @override
  String get paletteGreen => 'Xanh lá';

  @override
  String get paletteBlue => 'Xanh dương';

  @override
  String get palettePurple => 'Tím';

  @override
  String get paletteOrange => 'Cam';

  @override
  String get profileMaterialsHint => 'Sách và tài liệu bạn đang quản lý';

  @override
  String get profileTransactionsHint => 'Theo dõi mua, tặng và mượn';

  @override
  String get profileDeliveriesHint => 'Các lượt giao tài liệu';

  @override
  String get profileIssuesHint => 'Theo dõi vấn đề cần giải quyết';
}

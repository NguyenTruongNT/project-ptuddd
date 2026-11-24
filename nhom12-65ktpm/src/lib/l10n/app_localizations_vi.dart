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
}

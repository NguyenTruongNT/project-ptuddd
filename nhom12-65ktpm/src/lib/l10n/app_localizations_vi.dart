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
}

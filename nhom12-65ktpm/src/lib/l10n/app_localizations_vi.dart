// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get listingTitle => 'Đăng tin';

  @override
  String get listingCreate => 'Đăng tin mới';

  @override
  String get listingCreateFormTitle => 'Tạo tin đăng';

  @override
  String get listingEditDraftTitle => 'Chỉnh sửa bản nháp';

  @override
  String get listingDetailsTitle => 'Chi tiết tin đăng';

  @override
  String get listingPickerTitle => 'Chọn tài liệu';

  @override
  String get listingPickerHint =>
      'Chọn tài liệu để tạo hoặc tiếp tục tin đăng.';

  @override
  String get listingMaterialSearch => 'Tìm tài liệu';

  @override
  String get listingFilterTitle => 'Lọc theo trạng thái';

  @override
  String listingFilterLabel(String status) {
    return 'Trạng thái: $status ▾';
  }

  @override
  String get listingLocalSection => 'Nháp trên thiết bị';

  @override
  String get listingNoResults => 'Không có kết quả phù hợp.';

  @override
  String get listingNoMaterials =>
      'Bạn chưa có tài liệu. Thêm tài liệu để bắt đầu đăng tin.';

  @override
  String get listingClearFilters => 'Xóa bộ lọc và từ khóa';

  @override
  String get listingClearSearch => 'Xóa từ khóa';

  @override
  String get listingContinueDraft => 'Tiếp tục bản nháp';

  @override
  String get listingManagePublished => 'Quản lý tin đang công bố';

  @override
  String get listingManageHidden => 'Quản lý tin đã ẩn';

  @override
  String get listingMaterialUnavailable =>
      'Tài liệu đang được giữ hoặc có giao dịch; xem thông tin để biết chi tiết.';

  @override
  String get listingBackendUnavailable =>
      'Chức năng đăng tin tạm thời chưa sẵn sàng. Vui lòng thử lại sau.';

  @override
  String get listingUnexpectedError =>
      'Không thể tải hoặc lưu tin đăng. Vui lòng thử lại sau.';

  @override
  String get listingSaveBeforeShow =>
      'Lưu các thay đổi lên máy chủ trước khi hiện lại tin.';

  @override
  String get listingFormTitle => 'Quản lý tin đăng';

  @override
  String get listingChoose => 'Chọn tài liệu để đăng';

  @override
  String get listingMine => 'Tin của tôi';

  @override
  String get listingEmpty => 'Chưa có tin đăng trong mục này.';

  @override
  String get listingAddMaterial => 'Thêm tài liệu';

  @override
  String get listingOffer => 'Hình thức';

  @override
  String get listingBorrow => 'Cho mượn';

  @override
  String get listingDonate => 'Tặng';

  @override
  String get listingSell => 'Bán';

  @override
  String get listingPrice => 'Giá bán (VND)';

  @override
  String get listingDescription => 'Mô tả đề nghị';

  @override
  String get listingArea => 'Khu vực hẹn chung (không bắt buộc)';

  @override
  String get listingSave => 'Lưu nháp lên máy chủ';

  @override
  String get listingLocal => 'Lưu nháp trên thiết bị';

  @override
  String get listingPublish => 'Công bố';

  @override
  String get listingHide => 'Ẩn tin';

  @override
  String get listingShow => 'Hiện lại tin';

  @override
  String get listingDraft => 'Bản nháp';

  @override
  String get listingPublished => 'Đang công bố';

  @override
  String get listingHidden => 'Đã ẩn';

  @override
  String get listingArchived => 'Đã kết thúc';

  @override
  String get listingAll => 'Tất cả';

  @override
  String get listingNoImages =>
      'Cần ít nhất một ảnh đã lưu vào tài liệu để công bố.';

  @override
  String get listingLocked =>
      'Không thể sửa: tin đang công bố, còn yêu cầu chờ hoặc tài liệu không khả dụng.';

  @override
  String get listingUnknown =>
      'Chưa rõ máy chủ đã ghi nhận. Kiểm tra kết quả trước khi tạo thao tác mới.';

  @override
  String get listingCheck => 'Kiểm tra kết quả / gửi lại';

  @override
  String get listingSaved => 'Đã lưu trên máy chủ.';

  @override
  String get listingLocalSaved => 'Đã lưu nháp trên thiết bị, chưa công bố.';

  @override
  String get listingLeave => 'Giữ nháp trên máy trước khi rời?';

  @override
  String get listingDiscard => 'Bỏ thay đổi';

  @override
  String get listingStay => 'Tiếp tục sửa';

  @override
  String get listingNotFound =>
      'Tin không còn công khai hoặc bạn không có quyền.';

  @override
  String get listingHideConfirm =>
      'Tin ngừng xuất hiện trong Khám phá. Yêu cầu và giao dịch đang có vẫn được giữ.';

  @override
  String get listingReserved => 'Đã được đặt';

  @override
  String get listingManage => 'Quản lý tin';

  @override
  String get listingRequest => 'Gửi yêu cầu';

  @override
  String get listingOwnRequest => 'Xem yêu cầu';

  @override
  String listingBorrowPolicy(int minDays, int maxDays) {
    return 'Mượn từ $minDays–$maxDays ngày, người mượn đề xuất và chủ sách chấp thuận đúng số ngày hoặc từ chối.';
  }

  @override
  String get listingRestore =>
      'Khôi phục nháp trên thiết bị? Quyền và phiên bản dữ liệu vẫn cần kiểm tra lại.';

  @override
  String get listingMaterialChanged =>
      'Dữ liệu đã thay đổi. Hãy tải lại và kiểm tra trước khi gửi.';

  @override
  String get listingDemo =>
      'Chế độ mô phỏng chỉ đọc; kết nối Supabase để đăng tin.';

  @override
  String get listingInvalid =>
      'Kiểm tra hình thức, giá, độ dài mô tả và ảnh đã lưu.';

  @override
  String get listingMore => 'Tải thêm';

  @override
  String get listingSearch => 'Tìm tin theo tên tài liệu';

  @override
  String get listingRetry => 'Tải lại';

  @override
  String get listingOwner => 'Người đăng';

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

  @override
  String get matTitle => 'Tài liệu của tôi';

  @override
  String get matSubtitle => 'Mỗi cuốn sách, một hành trình tri thức.';

  @override
  String get matAdd => 'Thêm tài liệu';

  @override
  String get matEdit => 'Chỉnh sửa';

  @override
  String get matDetails => 'Chi tiết tài liệu';

  @override
  String get matSearch => 'Tìm tên tài liệu hoặc ISBN';

  @override
  String get matAll => 'Tất cả';

  @override
  String get matReady => 'Có thể đăng';

  @override
  String get matActive => 'Đang giao dịch';

  @override
  String get matEmpty => 'Bắt đầu từ một cuốn sách';

  @override
  String get matEmptyBody =>
      'Thêm tài liệu bạn sở hữu để lưu giữ và sẵn sàng chia sẻ.';

  @override
  String get matNoResults => 'Chưa tìm thấy tài liệu phù hợp.';

  @override
  String get matTryAgain => 'Thử lại';

  @override
  String get matLoadMore => 'Xem thêm';

  @override
  String get matNotFound =>
      'Tài liệu không còn tồn tại hoặc bạn không có quyền xem.';

  @override
  String get matNoImage => 'Chưa có ảnh';

  @override
  String get matNoImageHint => 'Thêm ít nhất một ảnh để có thể đăng tin.';

  @override
  String get matHeldByYou => 'Bạn đang giữ';

  @override
  String get matHeldOther => 'Người khác đang giữ';

  @override
  String get matReserved => 'Đã được đặt';

  @override
  String get matUnlisted => 'Chưa đăng tin';

  @override
  String get matPublished => 'Đang công khai';

  @override
  String get matDraftListing => 'Tin nháp';

  @override
  String get matHiddenListing => 'Đã ẩn tin';

  @override
  String get matReadyLabel => 'Sẵn sàng chia sẻ';

  @override
  String get matLockedTransaction =>
      'Tài liệu đang có giao dịch. Bạn có thể xem, nhưng chưa thể sửa thông tin và ảnh.';

  @override
  String get matLockedListing =>
      'Hãy ẩn tin đăng trước khi chỉnh sửa tài liệu.';

  @override
  String get matLockedRequest =>
      'Cần xử lý các yêu cầu đang chờ trước khi chỉnh sửa.';

  @override
  String get matLockedHolder =>
      'Chỉ chỉnh sửa khi tài liệu đã được ghi nhận về người sở hữu.';

  @override
  String get matSave => 'Lưu tài liệu';

  @override
  String get matSaveChanges => 'Lưu thay đổi';

  @override
  String get matSaved => 'Đã lưu tài liệu.';

  @override
  String get matConfirmCreate => 'Xác nhận thêm tài liệu';

  @override
  String get matConfirmEdit => 'Xác nhận thay đổi';

  @override
  String get matConfirmBody => 'Thông tin và thứ tự ảnh dưới đây sẽ được lưu:';

  @override
  String get matName => 'Tên tài liệu';

  @override
  String get matSubject => 'Môn học / loại';

  @override
  String get matCondition => 'Tình trạng';

  @override
  String get matDescription => 'Mô tả';

  @override
  String get matIsbn => 'ISBN (không bắt buộc)';

  @override
  String get matRequired200 => 'Nhập từ 1 đến 200 ký tự hợp lệ.';

  @override
  String get matRequired100 => 'Nhập từ 1 đến 100 ký tự hợp lệ.';

  @override
  String get matDescriptionLimit => 'Mô tả tối đa 2.000 ký tự hợp lệ.';

  @override
  String get matInvalidIsbn => 'ISBN phải là mã ISBN-10 hoặc ISBN-13 hợp lệ.';

  @override
  String get matImages => 'Ảnh tài liệu';

  @override
  String get matImagesHint => 'Tối đa 5 ảnh • JPEG, PNG, WebP • 5 MiB/ảnh';

  @override
  String get matAddImage => 'Thêm ảnh';

  @override
  String get matCamera => 'Chụp ảnh';

  @override
  String get matGallery => 'Chọn từ thư viện';

  @override
  String get matCover => 'Ảnh bìa';

  @override
  String get matMakeCover => 'Đặt làm ảnh bìa';

  @override
  String get matRemoveImage => 'Bỏ ảnh';

  @override
  String get matRemoveImageBody =>
      'Ảnh sẽ được gỡ khỏi tài liệu khi bạn lưu thay đổi.';

  @override
  String get matImageInvalid =>
      'Ảnh không hợp lệ. Chọn JPEG, PNG hoặc WebP không quá 5 MiB.';

  @override
  String get matImageFailed =>
      'Không thể tải ảnh. Nội dung đã được giữ lại; hãy thử lại.';

  @override
  String get matUploadProgress => 'Đang tải ảnh';

  @override
  String get matSaveProgress => 'Đang lưu tài liệu…';

  @override
  String get matConflict =>
      'Dữ liệu đã thay đổi. Tải lại bản mới trước khi lưu; nội dung bạn nhập vẫn được giữ.';

  @override
  String get matForbidden => 'Bạn không có quyền thực hiện thao tác này.';

  @override
  String get matNetwork =>
      'Chưa kết nối được. Hãy kiểm tra mạng hoặc lưu bản nháp.';

  @override
  String get matUnknown =>
      'Chưa xác định kết quả lưu. Thử lại để kiểm tra cùng thao tác, không tạo tài liệu trùng.';

  @override
  String get matRefresh => 'Tải lại dữ liệu';

  @override
  String get matLeaveTitle => 'Bạn có thay đổi chưa lưu';

  @override
  String get matLeaveBody =>
      'Bạn có thể giữ bản nháp trên thiết bị để tiếp tục sau.';

  @override
  String get matKeepEditing => 'Tiếp tục sửa';

  @override
  String get matSaveDraft => 'Lưu nháp trên máy';

  @override
  String get matDiscard => 'Bỏ thay đổi';

  @override
  String get matDraftSaved => 'Đã lưu nháp trên thiết bị.';

  @override
  String get matDraftFound => 'Có bản nháp chưa hoàn tất';

  @override
  String get matResumeDraft => 'Tiếp tục bản nháp';

  @override
  String get matNewInstead => 'Bắt đầu lại';

  @override
  String get matDraftError =>
      'Không lưu được bản nháp. Hãy giữ màn hình này và thử lại.';

  @override
  String get matCopyId => 'Sao chép mã tài liệu';

  @override
  String get matIdCopied => 'Đã sao chép mã tài liệu.';

  @override
  String get matOwner => 'Chủ sở hữu';

  @override
  String get matHolder => 'Người đang giữ';

  @override
  String get matYou => 'Bạn';

  @override
  String get matDemo => 'Dữ liệu mô phỏng • không lưu lên Supabase';

  @override
  String get matDetailsHint => 'Một bản sách riêng, được lưu cùng bạn.';

  @override
  String get matReloadUrls => 'Tải lại ảnh';

  @override
  String get matTip =>
      'Chụp rõ bìa và những trang có ghi chú để người nhận hiểu đúng tình trạng sách.';

  @override
  String get matNewTitle => 'Thêm một cuốn sách,\nmở thêm cơ hội sẻ chia.';

  @override
  String get matFormHint =>
      'Lưu thông tin bản sách bạn sở hữu. Bạn có thể đăng tin sau.';

  @override
  String get matPhotoPermission =>
      'Không mở được camera hoặc thư viện. Kiểm tra quyền truy cập và thử lại.';

  @override
  String get matSnapshotChanged =>
      'Nội dung mới nhất đã được tải. Bạn có thể tiếp tục chỉnh sửa từ bản này.';

  @override
  String get matCached =>
      'Đang xem dữ liệu lưu trên thiết bị. Kết nối mạng để tải dữ liệu mới và chỉnh sửa.';
}

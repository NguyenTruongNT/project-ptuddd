// Danh sách đường dẫn được dùng chung cho 26 màn hình MVP.
// Các URL trong danh mục chỉ phục vụ kiểm tra điều hướng, không xử lý nghiệp vụ.
class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const signIn = '/login';
  static const signUp = '/register';
  // Màn phụ Auth, không tăng số SCR chính.
  static const forgotPassword = '/auth/forgot-password';
  static const checkEmail = '/auth/check-email';
  static const resetPassword = '/auth/reset-password';
  static const authCallback = '/auth/callback';
  static const home = '/home';
  static const explore = '/explore';
  static const publishTab =
      '/publish'; // Tab Đăng tin, chưa phải form đăng tin.
  static const listingDetailsPattern = '/listings/:listingId';
  static const myMaterials = '/materials';
  static const materialForm = '/materials/new';
  static const materialDetailsPattern = '/materials/:materialId';
  static const materialEditPattern = '/materials/:materialId/edit';
  // Màn phụ của SCR-09; URL chỉ chứa Material ID, không chứa payload QR.
  static const materialQrPattern = '/materials/:materialId/qr';
  static const listingForm = '/listings/new';
  // Màn phụ của luồng SCR-10, không tăng số mã màn hình nghiệp vụ.
  static const listingMaterialPicker = '/listings/select-material';
  static const createRequestPattern = '/requests/new/:listingId';
  static const requestCenter = '/requests';
  static const transactions = '/transactions';
  static const transactionDetailsPattern = '/transactions/:transactionId';
  static const deliveries = '/deliveries';
  static const createDelivery = '/deliveries/new';
  static const deliveryDetailsPattern = '/deliveries/:taskId';
  static const prepareHandoverPattern = '/handovers/:handoverId/prepare';
  static const scanQrPattern = '/handovers/:handoverId/scan';
  static const receiverAckPattern = '/handovers/:handoverId/ack';
  static const issues = '/issues';
  static const createIssue = '/issues/new';
  static const issueDetailsPattern = '/issues/:issueId';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const settings = '/settings';

  // Hai trang phục vụ kiểm thử bộ khung, KHÔNG tính vào 26 màn hình MVP.
  static const screenCatalog = '/dev/screens';
  static const mockPreview = '/dev/mock';

  static String listingDetails(String id) =>
      '/listings/${Uri.encodeComponent(id)}';
  static String materialDetails(String id) =>
      '/materials/${Uri.encodeComponent(id)}';
  static String materialEdit(String id) =>
      '/materials/${Uri.encodeComponent(id)}/edit';
  static String materialQr(String id) =>
      '/materials/${Uri.encodeComponent(id)}/qr';
  static String transactionDetails(String id) =>
      '/transactions/${Uri.encodeComponent(id)}';
  static String deliveryDetails(String id) =>
      '/deliveries/${Uri.encodeComponent(id)}';
  static String issueDetails(String id) => '/issues/${Uri.encodeComponent(id)}';
  static String createRequest(String listingId) =>
      '/requests/new/${Uri.encodeComponent(listingId)}';
  static String prepareHandover(String id) =>
      '/handovers/${Uri.encodeComponent(id)}/prepare';
  static String scanQr(String id) =>
      '/handovers/${Uri.encodeComponent(id)}/scan';
  static String receiverAck(String id) =>
      '/handovers/${Uri.encodeComponent(id)}/ack';

  // Đúng 26 mã SCR trong thiết kế UI/UX đã duyệt.
  static final List<AppScreenInfo> screens = List.unmodifiable([
    const AppScreenInfo('SCR-01', 'Splash', splash),
    const AppScreenInfo('SCR-02', 'Đăng nhập', signIn),
    const AppScreenInfo('SCR-03', 'Đăng ký', signUp),
    const AppScreenInfo('SCR-04', 'Trang chủ', home),
    const AppScreenInfo('SCR-05', 'Khám phá', explore),
    AppScreenInfo(
      'SCR-06',
      'Chi tiết tin đăng',
      listingDetails('demo-listing'),
    ),
    const AppScreenInfo('SCR-07', 'Tài liệu của tôi', myMaterials),
    const AppScreenInfo('SCR-08', 'Tạo/sửa tài liệu', materialForm),
    AppScreenInfo(
      'SCR-09',
      'Chi tiết tài liệu và QR',
      materialDetails('demo-material'),
    ),
    const AppScreenInfo('SCR-10', 'Tạo/sửa tin đăng', listingForm),
    AppScreenInfo(
      'SCR-11',
      'Gửi yêu cầu trao đổi',
      createRequest('demo-listing'),
    ),
    const AppScreenInfo('SCR-12', 'Trung tâm yêu cầu', requestCenter),
    const AppScreenInfo('SCR-13', 'Giao dịch của tôi', transactions),
    AppScreenInfo(
      'SCR-14',
      'Chi tiết giao dịch',
      transactionDetails('demo-transaction'),
    ),
    const AppScreenInfo('SCR-15', 'Danh sách giao hộ', deliveries),
    const AppScreenInfo('SCR-16', 'Tạo nhiệm vụ giao hộ', createDelivery),
    AppScreenInfo('SCR-17', 'Chi tiết giao hộ', deliveryDetails('demo-task')),
    AppScreenInfo(
      'SCR-18',
      'Chuẩn bị bàn giao',
      prepareHandover('demo-handover'),
    ),
    AppScreenInfo('SCR-19', 'Quét QR', scanQr('demo-handover')),
    AppScreenInfo(
      'SCR-20',
      'Xác nhận nhận / từ chối',
      receiverAck('demo-handover'),
    ),
    const AppScreenInfo('SCR-21', 'Danh sách sự cố', issues),
    const AppScreenInfo('SCR-22', 'Báo cáo sự cố', createIssue),
    AppScreenInfo('SCR-23', 'Chi tiết sự cố', issueDetails('demo-issue')),
    const AppScreenInfo('SCR-24', 'Thông báo', notifications),
    const AppScreenInfo('SCR-25', 'Cá nhân', profile),
    const AppScreenInfo('SCR-26', 'Cài đặt', settings),
  ]);
}

// Dữ liệu nhỏ để hiển thị trang tra cứu đường dẫn khi phát triển.
class AppScreenInfo {
  const AppScreenInfo(this.code, this.title, this.previewPath);
  final String code;
  final String title;
  final String previewPath;
}

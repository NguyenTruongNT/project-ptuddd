import '../../../core/contracts/domain_enums.dart';
import '../../../core/errors/app_error.dart';

String requestStatusLabel(ExchangeRequestStatus status) => switch (status) {
  ExchangeRequestStatus.pending => 'Đang chờ duyệt',
  ExchangeRequestStatus.accepted => 'Đã được duyệt',
  ExchangeRequestStatus.rejected => 'Bị từ chối',
  ExchangeRequestStatus.cancelled => 'Đã rút',
};

String requestOfferLabel(OfferType type) => switch (type) {
  OfferType.borrow => 'Mượn',
  OfferType.sell => 'Mua',
  OfferType.donate => 'Nhận tặng',
};

/// Thông báo theo mã lỗi đã chốt của module Request.
/// Không hiển thị message SQL/backend thô; mã khác dùng thông báo chung đã an toàn.
String requestErrorMessage(DomainErrorCode code, String fallback) =>
    switch (code) {
      DomainErrorCode.duplicateRequest =>
        'Bạn đã có một yêu cầu đang chờ cho tin đăng này.',
      DomainErrorCode.materialUnavailable => 'Tài liệu hiện không thể nhận yêu cầu (đã được giữ chỗ hoặc ngừng chia sẻ).',
      DomainErrorCode.requestNotPending =>
        'Yêu cầu không còn ở trạng thái chờ. Danh sách đã được tải lại.',
      DomainErrorCode.duplicateActiveTransaction =>
        'Tài liệu đã có một giao dịch đang hoạt động.',
      _ => fallback,
    };

/// Ngày giờ theo giờ Việt Nam (UTC+7), không phụ thuộc múi giờ máy.
String formatVnDateTime(DateTime utc) {
  final vn = utc.toUtc().add(const Duration(hours: 7));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(vn.hour)}:${two(vn.minute)} ${two(vn.day)}/${two(vn.month)}/${vn.year}';
}

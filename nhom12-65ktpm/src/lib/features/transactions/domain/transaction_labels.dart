// Nhãn DẪN XUẤT cho phân hệ Transaction (SS-BR v2.0 §5, §11, MVP-D01).
// Chỉ phục vụ hiển thị: không đổi Transaction.status, không thay kiểm tra server.
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/transaction.dart';

// Việt Nam dùng UTC+7 cố định, không có giờ mùa hè.
const _vnOffset = Duration(hours: 7);

/// Ngày lịch Việt Nam (00:00, dạng UTC để so sánh) của một thời điểm server.
DateTime vnCalendarDate(DateTime instant) {
  final vn = instant.toUtc().add(_vnOffset);
  return DateTime.utc(vn.year, vn.month, vn.day);
}

/// Chuyển `yyyy-MM-dd` do server trả về thành ngày để so sánh.
DateTime? parseVnDate(String? raw) {
  if (raw == null) return null;
  final parts = raw.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime.utc(year, month, day);
}

String _two(int value) => value.toString().padLeft(2, '0');

/// `2026-11-28` -> `28/11/2026`.
String formatVnDate(String? raw) {
  final date = parseVnDate(raw);
  if (date == null) return '—';
  return '${_two(date.day)}/${_two(date.month)}/${date.year}';
}

/// Thời điểm server hiển thị theo giờ Việt Nam: `16:00 21/11/2026`.
String formatServerTimeVn(DateTime instant) {
  final vn = instant.toUtc().add(_vnOffset);
  return '${_two(vn.hour)}:${_two(vn.minute)} '
      '${_two(vn.day)}/${_two(vn.month)}/${vn.year}';
}

/// `90000` -> `90.000 đ`.
String formatVnd(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '$buffer đ';
}

String offerTypeLabelVi(OfferType type) => switch (type) {
  OfferType.borrow => 'Mượn',
  OfferType.sell => 'Bán',
  OfferType.donate => 'Tặng',
};

String statusLabelVi(TransactionStatus status) => switch (status) {
  TransactionStatus.awaitingPayment => 'Chờ xác nhận tiền',
  TransactionStatus.awaitingHandover => 'Chờ bàn giao',
  TransactionStatus.handoverInProgress => 'Đang bàn giao',
  TransactionStatus.borrowing => 'Đang mượn',
  TransactionStatus.returnPending => 'Chờ trả',
  TransactionStatus.returnInProgress => 'Đang trả',
  TransactionStatus.completed => 'Hoàn tất',
  TransactionStatus.cancelled => 'Đã hủy',
};

const _borrowActiveStatuses = {
  TransactionStatus.borrowing,
  TransactionStatus.returnPending,
  TransactionStatus.returnInProgress,
};

/// OVERDUE là nhãn suy ra (BR-21): quá hạn từ ngày lịch VN kế tiếp sau due_date.
/// Nếu B đã giao cho C chiều trả vào/trước hạn thì không tính trễ gốc (AC-11).
bool isOverdue(TransactionDetails details, DateTime nowUtc) {
  final txn = details.transaction;
  if (txn.type != OfferType.borrow) return false;
  if (!_borrowActiveStatuses.contains(txn.status)) return false;
  final due = parseVnDate(details.borrowing?.dueDateVn);
  if (due == null) return false;
  final handedToCourier = details.borrowing?.returnToCourierAt;
  if (handedToCourier != null && !vnCalendarDate(handedToCourier).isAfter(due)) {
    return false;
  }
  return vnCalendarDate(nowUtc).isAfter(due);
}

/// Quá hạn tái bàn giao 3 ngày sau C→B (REHANDOVER_OVERDUE, dẫn xuất).
bool isReHandoverOverdue(TransactionDetails details, DateTime nowUtc) {
  if (details.transaction.status.isTerminal) return false;
  final due = parseVnDate(details.borrowing?.reHandoverDueDateVn);
  if (due == null) return false;
  return vnCalendarDate(nowUtc).isAfter(due);
}

/// NEEDS_RESOLUTION là nhãn suy ra từ Issue OPEN (MVP-D01).
bool needsResolution(TransactionDetails details) => details.openIssueCount > 0;

bool hasPendingCancellation(TransactionDetails details) =>
    details.cancellationProposal != null;

/// Trạng thái đề nghị hủy theo góc nhìn người xem; rỗng khi không có đề nghị.
String cancellationStatusVi(TransactionDetails details) {
  final proposal = details.cancellationProposal;
  if (proposal == null) return '';
  return proposal.proposedBy == details.viewerRole
      ? 'Bạn đã đề nghị hủy. Đang chờ bên còn lại phản hồi.'
      : 'Bên còn lại đề nghị hủy giao dịch. Bạn có thể đồng ý hoặc không đồng ý.';
}

/// Tiến độ hoàn tiền khi hủy SELL đã được người bán xác nhận nhận tiền.
/// null khi không phát sinh nghĩa vụ hoàn tiền.
String? refundStatusVi(TransactionDetails details) {
  final payment = details.payment;
  if (details.transaction.type != OfferType.sell ||
      payment == null ||
      !payment.isSellerConfirmed) {
    return null;
  }
  if (payment.buyerRefundConfirmedAt != null) {
    return 'Người mua đã xác nhận nhận lại đủ tiền.';
  }
  if (payment.refundReportedAt != null) {
    return 'Người bán báo đã hoàn tiền – chờ người mua xác nhận đã nhận.';
  }
  return 'Người bán cần hoàn tiền ngoài ứng dụng trước khi hủy.';
}

/// Câu "đang chờ ai làm gì" theo vai trò người xem.
/// Không bao giờ nói "thanh toán thành công" khi chỉ có B báo chuyển khoản.
String waitingOnVi(TransactionDetails details) {
  final txn = details.transaction;
  final isOwner = details.viewerRole == TransactionViewerRole.owner;
  final due = formatVnDate(details.borrowing?.dueDateVn);

  switch (txn.status) {
    case TransactionStatus.awaitingPayment:
      final reported = details.payment?.buyerReportedAt != null;
      if (isOwner) {
        return reported
            ? 'Người mua đã báo chuyển khoản. Bạn hãy tự kiểm tra tài khoản '
                'rồi xác nhận đã nhận tiền.'
            : 'Đang chờ người mua chuyển khoản.';
      }
      return reported
          ? 'Bạn đã báo chuyển khoản. Đang chờ người bán xác nhận đã nhận tiền.'
          : 'Hãy chuyển khoản theo thông tin của người bán rồi báo đã chuyển.';
    case TransactionStatus.awaitingHandover:
      return isOwner
          ? 'Bạn cần bắt đầu bàn giao tài liệu.'
          : 'Đang chờ người đăng bàn giao tài liệu.';
    case TransactionStatus.handoverInProgress:
      return 'Đang bàn giao – chờ người nhận xác nhận từng chặng.';
    case TransactionStatus.borrowing:
      return isOwner
          ? 'Người mượn đang giữ tài liệu – hạn trả $due.'
          : 'Bạn đang mượn – hạn trả $due.';
    case TransactionStatus.returnPending:
      return isOwner
          ? 'Người mượn đã báo trả – chờ bàn giao trả.'
          : 'Bạn đã báo trả – hãy bắt đầu bàn giao trả.';
    case TransactionStatus.returnInProgress:
      return isOwner
          ? 'Đang trả – bạn xác nhận khi nhận lại đúng tài liệu.'
          : 'Đang trả – chờ chủ tài liệu xác nhận nhận lại.';
    case TransactionStatus.completed:
      return 'Giao dịch đã hoàn tất.';
    case TransactionStatus.cancelled:
      return 'Giao dịch đã hủy.';
  }
}

/// Ba tab của SCR-13. Tab "Có sự cố" là bộ lọc, có thể trùng với tab khác.
enum TransactionTab { active, completed, withIssue }

String transactionTabLabelVi(TransactionTab tab) => switch (tab) {
  TransactionTab.active => 'Đang xử lý',
  TransactionTab.completed => 'Đã kết thúc',
  TransactionTab.withIssue => 'Có sự cố',
};

bool belongsToTab(TransactionDetails details, TransactionTab tab) =>
    switch (tab) {
      TransactionTab.active => !details.transaction.status.isTerminal,
      TransactionTab.completed => details.transaction.status.isTerminal,
      TransactionTab.withIssue => needsResolution(details),
    };

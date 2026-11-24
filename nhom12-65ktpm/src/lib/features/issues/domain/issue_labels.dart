// Nhãn hiển thị cho phân hệ Issue (SS-BR v2.0 §9).
// Chỉ phục vụ hiển thị: không đổi Issue.status, không thay kiểm tra server.
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/issue.dart';

String issueTypeLabelVi(IssueType type) => switch (type) {
  IssueType.wrongMaterial => 'Sai tài liệu',
  IssueType.wrongCondition => 'Sai tình trạng / hư hỏng',
  IssueType.notReceived => 'Chưa nhận được tài liệu',
  IssueType.deliveryFailed => 'Giao thất bại',
  IssueType.uncooperative => 'Bên còn lại không hợp tác',
  IssueType.other => 'Khác',
};

String issueStatusLabelVi(IssueStatus status) => switch (status) {
  IssueStatus.open => 'Đang mở',
  IssueStatus.resolved => 'Đã giải quyết',
};

// Phương án đang chờ chính người xem xác nhận -> dấu "Cần phản hồi" ở SCR-21.
// Chỉ là gợi ý từ allowedActions; server vẫn kiểm tra lại khi gọi lệnh.
bool needsMyResponse(IssueDetails details) =>
    details.issue.isOpen && details.can(IssueAction.confirmResolution);

String issueRelationLabelVi(IssueDetails details) =>
    details.relation == IssueRelation.reporter
        ? 'Bạn là người báo'
        : '${details.reporterDisplayName} báo sự cố';

// Câu giải thích trạng thái xử lý cho người xem.
String issueProgressVi(IssueDetails details) {
  if (!details.issue.isOpen) return 'Các bên đã thống nhất phương án giải quyết.';
  final proposal = details.proposal;
  if (proposal == null) {
    return 'Chưa có phương án giải quyết. Hãy đề xuất để các bên xác nhận.';
  }
  if (needsMyResponse(details)) return 'Phương án đang chờ bạn xác nhận.';
  return 'Đã xác nhận ${proposal.approvedCount}/${proposal.consents.length} bên. '
      'Chờ bên còn lại.';
}

// Tab của SCR-21.
enum IssueTab { open, resolved }

String issueTabLabelVi(IssueTab tab) => switch (tab) {
  IssueTab.open => 'Đang mở',
  IssueTab.resolved => 'Đã giải quyết',
};

bool belongsToIssueTab(IssueDetails details, IssueTab tab) => switch (tab) {
  IssueTab.open => details.issue.isOpen,
  IssueTab.resolved => !details.issue.isOpen,
};

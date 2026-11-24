// Issue chỉ có OPEN/RESOLVED; xử lý tranh chấp thật cần các bên đồng thuận ở server.
import '../domain_enums.dart';

class Issue {
  const Issue({
    required this.id,
    required this.transactionId,
    required this.reporterId,
    required this.type,
    required this.reason,
    required this.status,
    required this.openedAt,
    this.handoverId,
    this.resolvedAt,
  });

  final String id;
  final String transactionId;
  final String reporterId;
  final IssueType type;
  final String reason;
  final String? handoverId;
  final IssueStatus status;
  final DateTime openedAt;
  // Chỉ có khi status = RESOLVED; do server ghi sau khi đủ xác nhận.
  final DateTime? resolvedAt;

  bool get isOpen => status == IssueStatus.open;
}

// Người xem là bên báo hay bên còn lại của giao dịch (server suy ra từ auth.uid()).
enum IssueRelation { reporter, counterparty }

// Hành động mà server GỢI Ý cho actor hiện tại (CONTRACTS.md §3).
// UI chỉ dùng để bật/tắt nút; RPC luôn kiểm tra lại quyền và trạng thái.
enum IssueAction {
  proposeResolution('CAN_PROPOSE_ISSUE_RESOLUTION'),
  confirmResolution('CAN_CONFIRM_ISSUE_RESOLUTION');

  const IssueAction(this.wire);
  final String wire;

  static IssueAction fromWire(String raw) {
    for (final value in values) {
      if (value.wire == raw) return value;
    }
    throw FormatException('Hành động sự cố không hợp lệ: $raw');
  }
}

// Xác nhận của MỘT bên bị ảnh hưởng đối với phương án hiện hành.
// Chỉ có tên hiển thị snapshot, không lộ ID người dùng khác.
class IssueConsent {
  const IssueConsent({required this.participantDisplayName, this.approvedAt});

  final String participantDisplayName;
  final DateTime? approvedAt;

  bool get isApproved => approvedAt != null;
}

// Phương án giải quyết đang chờ xác nhận (snapshot theo revision).
// Đề xuất mới tăng revision và làm mất hiệu lực các xác nhận của revision cũ.
// Việc đề xuất KHÔNG tự tính là xác nhận của người đề xuất.
class IssueResolutionProposal {
  const IssueResolutionProposal({
    required this.revision,
    required this.summary,
    required this.proposedByDisplayName,
    required this.proposedAt,
    required this.consents,
  });

  final int revision;
  final String summary;
  final String proposedByDisplayName;
  final DateTime proposedAt;
  // Mỗi bên bị ảnh hưởng một dòng, đã xác nhận hoặc chưa.
  final List<IssueConsent> consents;

  int get approvedCount => consents.where((consent) => consent.isApproved).length;

  // Gợi ý hiển thị; chỉ server mới chuyển Issue sang RESOLVED.
  bool get isFullyApproved =>
      consents.isNotEmpty && approvedCount == consents.length;
}

// Sự kiện trong timeline của một Issue (append-only, đã loại PII).
class IssueEventItem {
  const IssueEventItem({
    required this.id,
    required this.issueId,
    required this.eventType,
    required this.serverAt,
    required this.safeDescription,
    this.actorDisplay,
  });

  final String id;
  final String issueId;
  final String eventType;
  final DateTime serverAt;
  final String safeDescription;
  // Tên hiển thị snapshot của actor do server cung cấp; null khi do hệ thống.
  final String? actorDisplay;
}

// Read model cho SCR-21/SCR-23. Không chứa đường dẫn ảnh private; ảnh chỉ
// được mở qua signed URL sau khi server kiểm tra quyền (canViewEvidence).
class IssueDetails {
  const IssueDetails({
    required this.issue,
    required this.materialTitle,
    required this.reporterDisplayName,
    required this.counterpartyDisplayName,
    required this.relation,
    this.proposal,
    this.evidenceCount = 0,
    this.canViewEvidence = false,
    this.allowedActions = const {},
  });

  final Issue issue;
  final String materialTitle;
  final String reporterDisplayName;
  final String counterpartyDisplayName;
  final IssueRelation relation;
  final IssueResolutionProposal? proposal; // Phương án hiện hành, nếu đã có.
  final int evidenceCount;
  final bool canViewEvidence;
  final Set<IssueAction> allowedActions;

  String get id => issue.id;

  bool can(IssueAction action) => allowedActions.contains(action);
}

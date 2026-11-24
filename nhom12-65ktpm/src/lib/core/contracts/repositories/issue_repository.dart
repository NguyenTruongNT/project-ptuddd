// Không cho admin tự đóng Issue; server kiểm tra đồng thuận theo revision.
import '../command_inputs.dart';
import '../command_result.dart';
import '../models/issue.dart';

abstract interface class IssueQueryRepository {
  // Chỉ Issue thuộc giao dịch mà actor đăng nhập là A hoặc B.
  Future<List<IssueDetails>> getMyIssues();
  // null khi không tồn tại HOẶC không có quyền: không phân biệt để tránh lộ dữ liệu.
  Future<IssueDetails?> getIssueDetails(String issueId);
  // Sự kiện server, sắp xếp tăng dần theo serverAt; rỗng khi không có quyền.
  Future<List<IssueEventItem>> getTimeline(String issueId);
}

// Mọi lệnh trả snapshot Issue mới nhất để UI tải lại từ server, không tự sửa state.
abstract interface class IssueRepository {
  // Mở Issue; không đổi holder, owner, due_date hay payment (INV-10).
  Future<CommandResult<IssueDetails>> reportIssue(
    CreateIssueInput input, {required String idempotencyKey});

  // Đề xuất phương án; tăng revision và vô hiệu các xác nhận cũ.
  // Đề xuất không tự là xác nhận của người đề xuất.
  Future<CommandResult<IssueDetails>> proposeResolution(
    String issueId, String summary, {required String idempotencyKey});

  // Xác nhận đúng revision đang hiển thị; sai revision trả CONFLICT.
  // Chỉ khi mọi bên bị ảnh hưởng xác nhận, server mới chuyển RESOLVED.
  Future<CommandResult<IssueDetails>> confirmResolution(
    String issueId, int resolutionRevision, {required String idempotencyKey});
}

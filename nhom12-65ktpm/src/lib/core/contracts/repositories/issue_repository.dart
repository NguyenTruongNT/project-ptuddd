// Không cho admin tự đóng Issue; server kiểm tra đồng thuận theo revision.
import '../command_inputs.dart';
import '../command_result.dart';
import '../models/issue.dart';

abstract interface class IssueQueryRepository {
  Future<List<Issue>> getMyIssues();
}

abstract interface class IssueRepository {
  Future<CommandResult<Issue>> reportIssue(
    CreateIssueInput input, {required String idempotencyKey});
  Future<CommandResult<Issue>> confirmResolution(
    String issueId, int resolutionRevision, {required String idempotencyKey});
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/models/issue.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../../core/contracts/repositories/issue_repository.dart';
import '../../../core/providers/mock_query_providers.dart';
import '../../../core/backend/workflow_rpc.dart';
import '../data/supabase_issue_repository.dart';
import '../../transactions/providers/transaction_providers.dart';
import '../data/mock_issue_command_runner.dart';
import '../data/mock_issue_repository.dart';

// ---------- Repository (interface) ----------
// Trang chỉ phụ thuộc interface. Bản Supabase override các provider này.
final issueReadRepositoryProvider = Provider<IssueQueryRepository>(
  (ref) => ref.watch(issueQueryRepositoryProvider),
);

final _mockIssueRunnerProvider = Provider<MockIssueCommandRunner>(
  (ref) => MockIssueCommandRunner(
    store: ref.watch(mockTransactionStoreProvider),
    actorId: ref.watch(demoViewerIdProvider),
  ),
);

final issueRepositoryProvider = Provider<IssueRepository>((ref) {
  final rpc = ref.watch(workflowRpcProvider);
  return rpc == null
      ? MockIssueRepository(ref.watch(_mockIssueRunnerProvider))
      : SupabaseIssueRepository(rpc);
});

// ---------- Dữ liệu đọc ----------
final myIssuesProvider = FutureProvider<List<IssueDetails>>((ref) async {
  final items = await ref.watch(issueReadRepositoryProvider).getMyIssues();
  // Mới mở nhất lên đầu để người dùng thấy việc vừa phát sinh.
  final sorted = [...items]
    ..sort((a, b) => b.issue.openedAt.compareTo(a.issue.openedAt));
  return List.unmodifiable(sorted);
});

final issueDetailsProvider = FutureProvider.family<IssueDetails?, String>(
  (ref, issueId) =>
      ref.watch(issueReadRepositoryProvider).getIssueDetails(issueId),
);

final issueTimelineProvider =
    FutureProvider.family<List<IssueEventItem>, String>(
      (ref, issueId) =>
          ref.watch(issueReadRepositoryProvider).getTimeline(issueId),
    );

// Giao dịch mà SCR-22 gắn Issue vào; null khi không tồn tại hoặc không có quyền.
final issueTransactionContextProvider =
    FutureProvider.family<TransactionDetails?, String>(
      (ref, transactionId) => ref
          .watch(transactionQueryRepositoryProvider)
          .getTransactionDetails(transactionId),
    );

/// Sau mỗi lệnh (thành công hay lỗi) tải lại snapshot server, không tự sửa UI.
/// Issue đổi nhãn "Có sự cố" của giao dịch nên cũng phải tải lại giao dịch.
void refreshIssue(WidgetRef ref, {String? issueId, String? transactionId}) {
  if (issueId != null) {
    ref.invalidate(issueDetailsProvider(issueId));
    ref.invalidate(issueTimelineProvider(issueId));
  }
  ref.invalidate(myIssuesProvider);
  if (transactionId != null) {
    ref.invalidate(issueTransactionContextProvider(transactionId));
    refreshTransaction(ref, transactionId);
  }
}

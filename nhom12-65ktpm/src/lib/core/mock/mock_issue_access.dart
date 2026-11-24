import '../contracts/models/models.dart';
import 'mock_transaction_store.dart';

// Phạm vi người liên quan của Issue (SS-BR §9.3, STATE_MACHINES.md §8, CONTRACTS.md §8).
// Mock mô phỏng quy tắc để UI/test dùng chung; Supabase phải thực thi bằng RLS/RPC.
//
// - ĐỌC: A/B của giao dịch, cộng các bên bị ảnh hưởng trực tiếp (vd. C ở đúng chặng).
//   Không mở Issue cho mọi courier, và C không đọc được Issue của chặng khác.
// - GHI (đề xuất/xác nhận phương án): chỉ các bên bị ảnh hưởng trực tiếp.
//
// Bên bị ảnh hưởng trực tiếp:
//   * Issue gắn một chặng (handover): hai đầu của chặng đó (giao và nhận);
//   * Issue cấp giao dịch: A và B;
//   * luôn gồm người báo, vì họ đã tự nêu mình bị ảnh hưởng.

/// Hai đầu của chặng bàn giao mà Issue gắn vào; rỗng nếu Issue cấp giao dịch
/// hoặc chặng không thuộc giao dịch đó.
List<String> handoverParties(
  MockTransactionStore store,
  String transactionId,
  String? handoverId,
) {
  if (handoverId == null) return const [];
  final handover = store.handover(handoverId);
  if (handover == null || handover.transactionId != transactionId) {
    return const [];
  }
  return [handover.fromUserId, handover.toUserId];
}

/// Các bên cần xác nhận phương án, theo thứ tự ổn định (không trùng lặp).
List<String> issueAffectedParties(MockTransactionStore store, Issue issue) {
  final txn = store.transaction(issue.transactionId);
  if (txn == null) return [issue.reporterId];
  final base = handoverParties(store, issue.transactionId, issue.handoverId);
  final parties = base.isNotEmpty ? base : [txn.ownerAtAcceptance, txn.receiverId];
  return {...parties, issue.reporterId}.toList(growable: false);
}

bool _isTransactionParty(StudyTransaction txn, String userId) =>
    txn.ownerAtAcceptance == userId || txn.receiverId == userId;

/// Người dùng có được xem giao dịch (SCR-14) hay không; C thì không.
bool canViewIssueTransaction(StudyTransaction txn, String userId) =>
    _isTransactionParty(txn, userId);

/// Quyền ĐỌC Issue.
bool canReadIssue(MockTransactionStore store, Issue issue, String userId) {
  final txn = store.transaction(issue.transactionId);
  if (txn == null) return false;
  return _isTransactionParty(txn, userId) ||
      issueAffectedParties(store, issue).contains(userId);
}

/// Quyền đề xuất/xác nhận phương án: chỉ bên bị ảnh hưởng trực tiếp.
bool canActOnIssue(MockTransactionStore store, Issue issue, String userId) =>
    issueAffectedParties(store, issue).contains(userId);

/// Quyền MỞ Issue mới: A/B của giao dịch, hoặc một đầu của chặng được gắn vào.
bool canReportIssue(
  MockTransactionStore store,
  StudyTransaction txn,
  String? handoverId,
  String userId,
) =>
    _isTransactionParty(txn, userId) ||
    handoverParties(store, txn.id, handoverId).contains(userId);

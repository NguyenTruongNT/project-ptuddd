import '../contracts/models/models.dart';
import 'mock_issue_access.dart';
import 'mock_transaction_store.dart';

// Mô phỏng phần server sinh thông báo từ Event (CONTRACTS.md §7 bước 4:
// Event + notification queue ghi nguyên tử trong cùng lệnh). Backend thật
// CHƯA có phần này; quy tắc dưới đây cũng là nội dung đề xuất cho nhóm trưởng.
//
// - Event giao dịch: gửi A và B của giao dịch.
// - Event Issue: gửi mọi người được đọc Issue (A/B + bên bị ảnh hưởng ở chặng).
// - Không gửi cho chính người thực hiện lệnh.
// - Event ISSUE_* ở nhật ký giao dịch bị bỏ qua vì Event Issue tương ứng đã
//   báo, tránh một việc sinh hai thông báo.
// - Preview chỉ gồm tên tài liệu + mô tả an toàn của Event, không có bằng
//   chứng, số tài khoản hay nội dung riêng tư.
void fanOutNotifications(
  MockTransactionStore store,
  MockEventMark since,
  String actorId,
) {
  for (final event in store.transactionEventsSince(since)) {
    if (event.eventType.startsWith('ISSUE_')) continue;
    final txn = store.transaction(event.transactionId);
    if (txn == null) continue;
    _send(
      store,
      recipients: {txn.ownerAtAcceptance, txn.receiverId},
      actorId: actorId,
      type: event.eventType,
      entityType: NotificationEntityType.transaction,
      entityId: txn.id,
      preview: _preview(store, txn, event.safeDescription),
    );
  }
  for (final event in store.issueEventsSince(since)) {
    final issue = store.issue(event.issueId);
    final txn = issue == null ? null : store.transaction(issue.transactionId);
    if (issue == null || txn == null) continue;
    _send(
      store,
      recipients: {
        txn.ownerAtAcceptance,
        txn.receiverId,
        ...issueAffectedParties(store, issue),
      }.where((user) => canReadIssue(store, issue, user)).toSet(),
      actorId: actorId,
      type: event.eventType,
      entityType: NotificationEntityType.issue,
      entityId: issue.id,
      preview: _preview(store, txn, event.safeDescription),
    );
  }
}

void _send(
  MockTransactionStore store, {
  required Set<String> recipients,
  required String actorId,
  required String type,
  required NotificationEntityType entityType,
  required String entityId,
  required String preview,
}) {
  for (final recipient in recipients) {
    if (recipient == actorId) continue;
    store.appendNotification(
      recipientId: recipient,
      type: type,
      entityType: entityType,
      entityId: entityId,
      safePreview: preview,
    );
  }
}

String _preview(
  MockTransactionStore store,
  StudyTransaction txn,
  String description,
) {
  final title = store.material(txn.materialId)?.title;
  return title == null ? description : '$title: $description';
}

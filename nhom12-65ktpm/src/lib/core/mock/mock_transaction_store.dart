import '../contracts/domain_enums.dart';
import '../contracts/models/models.dart';
import 'mock_fixtures.dart';

// "Database" mô phỏng trong bộ nhớ cho phân hệ Transaction khi chưa có Supabase.
// - Khởi tạo từ MockFixtures, KHÔNG sửa fixture gốc (ID cố định cho cả nhóm).
// - Chỉ các mock command repository (giả lập RPC server) được gọi hàm ghi.
// - Mất khi khởi động lại app; không phải nguồn sự thật.
class MockTransactionStore {
  MockTransactionStore.fromFixtures({
    DateTime Function()? clock,
    List<Issue>? seedIssues,
  })  : clock = clock ?? (() => DateTime.now().toUtc()),
        _issues = {
          for (final issue in seedIssues ?? MockFixtures.issues)
            issue.id: issue,
        },
        _transactions = {
          for (final txn in MockFixtures.transactions) txn.id: txn,
        },
        _payments = {
          for (final payment in MockFixtures.payments)
            payment.transactionId: payment,
        },
        _events = [...MockFixtures.transactionEvents];

  // Đồng hồ "server" của mock; test truyền vào để có thời gian cố định.
  final DateTime Function() clock;

  final Map<String, StudyTransaction> _transactions;
  final Map<String, PaymentConfirmation> _payments;
  final List<TransactionEventItem> _events;
  final Map<String, CancellationProposal> _cancellations = {};
  final Map<String, MockCommandReceipt> _receipts = {};
  // Issue nằm cùng store với Transaction vì openIssueCount phải phản ánh Issue mới tạo.
  final Map<String, Issue> _issues;
  final Map<String, MockIssueProposal> _issueProposals = {};
  final List<IssueEventItem> _issueEvents = [];
  int _eventCounter = 0;
  int _issueCounter = 0;
  int _issueEventCounter = 0;

  // ---------- Đọc ----------
  List<StudyTransaction> get transactions =>
      List.unmodifiable(_transactions.values);

  StudyTransaction? transaction(String id) => _transactions[id];

  PaymentConfirmation? payment(String transactionId) =>
      _payments[transactionId];

  CancellationProposal? cancellation(String transactionId) =>
      _cancellations[transactionId];

  List<TransactionEventItem> events(String transactionId) => List.unmodifiable(
        _events.where((event) => event.transactionId == transactionId),
      );

  Material? material(String materialId) {
    for (final item in MockFixtures.materials) {
      if (item.id == materialId) return item;
    }
    return null;
  }

  int openIssueCount(String transactionId) => _issues.values
      .where((issue) =>
          issue.transactionId == transactionId &&
          issue.status == IssueStatus.open)
      .length;

  List<Issue> get issues => List.unmodifiable(_issues.values);

  Issue? issue(String id) => _issues[id];

  // Phương án giải quyết hiện hành của Issue; null khi chưa ai đề xuất.
  MockIssueProposal? issueProposal(String issueId) => _issueProposals[issueId];

  List<IssueEventItem> issueEvents(String issueId) => List.unmodifiable(
        _issueEvents.where((event) => event.issueId == issueId),
      );

  // Mốc sự kiện mới nhất của giao dịch; mock dùng làm mốc hoàn tất để tính hạn
  // khiếu nại 7 ngày (server thật dùng thời điểm ACK cuối cùng). Bỏ qua sự kiện
  // ISSUE_*: mở Issue không được tự kéo dài hạn khiếu nại.
  DateTime? lastEventAt(String transactionId) {
    DateTime? latest;
    for (final event in events(transactionId)) {
      if (event.eventType.startsWith('ISSUE_')) continue;
      if (latest == null || event.serverAt.isAfter(latest)) {
        latest = event.serverAt;
      }
    }
    return latest;
  }

  // Handover chưa kết thúc nghĩa là sách có thể đang trên đường.
  bool hasActiveHandover(String transactionId) => MockFixtures.handovers.any(
        (handover) =>
            handover.transactionId == transactionId &&
            (handover.status == HandoverStatus.pending ||
                handover.status == HandoverStatus.awaitingReceiverConfirmation),
      );

  bool hasActiveDeliveryTask(String transactionId) =>
      MockFixtures.deliveryTasks.any(
        (task) =>
            task.transactionId == transactionId &&
            task.status != DeliveryTaskStatus.completed &&
            task.status != DeliveryTaskStatus.failed &&
            task.status != DeliveryTaskStatus.cancelled,
      );

  MockCommandReceipt? receipt(String actorId, String command, String key) =>
      _receipts[_receiptKey(actorId, command, key)];

  // ---------- Ghi (chỉ dành cho mock command repository) ----------
  void setStatus(String transactionId, TransactionStatus status) {
    final txn = _transactions[transactionId]!;
    _transactions[transactionId] = StudyTransaction(
      id: txn.id,
      listingId: txn.listingId,
      requestId: txn.requestId,
      materialId: txn.materialId,
      type: txn.type,
      ownerAtAcceptance: txn.ownerAtAcceptance,
      receiverId: txn.receiverId,
      status: status,
      agreedBorrowDays: txn.agreedBorrowDays,
      agreedPriceVnd: txn.agreedPriceVnd,
    );
  }

  void putPayment(PaymentConfirmation payment) =>
      _payments[payment.transactionId] = payment;

  String nextIssueId() => 'issue-mock-${++_issueCounter}';

  void putIssue(Issue issue) => _issues[issue.id] = issue;

  void putIssueProposal(String issueId, MockIssueProposal proposal) =>
      _issueProposals[issueId] = proposal;

  /// Ghi một sự kiện append-only của Issue, trả về event ID.
  String appendIssueEvent({
    required String issueId,
    required String eventType,
    required String safeDescription,
    String? actorDisplay,
  }) {
    final id = 'iev-mock-${++_issueEventCounter}';
    _issueEvents.add(IssueEventItem(
      id: id,
      issueId: issueId,
      eventType: eventType,
      serverAt: clock(),
      safeDescription: safeDescription,
      actorDisplay: actorDisplay,
    ));
    return id;
  }

  void putCancellation(String transactionId, CancellationProposal? proposal) {
    if (proposal == null) {
      _cancellations.remove(transactionId);
    } else {
      _cancellations[transactionId] = proposal;
    }
  }

  /// Ghi một TransactionEvent append-only, trả về event ID.
  String appendEvent({
    required String transactionId,
    required String eventType,
    required String safeDescription,
    String? actorDisplay,
  }) {
    _eventCounter++;
    final id = 'evt-mock-$_eventCounter';
    _events.add(TransactionEventItem(
      id: id,
      transactionId: transactionId,
      eventType: eventType,
      serverAt: clock(),
      safeDescription: safeDescription,
      actorDisplay: actorDisplay,
    ));
    return id;
  }

  void saveReceipt(String actorId, String command, String key,
      MockCommandReceipt receipt) {
    _receipts[_receiptKey(actorId, command, key)] = receipt;
  }

  static String _receiptKey(String actorId, String command, String key) =>
      '$actorId|$command|$key';
}

// Tương ứng bảng command_receipts: retry cùng key + payload trả lại kết quả cũ.
class MockCommandReceipt {
  const MockCommandReceipt({
    required this.payloadHash,
    required this.eventId,
    this.entityId,
  });
  final String payloadHash;
  final String eventId;
  // Đối tượng do lệnh tạo ra (vd. Issue mới) để retry trả lại đúng bản ghi cũ.
  final String? entityId;
}

// Phương án giải quyết Issue theo revision và các xác nhận đi kèm.
// Đề xuất mới thay thế bản cũ với revision tăng dần, xác nhận cũ mất hiệu lực.
class MockIssueProposal {
  const MockIssueProposal({
    required this.revision,
    required this.summary,
    required this.proposedBy,
    required this.proposedAt,
    this.approvals = const {},
  });

  final int revision;
  final String summary;
  final String proposedBy;
  final DateTime proposedAt;
  // userId -> thời điểm xác nhận của revision hiện hành.
  final Map<String, DateTime> approvals;

  MockIssueProposal withApproval(String userId, DateTime at) =>
      MockIssueProposal(
        revision: revision,
        summary: summary,
        proposedBy: proposedBy,
        proposedAt: proposedAt,
        approvals: Map.unmodifiable({...approvals, userId: at}),
      );
}

import '../contracts/domain_enums.dart';
import '../contracts/models/models.dart';
import 'mock_fixtures.dart';

// "Database" mô phỏng trong bộ nhớ cho phân hệ Transaction khi chưa có Supabase.
// - Khởi tạo từ MockFixtures, KHÔNG sửa fixture gốc (ID cố định cho cả nhóm).
// - Chỉ các mock command repository (giả lập RPC server) được gọi hàm ghi.
// - Mất khi khởi động lại app; không phải nguồn sự thật.
class MockTransactionStore {
  MockTransactionStore.fromFixtures({DateTime Function()? clock})
      : clock = clock ?? (() => DateTime.now().toUtc()),
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
  int _eventCounter = 0;

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

  int openIssueCount(String transactionId) => MockFixtures.issues
      .where((issue) =>
          issue.transactionId == transactionId &&
          issue.status == IssueStatus.open)
      .length;

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
  const MockCommandReceipt({required this.payloadHash, required this.eventId});
  final String payloadHash;
  final String eventId;
}

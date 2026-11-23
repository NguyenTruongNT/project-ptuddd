import '../contracts/domain_enums.dart';
import '../contracts/models/models.dart';
import '../contracts/repositories/transaction_repository.dart';
import 'mock_fixtures.dart';

// Mock CHỈ ĐỌC. allowedActions ở đây mô phỏng gợi ý của server,
// không phải quyết định cuối: RPC thật vẫn phải kiểm tra lại.
class MockTransactionQueryRepository implements TransactionQueryRepository {
  const MockTransactionQueryRepository({required this.demoViewerId});

  final String demoViewerId;

  // Chỉ A hoặc B; C không xem toàn bộ Transaction chỉ vì là courier.
  bool _canSee(StudyTransaction txn) =>
      txn.ownerAtAcceptance == demoViewerId || txn.receiverId == demoViewerId;

  @override
  Future<List<TransactionDetails>> getMyTransactions() async =>
      List.unmodifiable(
        MockFixtures.transactions.where(_canSee).map(_toDetails),
      );

  @override
  Future<TransactionDetails?> getTransactionDetails(String transactionId) async {
    for (final txn in MockFixtures.transactions) {
      if (txn.id == transactionId && _canSee(txn)) return _toDetails(txn);
    }
    return null; // Không lộ thông tin giao dịch cho người không liên quan.
  }

  @override
  Future<List<TransactionEventItem>> getTimeline(String transactionId) async {
    final details = await getTransactionDetails(transactionId);
    if (details == null) return const []; // Không có quyền -> không trả gì.
    final events = MockFixtures.transactionEvents
        .where((event) => event.transactionId == transactionId)
        .toList()
      ..sort((a, b) {
        final byTime = a.serverAt.compareTo(b.serverAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return List.unmodifiable(events);
  }

  TransactionDetails _toDetails(StudyTransaction txn) {
    final material =
        MockFixtures.materials.firstWhere((item) => item.id == txn.materialId);
    final borrowing = _firstOrNull(
      MockFixtures.borrowingRecords,
      (BorrowingRecord item) => item.transactionId == txn.id,
    );
    final payment = _firstOrNull(
      MockFixtures.payments,
      (PaymentConfirmation item) => item.transactionId == txn.id,
    );
    final openIssues = MockFixtures.issues
        .where((issue) =>
            issue.transactionId == txn.id && issue.status == IssueStatus.open)
        .length;
    final role = txn.ownerAtAcceptance == demoViewerId
        ? TransactionViewerRole.owner
        : TransactionViewerRole.receiver;

    return TransactionDetails(
      transaction: txn,
      materialTitle: material.title,
      materialSubject: material.subject,
      ownerDisplayName:
          MockFixtures.displayNames[txn.ownerAtAcceptance] ?? 'Người dùng',
      receiverDisplayName:
          MockFixtures.displayNames[txn.receiverId] ?? 'Người dùng',
      viewerRole: role,
      createdAt: MockFixtures.transactionCreatedAt[txn.id] ??
          DateTime.utc(2026, 11, 20),
      borrowing: txn.type == OfferType.borrow ? borrowing : null,
      payment: txn.type == OfferType.sell ? payment : null,
      openIssueCount: openIssues,
      allowedActions: _allowedActions(txn, role, payment),
    );
  }

  // Mô phỏng bảng quyền của SS-BR v2.0 ở mức gợi ý UI.
  Set<TransactionAction> _allowedActions(
    StudyTransaction txn,
    TransactionViewerRole role,
    PaymentConfirmation? payment,
  ) {
    if (txn.status.isTerminal) return const {};
    final isOwner = role == TransactionViewerRole.owner;
    final actions = <TransactionAction>{
      TransactionAction.reportIssue,
      TransactionAction.proposeCancellation,
    };

    switch (txn.type) {
      case OfferType.sell:
        final sellerConfirmed = payment?.isSellerConfirmed ?? false;
        if (txn.status == TransactionStatus.awaitingPayment) {
          // Chỉ A xác nhận tiền; B chỉ được báo đã chuyển khoản.
          if (isOwner) actions.add(TransactionAction.confirmSellerPayment);
          if (!isOwner && payment?.buyerReportedAt == null) {
            actions.add(TransactionAction.reportBuyerTransfer);
          }
        }
        // BR-29: không có Handover SELL nào trước khi A xác nhận tiền.
        if (sellerConfirmed &&
            txn.status == TransactionStatus.awaitingHandover &&
            isOwner) {
          actions.add(TransactionAction.startHandover);
        }
      case OfferType.donate:
        if (txn.status == TransactionStatus.awaitingHandover && isOwner) {
          actions.add(TransactionAction.startHandover);
        }
      case OfferType.borrow:
        if (txn.status == TransactionStatus.awaitingHandover && isOwner) {
          actions.add(TransactionAction.startHandover);
        }
        if (txn.status == TransactionStatus.borrowing && !isOwner) {
          actions.add(TransactionAction.requestReturn);
        }
        // Chiều trả: B là người đang giữ sách nên B mở chặng trả.
        if (txn.status == TransactionStatus.returnPending && !isOwner) {
          actions.add(TransactionAction.startHandover);
        }
    }
    return Set.unmodifiable(actions);
  }

  static T? _firstOrNull<T>(List<T> items, bool Function(T) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }
}

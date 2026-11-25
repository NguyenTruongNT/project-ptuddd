import '../contracts/domain_enums.dart';
import '../contracts/models/models.dart';
import '../contracts/repositories/transaction_repository.dart';
import 'mock_event_order.dart';
import 'mock_fixtures.dart';
import 'mock_issue_access.dart';
import 'mock_transaction_store.dart';

// Repository ĐỌC. allowedActions ở đây mô phỏng gợi ý của server,
// không phải quyết định cuối: RPC/mock command vẫn kiểm tra lại.
class MockTransactionQueryRepository implements TransactionQueryRepository {
  MockTransactionQueryRepository({
    required this.demoViewerId,
    MockTransactionStore? store,
  }) : store = store ?? MockTransactionStore.fromFixtures();

  final String demoViewerId;
  final MockTransactionStore store;

  // Chỉ A hoặc B; C không xem toàn bộ Transaction chỉ vì là courier.
  bool _canSee(StudyTransaction txn) =>
      txn.ownerAtAcceptance == demoViewerId || txn.receiverId == demoViewerId;

  @override
  Future<List<TransactionDetails>> getMyTransactions() async =>
      List.unmodifiable(store.transactions.where(_canSee).map(_toDetails));

  @override
  Future<TransactionDetails?> getTransactionDetails(String transactionId) async {
    final txn = store.transaction(transactionId);
    if (txn == null || !_canSee(txn)) return null; // Không lộ dữ liệu.
    return _toDetails(txn);
  }

  @override
  Future<List<TransactionEventItem>> getTimeline(String transactionId) async {
    final details = await getTransactionDetails(transactionId);
    if (details == null) return const []; // Không có quyền -> không trả gì.
    return List.unmodifiable(sortedByServerOrder<TransactionEventItem>(
      store.events(transactionId),
      (event) => event.serverAt,
    ));
  }

  TransactionDetails _toDetails(StudyTransaction txn) {
    final material = store.material(txn.materialId);
    final borrowing = _firstOrNull(
      MockFixtures.borrowingRecords,
      (BorrowingRecord item) => item.transactionId == txn.id,
    );
    final payment = store.payment(txn.id);
    final role = txn.ownerAtAcceptance == demoViewerId
        ? TransactionViewerRole.owner
        : TransactionViewerRole.receiver;
    final proposal = store.cancellation(txn.id);

    return TransactionDetails(
      transaction: txn,
      materialTitle: material?.title ?? 'Tài liệu',
      materialSubject: material?.subject ?? '',
      ownerDisplayName:
          MockFixtures.displayNames[txn.ownerAtAcceptance] ?? 'Người dùng',
      receiverDisplayName:
          MockFixtures.displayNames[txn.receiverId] ?? 'Người dùng',
      viewerRole: role,
      createdAt: MockFixtures.transactionCreatedAt[txn.id] ??
          DateTime.utc(2026, 11, 20),
      borrowing: txn.type == OfferType.borrow ? borrowing : null,
      payment: txn.type == OfferType.sell ? payment : null,
      openIssueCount: store.openIssueCount(txn.id),
      cancellationProposal: proposal,
      allowedActions: _allowedActions(txn, role, payment, proposal),
    );
  }

  // Mô phỏng bảng quyền của SS-BR v2.0 ở mức gợi ý UI.
  Set<TransactionAction> _allowedActions(
    StudyTransaction txn,
    TransactionViewerRole role,
    PaymentConfirmation? payment,
    CancellationProposal? proposal,
  ) {
    if (txn.status.isTerminal) {
      // BR-34: sau COMPLETED vẫn được báo sự cố trong hạn 7 ngày lịch VN.
      // Cùng điều kiện với lệnh reportIssue; mọi thao tác khác đã kết thúc.
      return txn.status == TransactionStatus.completed &&
              isIssueReportWindowOpen(store, txn)
          ? const {TransactionAction.reportIssue}
          : const {};
    }
    final isOwner = role == TransactionViewerRole.owner;
    final actions = <TransactionAction>{TransactionAction.reportIssue};

    // Hủy: một bên đề nghị, bên còn lại phản hồi (BR-45).
    if (proposal == null) {
      actions.add(TransactionAction.proposeCancellation);
    } else if (proposal.proposedBy == role) {
      actions.add(TransactionAction.withdrawCancellation);
    } else {
      actions.add(TransactionAction.respondCancellation);
    }

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
        // Hoàn tiền chỉ phát sinh khi đang đề nghị hủy SELL đã nhận tiền.
        if (proposal != null && sellerConfirmed) {
          if (isOwner && payment?.refundReportedAt == null) {
            actions.add(TransactionAction.reportSellerRefund);
          }
          if (!isOwner &&
              payment?.refundReportedAt != null &&
              payment?.buyerRefundConfirmedAt == null) {
            actions.add(TransactionAction.confirmRefundReceived);
          }
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

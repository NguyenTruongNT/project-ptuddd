import '../contracts/models/models.dart';
import '../contracts/repositories/transaction_repository.dart';
import 'mock_fixtures.dart';

class MockTransactionQueryRepository implements TransactionQueryRepository {
  const MockTransactionQueryRepository({required this.demoViewerId});

  final String demoViewerId;

  bool _canSee(StudyTransaction txn) =>
      txn.ownerAtAcceptance == demoViewerId || txn.receiverId == demoViewerId;

  @override
  Future<List<StudyTransaction>> getMyTransactions() async =>
      List.unmodifiable(MockFixtures.transactions.where(_canSee));

  @override
  Future<StudyTransaction?> getTransactionDetails(String transactionId) async {
    for (final txn in MockFixtures.transactions) {
      if (txn.id == transactionId && _canSee(txn)) return txn;
    }
    return null; // Không lộ thông tin giao dịch cho người không liên quan.
  }

  @override
  Future<List<TransactionEventItem>> getTimeline(String transactionId) async {
    // Chưa có timeline mock; tuyệt đối không trả dữ liệu nếu không có quyền.
    final txn = await getTransactionDetails(transactionId);
    return txn == null ? [] : <TransactionEventItem>[];
  }
}

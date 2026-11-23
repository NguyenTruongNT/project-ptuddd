import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/models/transaction.dart';
import '../../../core/providers/mock_query_providers.dart';

// Đồng hồ chỉ dùng để tính NHÃN hiển thị (Quá hạn...), không phải mốc nghiệp vụ.
// Test override provider này để kiểm tra ranh giới ngày Việt Nam.
final nowUtcProvider = Provider<DateTime Function()>(
  (ref) => () => DateTime.now().toUtc(),
);

// Mọi provider đọc qua INTERFACE; khi có Supabase chỉ cần override repository.
final myTransactionsProvider = FutureProvider<List<TransactionDetails>>((ref) async {
  final items =
      await ref.watch(transactionQueryRepositoryProvider).getMyTransactions();
  // Mới nhất lên đầu để người dùng thấy việc vừa phát sinh.
  final sorted = [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return List.unmodifiable(sorted);
});

final transactionDetailsProvider =
    FutureProvider.family<TransactionDetails?, String>(
  (ref, transactionId) => ref
      .watch(transactionQueryRepositoryProvider)
      .getTransactionDetails(transactionId),
);

final transactionTimelineProvider =
    FutureProvider.family<List<TransactionEventItem>, String>(
  (ref, transactionId) =>
      ref.watch(transactionQueryRepositoryProvider).getTimeline(transactionId),
);

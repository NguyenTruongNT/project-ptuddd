import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_session_providers.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../../core/contracts/repositories/transaction_repository.dart';
import '../../../core/providers/mock_query_providers.dart';
import '../data/mock_command_runner.dart';
import '../data/mock_seller_payment_repository.dart';
import '../data/mock_transaction_cancellation_repository.dart';
import '../data/supabase_rpc_gateway.dart';
import '../data/supabase_transaction_repositories.dart';

// Đồng hồ chỉ dùng để tính NHÃN hiển thị (Quá hạn...), không phải mốc nghiệp vụ.
// Test override provider này để kiểm tra ranh giới ngày Việt Nam.
final nowUtcProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

// ---------- Repository (interface) ----------
// Trang chỉ phụ thuộc interface. Có SupabaseClient thì dùng RPC thật;
// không cấu hình Supabase (demo/test) thì dùng mock in-memory.

/// null khi chạy demo/test không có Supabase. Phụ thuộc ranh giới phiên để
/// đổi người dùng hay đăng xuất thì toàn bộ repository/cache được dựng lại.
final studyRpcGatewayProvider = Provider<SupabaseRpcGateway?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final boundary = ref.watch(sessionBoundaryProvider);
  if (client == null) return null;
  // Chưa đăng nhập: actor rỗng, mọi lời gọi trả AUTH_REQUIRED.
  return SupabaseRpcGateway.fromClient(
    client,
    boundary == 'demo' ? '' : boundary,
  );
});

final transactionReadRepositoryProvider = Provider<TransactionQueryRepository>((
  ref,
) {
  final rpc = ref.watch(studyRpcGatewayProvider);
  if (rpc != null) return SupabaseTransactionQueryRepository(rpc);
  return ref.watch(transactionQueryRepositoryProvider);
});

final _mockCommandRunnerProvider = Provider<MockCommandRunner>(
  (ref) => MockCommandRunner(
    store: ref.watch(mockTransactionStoreProvider),
    actorId: ref.watch(demoViewerIdProvider),
  ),
);

final sellerPaymentRepositoryProvider = Provider<SellerPaymentRepository>((
  ref,
) {
  final rpc = ref.watch(studyRpcGatewayProvider);
  if (rpc != null) return SupabaseSellerPaymentRepository(rpc);
  return MockSellerPaymentRepository(ref.watch(_mockCommandRunnerProvider));
});

final transactionCancellationRepositoryProvider =
    Provider<TransactionCancellationRepository>((ref) {
      final rpc = ref.watch(studyRpcGatewayProvider);
      if (rpc != null) return SupabaseTransactionCancellationRepository(rpc);
      return MockTransactionCancellationRepository(
        ref.watch(_mockCommandRunnerProvider),
      );
    });

// ---------- Dữ liệu đọc ----------
final myTransactionsProvider = FutureProvider<List<TransactionDetails>>((
  ref,
) async {
  final items = await ref
      .watch(transactionReadRepositoryProvider)
      .getMyTransactions();
  // Mới nhất lên đầu để người dùng thấy việc vừa phát sinh.
  final sorted = [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return List.unmodifiable(sorted);
});

final transactionDetailsProvider =
    FutureProvider.family<TransactionDetails?, String>(
      (ref, transactionId) => ref
          .watch(transactionReadRepositoryProvider)
          .getTransactionDetails(transactionId),
    );

final transactionTimelineProvider =
    FutureProvider.family<List<TransactionEventItem>, String>(
      (ref, transactionId) => ref
          .watch(transactionReadRepositoryProvider)
          .getTimeline(transactionId),
    );

/// Sau mỗi lệnh (thành công hay lỗi) tải lại snapshot server, không tự sửa UI.
void refreshTransaction(WidgetRef ref, String transactionId) {
  ref.invalidate(transactionDetailsProvider(transactionId));
  ref.invalidate(transactionTimelineProvider(transactionId));
  ref.invalidate(myTransactionsProvider);
}

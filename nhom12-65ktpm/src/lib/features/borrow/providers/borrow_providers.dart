import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/workflow_rpc.dart';
import '../../../core/contracts/repositories/transaction_repository.dart';
import '../../../core/providers/mock_query_providers.dart';
import '../data/mock_borrow_repository.dart';
import '../data/supabase_borrow_repository.dart';

/// Repository nghiệp vụ mượn/trả.
///
/// - Phiên Supabase thật luôn gọi RPC backend.
/// - Chỉ chế độ demo tường minh mới dùng mock.
/// - Không fallback sang mock khi backend hoặc phiên đăng nhập lỗi.
final borrowRepositoryProvider = Provider<BorrowRepository>((ref) {
  final WorkflowRpc? rpc = ref.watch(workflowRpcProvider);

  if (rpc != null) {
    return SupabaseBorrowRepository(rpc);
  }

  return MockBorrowRepository(
    ref.watch(mockTransactionStoreProvider),
    ref.watch(demoViewerIdProvider),
  );
});

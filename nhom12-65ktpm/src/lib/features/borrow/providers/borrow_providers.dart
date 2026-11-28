import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/workflow_rpc.dart';
import '../../../core/contracts/repositories/transaction_repository.dart';
import '../../../core/errors/app_error.dart';
import '../data/supabase_borrow_repository.dart';

/// Repository nghiệp vụ mượn/trả luôn dùng backend Supabase thật.
///
/// Không fallback sang mock khi thiếu cấu hình, hết phiên hoặc lỗi mạng;
/// màn hình bắt lỗi này và báo cần đăng nhập/kết nối Supabase.
final borrowRepositoryProvider = Provider<BorrowRepository>((ref) {
  final WorkflowRpc? rpc = ref.watch(workflowRpcProvider);

  if (rpc == null) {
    throw const AppError(
      DomainErrorCode.backendUnavailable,
      'Chức năng mượn/trả cần kết nối Supabase.',
    );
  }

  return SupabaseBorrowRepository(rpc);
});

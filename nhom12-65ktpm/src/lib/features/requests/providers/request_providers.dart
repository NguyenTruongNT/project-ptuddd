import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/workflow_rpc.dart';
import '../../../core/contracts/models/exchange_request.dart';
import '../../../core/contracts/repositories/request_repository.dart';
import '../../../core/errors/app_error.dart';
import '../data/supabase_request_repository.dart';

/// Request trong chức năng nộp bài luôn dùng backend Supabase thật.
///
/// Không fallback sang mock khi thiếu cấu hình, hết phiên hoặc lỗi mạng.
final requestRepositoryProvider = Provider<RequestRepository>((ref) {
  final WorkflowRpc? rpc = ref.watch(workflowRpcProvider);

  if (rpc == null) {
    throw const AppError(
      DomainErrorCode.backendUnavailable,
      'Chức năng yêu cầu cần kết nối Supabase.',
    );
  }

  return SupabaseRequestRepository(rpc);
});

/// Danh sách yêu cầu mà tài khoản hiện tại là requester hoặc owner.
final myRequestsProvider = FutureProvider.autoDispose<List<ExchangeRequest>>((
  ref,
) {
  return ref.watch(requestRepositoryProvider).getMyRequests();
});

/// Tải lại danh sách sau create, approve, reject hoặc cancel.
///
/// Các màn Listing cũng cần được tải lại vì hasPendingRequest và
/// isRequestable là projection do backend trả về.
void refreshRequests(WidgetRef ref) {
  ref.invalidate(myRequestsProvider);
}

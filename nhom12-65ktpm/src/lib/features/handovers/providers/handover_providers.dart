import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_session_providers.dart';
import '../../../core/backend/workflow_rpc.dart';
import '../../../core/contracts/models/handover.dart';
import '../../../core/providers/mock_query_providers.dart';
import '../data/mock_handover_repository.dart';
import '../data/supabase_handover_repository.dart';
import '../domain/handover_feature_repository.dart';

/// Provider cung cấp Repository Handover: dùng Supabase RPC thật khi đã đăng nhập,
/// chỉ dùng Mock khi ở chế độ Demo không có Supabase client.
final handoverRepositoryProvider = Provider<HandoverFeatureRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final boundary = ref.watch(sessionBoundaryProvider);
  if (client != null && boundary.isNotEmpty && boundary != 'demo') {
    final rpc = ref.watch(workflowRpcProvider);
    if (rpc != null) {
      return SupabaseHandoverRepository(rpc);
    }
  }
  final actorId = ref.watch(demoViewerIdProvider);
  final store = ref.watch(mockTransactionStoreProvider);
  return MockHandoverRepository(actorId: actorId, store: store);
});

/// Chi tiết lượt bàn giao theo ID
final handoverDetailsProvider =
    FutureProvider.family<Handover?, String>((ref, handoverId) async {
  final repo = ref.watch(handoverRepositoryProvider);
  return repo.getHandover(handoverId);
});

/// Làm mới dữ liệu bàn giao sau khi chụp ảnh / xác nhận
void refreshHandover(WidgetRef ref, String handoverId) {
  ref.invalidate(handoverDetailsProvider(handoverId));
  ref.invalidate(mockTransactionStoreProvider);
}

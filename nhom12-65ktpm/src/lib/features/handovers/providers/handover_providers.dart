import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/workflow_rpc.dart';
import '../../../core/contracts/models/handover.dart';
import '../../../core/providers/mock_query_providers.dart';
import '../data/handover_evidence_storage.dart';
import '../data/mock_handover_repository.dart';
import '../data/supabase_handover_repository.dart';
import '../domain/handover_feature_repository.dart';
import '../../transactions/providers/transaction_providers.dart';
import '../../issues/providers/issue_providers.dart';

/// Provider cung cấp Repository Handover: dùng Supabase RPC thật khi đã đăng nhập,
/// chỉ dùng Mock khi ở chế độ Demo không có Supabase client.
final handoverRepositoryProvider = Provider<HandoverFeatureRepository>((ref) {
  // Gateway chỉ trả null ở demo tường minh. Mất phiên/mất cấu hình trong
  // môi trường thật phải báo lỗi, không xác minh thành công bằng fixture.
  final rpc = ref.watch(workflowRpcProvider);
  if (rpc != null) return SupabaseHandoverRepository(rpc);
  final actorId = ref.watch(demoViewerIdProvider);
  final store = ref.watch(mockTransactionStoreProvider);
  return MockHandoverRepository(actorId: actorId, store: store);
});

/// Chi tiết lượt bàn giao theo ID
final handoverDetailsProvider = FutureProvider.family<Handover?, String>((
  ref,
  handoverId,
) async {
  final repo = ref.watch(handoverRepositoryProvider);
  return repo.getHandover(handoverId);
});

/// Danh sách Signed URL ngắn hạn cho ảnh minh chứng thật (từ bucket private).
final handoverEvidenceSignedUrlsProvider =
    FutureProvider.family<List<String>, String>((ref, handoverId) async {
  final repo = ref.watch(handoverRepositoryProvider);
  final storage = ref.watch(handoverEvidenceStorageProvider);
  final paths = await repo.getEvidencePaths(handoverId);
  if (paths.isEmpty || !storage.isCloudEnabled) return const [];
  final urls = <String>[];
  for (final path in paths) {
    final url = await storage.createSignedUrl(path);
    if (url != null) urls.add(url);
  }
  return List.unmodifiable(urls);
});

/// Làm mới dữ liệu bàn giao sau khi chụp ảnh / xác nhận
void refreshHandover(WidgetRef ref, String handoverId) {
  final transactionId = ref
      .read(handoverDetailsProvider(handoverId))
      .asData
      ?.value
      ?.transactionId;
  ref.invalidate(handoverDetailsProvider(handoverId));
  ref.invalidate(handoverEvidenceSignedUrlsProvider(handoverId));
  // Giữ store demo hiện tại, nhất là cờ QR sai; refresh không được xóa trạng
  // thái nghiệp vụ rồi cho phép fallback. Chỉ tải lại các read model liên quan.
  if (transactionId != null) refreshTransaction(ref, transactionId);
  ref.invalidate(myIssuesProvider);
}

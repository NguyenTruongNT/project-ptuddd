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

/// Đồng hồ chuẩn để kiểm tra TTL của Signed URL (có thể override trong test).
final evidenceClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Kết quả tải Signed URL ảnh minh chứng, phân biệt rõ chế độ demo với lỗi Storage.
class HandoverEvidenceUrls {
  const HandoverEvidenceUrls({
    required this.urls,
    this.failedCount = 0,
    this.isDemoMode = false,
    this.expiresAt,
  });

  final List<String> urls;
  final int failedCount;
  final bool isDemoMode;
  final DateTime? expiresAt;

  bool get hasPartialFailure => urls.isNotEmpty && failedCount > 0;

  bool isExpiredAt(DateTime now) {
    final exp = expiresAt;
    if (exp == null) return false;
    return !now.isBefore(exp);
  }
}

/// Danh sách Signed URL ngắn hạn cho ảnh minh chứng thật (từ bucket private).
/// Tự hủy khi rời màn hình để lần mở lại sau luôn cấp URL mới.
final handoverEvidenceSignedUrlsProvider = FutureProvider.autoDispose
    .family<HandoverEvidenceUrls, String>((ref, handoverId) async {
  final repo = ref.watch(handoverRepositoryProvider);
  final storage = ref.watch(handoverEvidenceStorageProvider);
  final now = ref.watch(evidenceClockProvider);

  // Chỉ chế độ demo tường minh (không có Supabase client) mới hiển thị ô mô phỏng.
  if (storage.client == null && !storage.isCloudEnabled) {
    return const HandoverEvidenceUrls(
      urls: [],
      isDemoMode: true,
    );
  }

  if (!storage.isCloudEnabled) {
    throw StateError('Chưa đăng nhập để tải ảnh minh chứng.');
  }

  final paths = await repo.getEvidencePaths(handoverId);
  if (paths.isEmpty) {
    return const HandoverEvidenceUrls(
      urls: [],
      isDemoMode: false,
    );
  }

  final urls = <String>[];
  var failedCount = 0;
  Object? lastError;
  StackTrace? lastStack;

  for (final path in paths) {
    try {
      final url = await storage.createSignedUrl(path);
      if (url.isNotEmpty) {
        urls.add(url);
      } else {
        failedCount++;
      }
    } catch (e, st) {
      failedCount++;
      lastError = e;
      lastStack = st;
    }
  }

  if (urls.isEmpty && failedCount > 0) {
    if (lastError != null && lastStack != null) {
      Error.throwWithStackTrace(lastError, lastStack);
    }
    throw StateError('Không thể tạo liên kết ảnh minh chứng.');
  }

  return HandoverEvidenceUrls(
    urls: List.unmodifiable(urls),
    failedCount: failedCount,
    isDemoMode: false,
    expiresAt: now().add(HandoverEvidenceStorage.signedUrlTtl),
  );
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

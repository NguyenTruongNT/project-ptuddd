import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/models/handover.dart';
import '../../../core/providers/mock_query_providers.dart';
import '../data/mock_handover_repository.dart';

/// Provider cung cấp MockHandoverRepository
final handoverRepositoryProvider = Provider<MockHandoverRepository>((ref) {
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

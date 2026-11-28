import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_session_providers.dart';
import '../../../core/contracts/material_workspace.dart';
import '../../../core/contracts/material_qr.dart';
import '../../../core/backend/workflow_rpc.dart';
import '../../../core/mock/mock_fixtures.dart';
import '../data/mock_material_workspace.dart';
import '../data/material_draft_store.dart';
import '../data/supabase_material_workspace.dart';
import '../data/material_qr_repository.dart';

// Provider chứa repository, không cache payload. Mỗi màn giữ QR trong bộ nhớ
// riêng và hủy nó khi đổi phiên/đưa ứng dụng ra nền.
final materialQrRepositoryProvider = Provider<MaterialQrRepository>((ref) {
  final rpc = ref.watch(workflowRpcProvider);
  return rpc == null
      ? MockMaterialQrRepository(
          ref.watch(mockMaterialStoreProvider),
          MockFixtures.userA,
        )
      : SupabaseMaterialQrRepository(rpc);
});

final mockMaterialStoreProvider = Provider<MockMaterialStore>((ref) {
  ref.watch(sessionBoundaryProvider);
  return MockMaterialStore();
});
final materialWorkspaceProvider = Provider<MaterialWorkspaceRepository>((ref) {
  final boundary = ref.watch(sessionBoundaryProvider);
  final client = ref.watch(supabaseClientProvider);
  if (boundary == 'demo' && client == null) {
    return MockMaterialWorkspace(
      ref.watch(mockMaterialStoreProvider),
      MockFixtures.userA,
    );
  }
  if (client == null || boundary.isEmpty) throw StateError('AUTH_REQUIRED');
  return SupabaseMaterialWorkspace(
    client,
    boundary,
    cache: ref.watch(materialDraftStoreProvider),
  );
});
final materialDraftStoreProvider = Provider<MaterialDraftStore>(
  (ref) => MaterialDraftStore(),
);
final materialImagePickerProvider = Provider<ImagePicker>(
  (ref) => ImagePicker(),
);
final materialDetailsProvider = FutureProvider.autoDispose
    .family<MaterialDetails?, String>((ref, id) {
      ref.watch(sessionBoundaryProvider);
      return ref.watch(materialWorkspaceProvider).getDetails(id);
    });

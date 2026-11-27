import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/workflow_rpc.dart';
import '../../../core/contracts/listing_workspace.dart';
import '../../../core/contracts/models/listing.dart';
import '../../../core/providers/mock_query_providers.dart';
import '../../materials/providers/material_providers.dart';
import '../../listings/providers/listing_providers.dart';
import '../data/home_repository.dart';
import '../domain/home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final rpc = ref.watch(workflowRpcProvider);
  return rpc == null
      ? MockHomeRepository(
          ref.watch(mockMaterialStoreProvider),
          ref.watch(mockTransactionStoreProvider),
          ref.watch(demoViewerIdProvider),
        )
      : SupabaseHomeRepository(rpc);
}, retry: (_, _) => null);
final homeOverviewProvider = FutureProvider<HomeOverview>(
  (ref) => ref.watch(homeRepositoryProvider).getOverview(),
  // Home cho retry từng khối bằng nút; tránh tự gọi lại 10 lần khi mất mạng.
  retry: (_, _) => null,
);

// Đây là một trang giới thiệu, không được dùng chiều dài trang để tính tổng.
final homeRecentListingsProvider = FutureProvider<List<ListingCardModel>>(
  (ref) async =>
      (await ref.watch(listingWorkspaceProvider).searchPage(limit: 6)).items,
  retry: (_, _) => null,
);
final homeDraftsProvider = FutureProvider<List<ManagedListing>>(
  (ref) async =>
      (await ref
              .watch(listingWorkspaceProvider)
              .searchMine(status: 'DRAFT', limit: 3))
          .items,
  retry: (_, _) => null,
);

void refreshHome(WidgetRef ref) {
  ref.invalidate(homeOverviewProvider);
  ref.invalidate(homeRecentListingsProvider);
  ref.invalidate(homeDraftsProvider);
}

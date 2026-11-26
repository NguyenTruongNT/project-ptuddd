import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_session_providers.dart';
import '../../../core/backend/workflow_rpc.dart';
import '../../../core/contracts/listing_workspace.dart';
import '../../../core/mock/mock_fixtures.dart';
import '../data/listing_preview_repository.dart';
import '../data/supabase_listing_workspace.dart';
import '../data/listing_drafts.dart';
import '../../materials/providers/material_providers.dart';

final listingDraftsProvider = Provider<ListingDrafts>(
  (ref) => ListingDrafts(ref.watch(materialDraftStoreProvider)),
);

final listingWorkspaceProvider = Provider<ListingWorkspaceRepository>((ref) {
  final boundary = ref.watch(sessionBoundaryProvider);
  final rpc = ref.watch(workflowRpcProvider);
  return rpc == null
      // Preview dùng cùng người xem với các module demo, không dùng actor giả cho RPC.
      ? ListingPreviewRepository(
          demoViewerId: boundary == 'demo' ? MockFixtures.userA : boundary,
        )
      : SupabaseListingWorkspace(rpc);
});
final listingDetailsProvider = FutureProvider.autoDispose
    .family<ListingDetails?, String>(
      (ref, id) => ref.watch(listingWorkspaceProvider).getPublishedDetails(id),
    );

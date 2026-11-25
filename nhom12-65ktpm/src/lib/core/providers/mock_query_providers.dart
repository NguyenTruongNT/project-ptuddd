import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contracts/models/listing.dart';
import '../contracts/models/material.dart';
import '../contracts/models/transaction.dart';
import '../contracts/repositories/issue_repository.dart';
import '../contracts/repositories/listing_repository.dart';
import '../contracts/repositories/material_repository.dart';
import '../contracts/repositories/transaction_repository.dart';
import '../mock/mock_fixtures.dart';
import '../mock/mock_issue_query_repository.dart';
import '../mock/mock_listing_query_repository.dart';
import '../mock/mock_material_query_repository.dart';
import '../mock/mock_transaction_query_repository.dart';
import '../mock/mock_transaction_store.dart';
import '../auth/auth_session_providers.dart';
import '../backend/workflow_rpc.dart';
import '../../features/transactions/data/supabase_transaction_repository.dart';
import '../../features/issues/data/supabase_issue_repository.dart';

// ID này chỉ dành cho trang preview. Không dùng làm actor cho Supabase RPC.
final demoViewerIdProvider = Provider<String>((ref) {
  final boundary = ref.watch(sessionBoundaryProvider);
  return boundary == 'demo' ? MockFixtures.userA : boundary;
});

// Các màn hình module sẽ đọc INTERFACE thay vì phụ thuộc class mock trực tiếp.
// Khi có backend thật, override các provider repository phù hợp.
final listingQueryRepositoryProvider = Provider<ListingQueryRepository>(
  (ref) => const MockListingQueryRepository(),
);
final materialQueryRepositoryProvider = Provider<MaterialQueryRepository>(
  (ref) => MockMaterialQueryRepository(
    demoViewerId: ref.watch(demoViewerIdProvider),
  ),
);
// Một store mô phỏng dùng chung cho đọc + lệnh mock; không phụ thuộc viewer
// để đổi tài khoản demo A/B vẫn thấy cùng trạng thái.
final mockTransactionStoreProvider = Provider<MockTransactionStore>((ref) {
  ref.watch(sessionBoundaryProvider);
  return MockTransactionStore.fromFixtures();
});
final transactionQueryRepositoryProvider = Provider<TransactionQueryRepository>(
  (ref) {
    final rpc = ref.watch(workflowRpcProvider);
    if (rpc != null) return SupabaseTransactionQueryRepository(rpc);
    return MockTransactionQueryRepository(
      demoViewerId: ref.watch(demoViewerIdProvider),
      store: ref.watch(mockTransactionStoreProvider),
    );
  },
);
// Issue dùng chung store với Transaction để nhãn "có sự cố" luôn khớp.
final issueQueryRepositoryProvider = Provider<IssueQueryRepository>((ref) {
  final rpc = ref.watch(workflowRpcProvider);
  if (rpc != null) return SupabaseIssueQueryRepository(rpc);
  return MockIssueQueryRepository(
    demoViewerId: ref.watch(demoViewerIdProvider),
    store: ref.watch(mockTransactionStoreProvider),
  );
});

// FutureProvider chuyển Future thành AsyncValue: loading/data/error cho UI.
final publishedListingsProvider = FutureProvider<List<ListingCardModel>>(
  (ref) => ref.watch(listingQueryRepositoryProvider).searchPublished(),
);
final myMaterialsPreviewProvider = FutureProvider<List<MaterialSummary>>(
  (ref) => ref.watch(materialQueryRepositoryProvider).getMyMaterials(),
);
final myTransactionsPreviewProvider = FutureProvider<List<TransactionDetails>>(
  (ref) => ref.watch(transactionQueryRepositoryProvider).getMyTransactions(),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contracts/models/listing.dart';
import '../contracts/models/material.dart';
import '../contracts/models/transaction.dart';
import '../contracts/repositories/listing_repository.dart';
import '../contracts/repositories/material_repository.dart';
import '../contracts/repositories/transaction_repository.dart';
import '../mock/mock_fixtures.dart';
import '../mock/mock_listing_query_repository.dart';
import '../mock/mock_material_query_repository.dart';
import '../mock/mock_transaction_query_repository.dart';

// ID này chỉ dành cho trang preview. Không dùng làm actor cho Supabase RPC.
final demoViewerIdProvider = Provider<String>((ref) => MockFixtures.userA);

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
final transactionQueryRepositoryProvider = Provider<TransactionQueryRepository>(
  (ref) => MockTransactionQueryRepository(
    demoViewerId: ref.watch(demoViewerIdProvider),
  ),
);

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

import '../../../core/backend/workflow_rpc.dart';
import '../../../core/mock/mock_transaction_store.dart';
import '../../materials/data/mock_material_workspace.dart';
import '../domain/home_repository.dart';

class SupabaseHomeRepository implements HomeRepository {
  const SupabaseHomeRepository(this.rpc);
  final WorkflowRpc rpc;
  @override
  Future<HomeOverview> getOverview() =>
      rpc.read('get_home_overview', {}, HomeOverview.fromJson);
}

class MockHomeRepository implements HomeRepository {
  const MockHomeRepository(this.store, this.transactions, this.actor);
  final MockMaterialStore store;
  final MockTransactionStore transactions;
  final String actor;
  @override
  Future<HomeOverview> getOverview() async {
    final materials = store.values.values
        .where((d) => d.material.ownerId == actor)
        .toList();
    int listings(String status) =>
        materials.where((d) => d.listingStatus == status).length;
    return HomeOverview(
      materialCount: materials.length,
      publishedCount: listings('PUBLISHED'),
      draftCount: listings('DRAFT'),
      hiddenCount: listings('HIDDEN'),
      // Dùng trạng thái demo đang thao tác, không đếm lại fixture ban đầu.
      activeTransactionCount: transactions.transactions
          .where(
            (t) =>
                (t.ownerAtAcceptance == actor || t.receiverId == actor) &&
                !['COMPLETED', 'CANCELLED'].contains(t.status.wire),
          )
          .length,
      serverAt: DateTime.now().toUtc(),
    );
  }
}

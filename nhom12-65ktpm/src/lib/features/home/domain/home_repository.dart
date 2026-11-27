import '../../../core/backend/workflow_json.dart';

class HomeOverview {
  const HomeOverview({
    required this.materialCount,
    required this.publishedCount,
    required this.draftCount,
    required this.hiddenCount,
    required this.activeTransactionCount,
    required this.serverAt,
  });
  final int materialCount,
      publishedCount,
      draftCount,
      hiddenCount,
      activeTransactionCount;
  final DateTime serverAt;

  factory HomeOverview.fromJson(Object? raw) {
    final row = WorkflowJson.object(raw);
    int count(String key) {
      final value = WorkflowJson.integer(row[key]);
      if (value < 0) throw const FormatException('Invalid overview count');
      return value;
    }

    return HomeOverview(
      materialCount: count('material_count'),
      publishedCount: count('published_count'),
      draftCount: count('draft_count'),
      hiddenCount: count('hidden_count'),
      activeTransactionCount: count('active_transaction_count'),
      serverAt: WorkflowJson.timestamp(row['server_at']),
    );
  }
}

abstract interface class HomeRepository {
  Future<HomeOverview> getOverview();
}

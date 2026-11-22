import '../contracts/models/models.dart';
import '../contracts/repositories/material_repository.dart';
import 'mock_fixtures.dart';

class MockMaterialQueryRepository implements MaterialQueryRepository {
  const MockMaterialQueryRepository({required this.demoViewerId});

  // Chỉ để giả lập session của A/B/C; bản Supabase lấy auth.uid() ở server.
  final String demoViewerId;

  @override
  Future<List<MaterialSummary>> getMyMaterials() async {
    return List.unmodifiable(MockFixtures.materials
        .where((material) => material.ownerId == demoViewerId)
        .map((material) => MaterialSummary(
              id: material.id,
              title: material.title,
              subject: material.subject,
              ownerId: material.ownerId,
              holderId: material.holderId,
            )));
  }

  @override
  Future<Material?> getMyMaterial(String materialId) async {
    for (final material in MockFixtures.materials) {
      if (material.id == materialId && material.ownerId == demoViewerId) {
        return material;
      }
    }
    return null;
  }
}

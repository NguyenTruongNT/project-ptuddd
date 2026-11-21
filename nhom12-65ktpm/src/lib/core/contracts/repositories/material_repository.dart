import '../command_inputs.dart';
import '../command_result.dart';
import '../models/material.dart';

abstract interface class MaterialQueryRepository {
  // Server chỉ trả tài liệu mà người đang đăng nhập được phép xem.
  Future<List<MaterialSummary>> getMyMaterials();
  Future<Material?> getMyMaterial(String materialId);
}

abstract interface class MaterialRepository {
  Future<CommandResult<Material>> createMaterial(
    CreateMaterialInput input, {required String idempotencyKey});
}

import '../../../core/backend/workflow_rpc.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/material_qr.dart';
import '../../../core/errors/app_error.dart';
import 'mock_material_workspace.dart';

class SupabaseMaterialQrRepository implements MaterialQrRepository {
  const SupabaseMaterialQrRepository(this.rpc);
  final WorkflowRpc rpc;

  @override
  Future<CommandResult<MaterialQr>> ensureQr(
    String materialId, {
    required String idempotencyKey,
  }) {
    if (!MaterialQr.validId(materialId) ||
        !MaterialQr.validKey(idempotencyKey)) {
      return Future.value(
        const CommandError(
          DomainErrorCode.invalidInput,
          'Thông tin yêu cầu QR không hợp lệ.',
        ),
      );
    }
    // Không có TransactionEvent: ACK dùng receipt server, giống Material/Listing.
    return rpc.receiptCommand('ensure_material_qr', {
      'p_material_id': materialId,
      'p_idempotency_key': idempotencyKey,
    }, (raw) => MaterialQr.fromJson(raw, expectedMaterialId: materialId));
  }
}

class MockMaterialQrRepository implements MaterialQrRepository {
  const MockMaterialQrRepository(this.store, this.actor);
  final MockMaterialStore store;
  final String actor;

  @override
  Future<CommandResult<MaterialQr>> ensureQr(
    String materialId, {
    required String idempotencyKey,
  }) async {
    if (!MaterialQr.validKey(idempotencyKey)) {
      return const CommandError(
        DomainErrorCode.invalidInput,
        'Thiếu mã thao tác.',
      );
    }
    if (store.values[materialId]?.material.ownerId != actor) {
      return const CommandError(
        DomainErrorCode.forbidden,
        'QR không còn khả dụng.',
      );
    }
    // Namespace DEMO không thể bị server hiểu nhầm là QR Material hợp lệ.
    return CommandOk(
      MaterialQr(
        materialId: materialId,
        title: store.values[materialId]!.material.title,
        version: 0,
        payload: 'studyshare:demo:$materialId',
        issuedAt: DateTime.utc(2026, 11, 27),
        isDemo: true,
      ),
      null,
    );
  }
}

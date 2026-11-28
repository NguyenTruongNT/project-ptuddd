import '../backend/workflow_json.dart';
import 'command_result.dart';

/// DTO riêng tư, chỉ tồn tại trong bộ nhớ màn QR; không ghép vào MaterialDetails,
/// ListingDetails, cache SQLite, URL điều hướng hoặc dữ liệu công khai.
class MaterialQr {
  const MaterialQr({
    required this.materialId,
    required this.title,
    required this.payload,
    required this.version,
    required this.issuedAt,
    this.isDemo = false,
  });

  final String materialId;
  final String title;
  final String payload;
  final int version;
  final DateTime issuedAt;
  final bool isDemo;

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
  );
  static bool validId(String id) => _uuid.hasMatch(id);
  static bool validKey(String key) =>
      key.isNotEmpty &&
      key.length <= 128 &&
      key.trim() == key &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(key);

  factory MaterialQr.fromJson(
    Object? raw, {
    required String expectedMaterialId,
  }) {
    final row = WorkflowJson.object(raw);
    final id = WorkflowJson.text(row['material_id']);
    final version = WorkflowJson.integer(row['version']);
    final payload = WorkflowJson.text(row['payload']);
    if (!validId(id) ||
        id.toLowerCase() != expectedMaterialId.toLowerCase() ||
        row['kind'] != 'MATERIAL' ||
        version != 1 ||
        !RegExp('^studyshare:material:1:${id.toLowerCase()}:[0-9a-f]{64}\$')
            .hasMatch(payload)) {
      throw const FormatException('Invalid private QR response');
    }
    return MaterialQr(
      materialId: id,
      title: WorkflowJson.text(row['title']),
      payload: payload,
      version: version,
      issuedAt: WorkflowJson.timestamp(row['issued_at']),
    );
  }
}

abstract interface class MaterialQrRepository {
  Future<CommandResult<MaterialQr>> ensureQr(
    String materialId, {
    required String idempotencyKey,
  });
}

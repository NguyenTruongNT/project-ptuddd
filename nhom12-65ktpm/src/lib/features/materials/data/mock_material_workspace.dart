import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/contracts/material_workspace.dart';
import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/models/material.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/mock/mock_fixtures.dart';
import '../domain/material_validation.dart';

// Store Material riêng; giữ nguyên fixture và module của đồng đội.
class MockMaterialStore {
  MockMaterialStore({bool seeded = true}) {
    if (!seeded) return;
    for (final material in MockFixtures.materials) {
      final listing = MockFixtures.listings
          .where((l) => l.materialId == material.id)
          .firstOrNull;
      final active = MockFixtures.transactions.any(
        (t) =>
            t.materialId == material.id &&
            !['COMPLETED', 'CANCELLED'].contains(t.status.wire),
      );
      values[material.id] = MaterialDetails(
        material: material,
        listingStatus: listing?.status.wire,
        hasActiveTransaction: active,
        ownerName: MockFixtures.displayNames[material.ownerId],
        holderName: MockFixtures.displayNames[material.holderId],
        editBlockedReason: active
            ? 'TRANSACTION_ACTIVE'
            : listing?.status.wire == 'PUBLISHED'
            ? 'LISTING_PUBLISHED'
            : material.holderId != material.ownerId
            ? 'NOT_CURRENT_HOLDER'
            : null,
      );
    }
  }
  final values = <String, MaterialDetails>{};
  final uploads =
      <String, ({String actor, String? target, MaterialImage image})>{};
  final receipts = <String, ({String hash, CommandResult<Material> result})>{};
}

class MockMaterialWorkspace implements MaterialWorkspaceRepository {
  MockMaterialWorkspace(this.store, this.actor);
  final MockMaterialStore store;
  final String actor;
  bool failUpload = false;
  bool failSave = false;
  @override
  Future<MaterialDetails?> getDetails(String id) async {
    final d = store.values[id];
    return d?.material.ownerId == actor ? d : null;
  }

  @override
  Future<Material?> getMyMaterial(String materialId) async =>
      (await getDetails(materialId))?.material;
  @override
  Future<List<MaterialSummary>> getMyMaterials() async =>
      (await searchMaterials(limit: 1000)).items;
  @override
  Future<MaterialPage> searchMaterials({
    String query = '',
    String filter = 'all',
    int offset = 0,
    int limit = 20,
  }) async {
    final q = query.trim().toLowerCase();
    final rows = store.values.values
        .where((d) {
          final m = d.material;
          return m.ownerId == actor &&
              (q.isEmpty ||
                  m.title.toLowerCase().contains(q) ||
                  (m.isbn ?? '').toLowerCase().contains(q)) &&
              (filter == 'all' ||
                  (filter == 'ready' && d.canPublish) ||
                  (filter == 'active' && d.hasActiveTransaction));
        })
        .toList()
        .reversed
        .toList();
    final page = rows
        .skip(offset)
        .take(limit)
        .map(
          (d) => MaterialSummary(
            id: d.material.id,
            title: d.material.title,
            subject: d.material.subject,
            ownerId: d.material.ownerId,
            holderId: d.material.holderId,
            coverUrl: d.images.firstOrNull?.url,
            canEdit: d.canEdit,
            canPublish: d.canPublish,
            listingStatus: d.listingStatus,
            hasActiveTransaction: d.hasActiveTransaction,
          ),
        )
        .toList();
    return MaterialPage(page, hasMore: offset + limit < rows.length);
  }

  @override
  Future<MaterialImage> uploadImage(
    MaterialPhoto photo, {
    String? materialId,
  }) async {
    if (failUpload) {
      throw const AppError(DomainErrorCode.evidenceUploadFailed, '');
    }
    if (actor.isEmpty) throw const AppError(DomainErrorCode.authRequired, '');
    if (photo.bytes.isEmpty ||
        photo.bytes.length > MaterialValidation.maxImageBytes ||
        !['image/jpeg', 'image/png', 'image/webp'].contains(photo.mimeType)) {
      throw const AppError(DomainErrorCode.invalidInput, '');
    }
    if (materialId != null) {
      final d = await getDetails(materialId);
      if (d == null || !d.canEdit) {
        throw const AppError(DomainErrorCode.forbidden, '');
      }
    }
    final id = const Uuid().v4();
    final image = MaterialImage(
      id: id,
      storagePath: '$actor/$id',
      bytes: photo.bytes,
      url: 'data:${photo.mimeType};base64,${base64Encode(photo.bytes)}',
    );
    store.uploads[id] = (actor: actor, target: materialId, image: image);
    return image;
  }

  Future<CommandResult<Material>> _save(
    String? id,
    CreateMaterialInput input,
    int? revision,
    String key,
  ) async {
    if (actor.isEmpty) {
      return const CommandError(DomainErrorCode.authRequired, '');
    }
    final receiptKey = '$actor:${id == null ? 'create' : 'update'}:$key';
    final hash = jsonEncode([
      id,
      input.title.trim(),
      input.subject.trim(),
      input.condition.trim(),
      input.description?.trim(),
      MaterialValidation.normalizeIsbn(input.isbn ?? ''),
      input.imageIds,
      revision,
    ]);
    final receipt = store.receipts[receiptKey];
    if (receipt != null) {
      return receipt.hash == hash
          ? receipt.result
          : const CommandError(DomainErrorCode.conflict, '');
    }
    if (failSave) {
      return const CommandError(DomainErrorCode.networkUnavailable, '');
    }
    if (key.isEmpty || !MaterialValidation.input(input)) {
      return const CommandError(DomainErrorCode.invalidInput, '');
    }
    final old = id == null ? null : await getDetails(id);
    if (id != null && old == null) {
      return const CommandError(DomainErrorCode.forbidden, '');
    }
    if (old != null && !old.canEdit) {
      return const CommandError(DomainErrorCode.materialUnavailable, '');
    }
    if (old != null && revision != old.material.revision) {
      return const CommandError(DomainErrorCode.conflict, '');
    }
    final images = <MaterialImage>[];
    for (final imageId in input.imageIds) {
      final existing = old?.images.where((p) => p.id == imageId).firstOrNull;
      final upload = store.uploads[imageId];
      if (existing != null) {
        images.add(existing);
      } else if (upload != null &&
          upload.actor == actor &&
          (upload.target == null || upload.target == id)) {
        images.add(upload.image);
      } else {
        return const CommandError(DomainErrorCode.forbidden, '');
      }
    }
    final m = Material(
      id: id ?? const Uuid().v4(),
      ownerId: actor,
      holderId: old?.material.holderId ?? actor,
      title: input.title.trim(),
      subject: input.subject.trim(),
      condition: input.condition.trim(),
      description: input.description?.trim(),
      isbn: input.isbn == null
          ? null
          : MaterialValidation.normalizeIsbn(input.isbn!),
      revision: (old?.material.revision ?? 0) + 1,
      updatedAt: DateTime.now().toUtc(),
    );
    store.values[m.id] = MaterialDetails(
      material: m,
      images: List.unmodifiable(images),
      ownerName: MockFixtures.displayNames[actor],
      holderName: MockFixtures.displayNames[m.holderId],
      listingStatus: old?.listingStatus,
    );
    for (final imageId in input.imageIds) {
      store.uploads.remove(imageId);
    }
    final result = CommandOk.receipt(
      m,
      commandId: const Uuid().v4(),
      serverRevision: m.revision,
    );
    store.receipts[receiptKey] = (hash: hash, result: result);
    return result;
  }

  @override
  Future<CommandResult<Material>> createMaterial(
    CreateMaterialInput input, {
    required String idempotencyKey,
  }) => _save(null, input, null, idempotencyKey);
  @override
  Future<CommandResult<Material>> updateMaterial(
    String id,
    CreateMaterialInput input, {
    required int expectedRevision,
    required String idempotencyKey,
  }) => _save(id, input, expectedRevision, idempotencyKey);
  @override
  Future<void> discardUpload(String imageId) async {
    if (store.uploads[imageId]?.actor == actor) store.uploads.remove(imageId);
  }
}

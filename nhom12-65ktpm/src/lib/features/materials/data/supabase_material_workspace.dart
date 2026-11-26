import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/contracts/material_workspace.dart';
import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/models/material.dart';
import '../../../core/errors/app_error.dart';
import '../domain/material_validation.dart';
import 'material_draft_store.dart';

class SupabaseMaterialWorkspace implements MaterialWorkspaceRepository {
  SupabaseMaterialWorkspace(this.client, this.actor, {this.cache});
  final SupabaseClient client;
  final String actor;
  final MaterialDraftStore? cache;
  static const bucket = 'studyshare-material-images';
  void _session() {
    if (actor.isEmpty || client.auth.currentUser?.id != actor) {
      throw const AppError(DomainErrorCode.authRequired, '');
    }
  }

  DomainErrorCode _code(Object e) {
    final raw = e is PostgrestException
        ? e.message
        : e is AppError
        ? e.code.wire
        : e is FunctionException && e.details is Map
        ? (e.details as Map)['code']?.toString()
        : '';
    for (final code in DomainErrorCode.values) {
      if (raw == code.wire) return code;
    }
    if (e is PostgrestException ||
        e is StorageException ||
        e is FunctionException) {
      return DomainErrorCode.forbidden;
    }
    return DomainErrorCode.networkUnavailable;
  }

  Material _material(Map<String, dynamic> r) => Material(
    id: r['id'] as String,
    ownerId: r['owner_id'] as String,
    holderId: r['holder_id'] as String,
    title: r['title'] as String,
    subject: r['subject'] as String,
    condition: r['condition'] as String,
    description: r['description'] as String?,
    isbn: r['isbn'] as String?,
    revision: (r['revision'] as num).toInt(),
    updatedAt: DateTime.tryParse(r['updated_at'] as String? ?? ''),
  );
  Future<MaterialDetails> _details(
    Map<String, dynamic> r, {
    bool cached = false,
    bool coverOnly = false,
  }) async {
    final images = <MaterialImage>[];
    final rows = r['images'] as List? ?? [];
    for (final raw in coverOnly ? rows.take(1) : rows) {
      final i = Map<String, dynamic>.from(raw as Map);
      String? url;
      if (!cached) {
        try {
          _session();
          url = await client.storage
              .from(bucket)
              .createSignedUrl(i['storage_path'] as String, 300)
              .timeout(const Duration(seconds: 10));
        } catch (_) {
          /* Page retains metadata and offers image refresh. */
        }
      }
      images.add(
        MaterialImage(
          id: i['id'] as String,
          storagePath: i['storage_path'] as String,
          url: url,
        ),
      );
    }
    return MaterialDetails(
      material: _material(r),
      images: List.unmodifiable(images),
      ownerName: r['owner_name'] as String?,
      holderName: r['holder_name'] as String?,
      listingStatus: r['listing_status'] as String?,
      hasActiveTransaction: r['has_active_transaction'] == true,
      editBlockedReason: r['edit_blocked_reason'] as String?,
      isCached: cached,
    );
  }

  @override
  Future<MaterialDetails?> getDetails(String id) async {
    _session();
    final key = 'cache:$actor:$id';
    try {
      final raw = await client
          .rpc('get_my_material', params: {'p_material_id': id})
          .timeout(const Duration(seconds: 20));
      _session();
      if (raw == null) {
        await cache?.remove(key);
        return null;
      }
      final r = Map<String, dynamic>.from(raw as Map);
      try {
        await cache?.write(key, {
          'saved_at': DateTime.now().toUtc().toIso8601String(),
          'data': r,
        });
      } catch (_) {}
      return await _details(r);
    } catch (e) {
      _session();
      if (_code(e) == DomainErrorCode.networkUnavailable) {
        try {
          final local = await cache?.read(key);
          if (local != null &&
              DateTime.now().toUtc().difference(
                    DateTime.parse(local['saved_at'] as String),
                  ) <
                  const Duration(minutes: 15)) {
            return await _details(
              Map<String, dynamic>.from(local['data'] as Map),
              cached: true,
            );
          }
        } catch (_) {}
      }
      throw AppError(_code(e), '');
    }
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
    _session();
    final cacheKey = 'cache-list:$actor:$filter:$offset:$limit:${query.trim()}';
    try {
      final raw = Map<String, dynamic>.from(
        await client
                .rpc(
                  'search_my_materials',
                  params: {
                    'p_query': query.trim(),
                    'p_filter': filter,
                    'p_offset': offset,
                    'p_limit': limit,
                  },
                )
                .timeout(const Duration(seconds: 20))
            as Map,
      );
      try {
        await cache?.write(cacheKey, {
          'saved_at': DateTime.now().toUtc().toIso8601String(),
          'data': raw,
        });
      } catch (_) {}
      return await _page(raw);
    } catch (e) {
      _session();
      if (_code(e) == DomainErrorCode.networkUnavailable) {
        try {
          final local = await cache?.read(cacheKey);
          if (local != null &&
              DateTime.now().toUtc().difference(
                    DateTime.parse(local['saved_at'] as String),
                  ) <
                  const Duration(minutes: 15)) {
            return await _page(
              Map<String, dynamic>.from(local['data'] as Map),
              cached: true,
            );
          }
        } catch (_) {}
      }
      throw AppError(_code(e), '');
    }
  }

  Future<MaterialPage> _page(
    Map<String, dynamic> raw, {
    bool cached = false,
  }) async {
    final details = await Future.wait(
      (raw['items'] as List).map(
        (r) => _details(
          Map<String, dynamic>.from(r as Map),
          cached: cached,
          coverOnly: true,
        ),
      ),
    );
    _session();
    return MaterialPage(
      details
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
          .toList(),
      hasMore: raw['has_more'] == true,
      isCached: cached,
    );
  }

  @override
  Future<MaterialImage> uploadImage(
    MaterialPhoto photo, {
    String? materialId,
  }) async {
    _session();
    if (photo.bytes.isEmpty ||
        photo.bytes.length > MaterialValidation.maxImageBytes ||
        !['image/jpeg', 'image/png', 'image/webp'].contains(photo.mimeType)) {
      throw const AppError(DomainErrorCode.invalidInput, '');
    }
    Map<String, dynamic>? upload;
    try {
      await _cleanupExpired();
      upload = Map<String, dynamic>.from(
        await client.rpc(
          'prepare_material_image',
          params: {
            'p_mime_type': photo.mimeType,
            'p_byte_size': photo.bytes.length,
            'p_material_id': materialId,
          },
        ) as Map,
      );
      _session();
      await client.storage
          .from(bucket)
          .uploadBinary(
            upload['storage_path'] as String,
            photo.bytes,
            fileOptions: FileOptions(
              contentType: photo.mimeType,
              upsert: false,
            ),
          );
      _session();
      await client.functions.invoke(
        'verify-material-image',
        body: {'image_id': upload['id']},
      );
      _session();
      return MaterialImage(
        id: upload['id'] as String,
        storagePath: upload['storage_path'] as String,
        bytes: photo.bytes,
      );
    } catch (e) {
      if (upload != null && client.auth.currentUser?.id == actor) {
        try {
          await discardUpload(upload['id'] as String);
        } catch (_) {}
      }
      throw AppError(
        e is PostgrestException || e is FunctionException
            ? _code(e)
            : DomainErrorCode.evidenceUploadFailed,
        '',
      );
    }
  }

  Future<CommandResult<Material>> _save(
    String? id,
    CreateMaterialInput input,
    int? revision,
    String key,
  ) async {
    try {
      _session();
      if (!MaterialValidation.input(input)) {
        return const CommandError(DomainErrorCode.invalidInput, '');
      }
      final payload = {
        'title': input.title.trim(),
        'subject': input.subject.trim(),
        'condition': input.condition.trim(),
        'description': input.description,
        'isbn': input.isbn,
        'image_ids': input.imageIds,
      };
      final raw = Map<String, dynamic>.from(
        await client
                .rpc(
                  'save_material',
                  params: {
                    'p_payload': payload,
                    'p_idempotency_key': key,
                    'p_material_id': id,
                    'p_expected_revision': revision,
                  },
                )
                .timeout(const Duration(seconds: 25))
            as Map,
      );
      _session();
      return CommandOk.receipt(
        _material(raw),
        commandId: raw['command_id'] as String,
        serverRevision: (raw['server_revision'] as num).toInt(),
      );
    } catch (e) {
      final code = e is PostgrestException || e is AppError
          ? _code(e)
          : DomainErrorCode.timeoutUnknown;
      return CommandError(code, '');
    }
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
    _session();
    final path = await client.rpc(
      'discard_material_upload',
      params: {'p_image_id': imageId},
    );
    _session();
    if (path is String) {
      await client.storage.from(bucket).remove([path]);
      _session();
      await client.rpc(
        'finish_material_upload_cleanup',
        params: {
          'p_paths': [path],
        },
      );
    }
  }

  Future<void> _cleanupExpired() async {
    _session();
    try {
      final rows = await client.rpc('claim_expired_material_uploads') as List;
      final paths = rows.cast<String>();
      if (paths.isEmpty) return;
      _session();
      await client.storage.from(bucket).remove(paths);
      _session();
      await client.rpc(
        'finish_material_upload_cleanup',
        params: {'p_paths': paths},
      );
    } catch (_) {
      /* Dọn nháp cũ được retry lần upload kế tiếp. */
    }
  }
}

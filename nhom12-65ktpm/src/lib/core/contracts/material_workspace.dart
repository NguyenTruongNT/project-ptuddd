import 'dart:typed_data';

import 'command_inputs.dart';
import 'command_result.dart';
import 'models/material.dart';
import 'repositories/material_repository.dart';

class MaterialImage {
  const MaterialImage({
    required this.id,
    required this.storagePath,
    this.url,
    this.bytes,
  });
  final String id;
  final String storagePath;
  final String? url;
  final Uint8List? bytes;
}

class MaterialPhoto {
  const MaterialPhoto({
    required this.localId,
    required this.name,
    required this.mimeType,
    required this.bytes,
  });
  final String localId;
  final String name;
  final String mimeType;
  final Uint8List bytes;
}

class MaterialDetails {
  const MaterialDetails({
    required this.material,
    this.images = const [],
    this.ownerName,
    this.holderName,
    this.listingStatus,
    this.hasActiveTransaction = false,
    this.editBlockedReason,
    this.isCached = false,
  });
  final Material material;
  final List<MaterialImage> images;
  final String? ownerName;
  final String? holderName;
  final String? listingStatus;
  final bool hasActiveTransaction;
  final String? editBlockedReason;
  final bool isCached;
  bool get canEdit => !isCached && editBlockedReason == null;
  bool get canPublish => canEdit && listingStatus == null && images.isNotEmpty;
}

class MaterialPage {
  const MaterialPage(
    this.items, {
    required this.hasMore,
    this.isCached = false,
  });
  final List<MaterialSummary> items;
  final bool hasMore;
  final bool isCached;
}

abstract interface class MaterialWorkspaceRepository
    implements MaterialQueryRepository, MaterialRepository {
  Future<MaterialPage> searchMaterials({
    String query = '',
    String filter = 'all',
    int offset = 0,
    int limit = 20,
  });
  Future<MaterialDetails?> getDetails(String id);
  Future<MaterialImage> uploadImage(MaterialPhoto photo, {String? materialId});
  Future<CommandResult<Material>> updateMaterial(
    String id,
    CreateMaterialInput input, {
    required int expectedRevision,
    required String idempotencyKey,
  });
  Future<void> discardUpload(String imageId);
}

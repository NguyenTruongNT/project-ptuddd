import '../../../core/backend/workflow_rpc.dart';
import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/listing_workspace.dart';
import '../../../core/contracts/models/listing.dart';
import '../../../core/errors/app_error.dart';

class SupabaseListingWorkspace implements ListingWorkspaceRepository {
  SupabaseListingWorkspace(this.rpc);
  final WorkflowRpc rpc;
  static Map<String, dynamic> _map(Object? v) =>
      Map<String, dynamic>.from(v as Map);
  static ManagedListing decodeManaged(Object? raw, {String? coverUrl}) {
    final v = _map(raw);
    return ManagedListing(
      listing: Listing(
        id: v['id'] as String,
        materialId: v['material_id'] as String,
        offerType: OfferType.fromWire(v['offer_type'] as String),
        status: ListingStatus.fromWire(v['status'] as String),
        askingPriceVnd: (v['asking_price_vnd'] as num?)?.toInt(),
        revision: (v['revision'] as num).toInt(),
        description: v['description'] as String?,
        meetingArea: v['meeting_area'] as String?,
      ),
      materialRevision: (v['material_revision'] as num).toInt(),
      title: v['title'] as String? ?? '',
      coverUrl: coverUrl,
      canEdit: v['can_edit'] == true,
      canHide: v['can_hide'] == true,
      canShow: v['can_show'] == true,
      hasActiveTransaction: v['has_active_transaction'] == true,
      hasPendingRequests: v['has_pending_requests'] == true,
    );
  }

  @override
  Future<ManagedListing?> getManaged({String? listingId, String? materialId}) =>
      rpc.read('get_my_listing', {
        'p_listing_id': listingId,
        'p_material_id': materialId,
      }, (v) => v == null ? null : decodeManaged(v));
  @override
  Future<ListingPage<ManagedListing>> searchMine({
    String status = 'all',
    String query = '',
    int offset = 0,
    int limit = 20,
  }) async {
    final v = await rpc.read('search_my_listings', {
      'p_status': status,
      'p_query': query,
      'p_offset': offset,
      'p_limit': limit,
    }, _map);
    final items = await Future.wait(
      (v['items'] as List).map((raw) async {
        final item = _map(raw);
        String? coverUrl;
        final path = item['cover_storage_path'] as String?;
        if (path != null) {
          try {
            // Đường dẫn chỉ từ RPC riêng của chủ tin; Storage vẫn kiểm tra RLS.
            // Ký đúng ảnh bìa, không gọi thêm RPC/gallery cho từng dòng danh sách.
            coverUrl = await rpc.client.storage
                .from('studyshare-material-images')
                .createSignedUrl(path, 300);
          } catch (_) {
            // Lỗi ảnh không che mất tin và các thao tác quản lý còn hợp lệ.
          }
        }
        return decodeManaged(item, coverUrl: coverUrl);
      }),
    );
    return ListingPage(
      List.unmodifiable(items),
      hasMore: v['has_more'] == true,
    );
  }

  @override
  Future<CommandResult<ManagedListing>> execute(ListingCommand command) =>
      rpc.receiptCommand('save_listing', command.toRpc(), decodeManaged);
  @override
  Future<CommandResult<ManagedListing>?> getCommandResult(
    ListingCommand command,
  ) => rpc.read(
    'get_listing_command_result',
    {
      'p_command': 'listing_${command.action.name}',
      'p_key': command.idempotencyKey,
    },
    (raw) {
      if (raw == null) return null;
      final v = _map(raw);
      return CommandOk.receipt(
        decodeManaged(v['data']),
        commandId: v['command_id'] as String,
        serverRevision: (v['server_revision'] as num).toInt(),
      );
    },
  );
  Future<String?> _image(String listingId, String imageId) async {
    try {
      final path = await rpc.read<String?>('get_listing_image_path', {
        'p_listing_id': listingId,
        'p_image_id': imageId,
      }, (v) => v as String?);
      if (path == null) return null;
      final url = await rpc.client.storage
          .from('studyshare-material-images')
          .createSignedUrl(path, 300)
          .timeout(rpc.timeout);
      if (rpc.client.auth.currentUser?.id != rpc.actor) return null;
      return url;
    } catch (_) {
      return null;
    } // Lỗi ảnh không làm mất metadata; UI cho tải lại.
  }

  Future<ListingDetails> _details(Object? raw, {bool coverOnly = false}) async {
    final v = _map(raw);
    final id = v['id'] as String;
    final images = await Future.wait(
      (v['images'] as List).take(coverOnly ? 1 : 5).map((item) async {
        final imageId = _map(item)['id'] as String;
        return ListingImage(id: imageId, url: await _image(id, imageId));
      }),
    );
    return ListingDetails(
      card: ListingCardModel(
        listingId: id,
        materialId: v['material_id'] as String,
        title: v['title'] as String,
        subject: v['subject'] as String,
        condition: v['condition'] as String,
        offerType: OfferType.fromWire(v['offer_type'] as String),
        askingPriceVnd: (v['asking_price_vnd'] as num?)?.toInt(),
        isRequestable: v['is_requestable'] == true,
        isReserved: v['is_reserved'] == true,
        isOwner: v['is_owner'] == true,
        hasPendingRequest: v['has_pending_request'] == true,
        coverUrl: images.firstOrNull?.url,
        publishedAt: DateTime.tryParse(v['published_at'] as String? ?? ''),
      ),
      ownerId: v['owner_id'] as String,
      ownerName: v['owner_name'] as String,
      images: List.unmodifiable(images),
      isbn: v['isbn'] as String?,
      description: v['description'] as String?,
      materialDescription: v['material_description'] as String?,
      meetingArea: v['meeting_area'] as String?,
    );
  }

  @override
  Future<ListingDetails?> getPublishedDetails(String listingId) async {
    final raw = await rpc.read<Object?>('get_published_listing', {
      'p_listing_id': listingId,
    }, (v) => v);
    return raw == null ? null : _details(raw);
  }

  @override
  Future<ListingPage<ListingCardModel>> searchPage({
    String keyword = '',
    int offset = 0,
    int limit = 20,
  }) async {
    final raw = await rpc.read('search_published_listings', {
      'p_keyword': keyword,
      'p_offset': offset,
      'p_limit': limit,
    }, _map);
    final details = await Future.wait(
      (raw['items'] as List).map((v) => _details(v, coverOnly: true)),
    );
    return ListingPage(
      List.unmodifiable(details.map((e) => e.card)),
      hasMore: raw['has_more'] == true,
    );
  }

  @override
  Future<List<ListingCardModel>> searchPublished({String keyword = ''}) async =>
      (await searchPage(keyword: keyword)).items;
  @override
  Future<ListingCardModel?> getPublishedCard(String listingId) async =>
      (await getPublishedDetails(listingId))?.card;
  // Adapter interface cũ. Màn mới dùng execute với revisions đã hiển thị.
  @override
  Future<CommandResult<Listing>> createListing(
    CreateListingInput input, {
    required String idempotencyKey,
  }) async {
    final receipt = await getCommandResult(
      ListingCommand(
        action: ListingAction.draft,
        materialId: input.materialId,
        idempotencyKey: idempotencyKey,
      ),
    );
    if (receipt is CommandOk<ManagedListing>) {
      final old = receipt.data.listing;
      if (old.materialId != input.materialId ||
          old.offerType != input.offerType ||
          old.askingPriceVnd != input.askingPriceVnd) {
        return const CommandError(
          DomainErrorCode.conflict,
          'Key đã dùng cho nội dung khác.',
        );
      }
      return _legacy(receipt);
    }
    final m = await rpc.read('get_my_material', {
      'p_material_id': input.materialId,
    }, (v) => v == null ? null : _map(v));
    if (m == null) {
      return const CommandError(
        DomainErrorCode.forbidden,
        'Không có quyền với tài liệu này.',
      );
    }
    return _legacy(
      await execute(
        ListingCommand(
          action: ListingAction.draft,
          materialId: input.materialId,
          expectedMaterialRevision: (m['revision'] as num).toInt(),
          offerType: input.offerType,
          askingPriceVnd: input.askingPriceVnd,
          idempotencyKey: idempotencyKey,
        ),
      ),
    );
  }

  @override
  Future<CommandResult<Listing>> publishListing(
    String listingId, {
    required String idempotencyKey,
  }) async {
    final receipt = await getCommandResult(
      ListingCommand(
        action: ListingAction.publish,
        materialId: '',
        idempotencyKey: idempotencyKey,
      ),
    );
    if (receipt is CommandOk<ManagedListing>) {
      if (receipt.data.listing.id != listingId) {
        return const CommandError(
          DomainErrorCode.conflict,
          'Key đã dùng cho tin khác.',
        );
      }
      return _legacy(receipt);
    }
    final d = await getManaged(listingId: listingId);
    if (d == null) {
      return const CommandError(
        DomainErrorCode.forbidden,
        'Không có quyền với tin này.',
      );
    }
    return _legacy(
      await execute(
        ListingCommand(
          action: ListingAction.publish,
          materialId: d.listing.materialId,
          listingId: listingId,
          expectedRevision: d.listing.revision,
          expectedMaterialRevision: d.materialRevision,
          offerType: d.listing.offerType,
          askingPriceVnd: d.listing.askingPriceVnd,
          description: d.listing.description,
          meetingArea: d.listing.meetingArea,
          idempotencyKey: idempotencyKey,
        ),
      ),
    );
  }

  CommandResult<Listing> _legacy(CommandResult<ManagedListing> r) =>
      switch (r) {
        CommandOk() => CommandOk.receipt(
          r.data.listing,
          commandId: r.commandId,
          serverRevision: r.serverRevision,
        ),
        CommandError() => CommandError(r.code, r.safeMessage),
      };
}

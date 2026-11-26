import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/app_routes.dart';
import '../../../core/auth/auth_session_providers.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/listing_workspace.dart';
import '../../../core/contracts/material_workspace.dart';
import '../../../core/contracts/models/material.dart' as material_model;
import '../../../core/contracts/models/listing.dart' as listing_model;
import '../../../core/errors/app_error.dart';
import '../../../core/providers/mock_query_providers.dart';
import '../../../design_system/widgets/study_confirm.dart';
import '../../../l10n/app_localizations.dart';
import '../../materials/presentation/material_widgets.dart';
import '../../materials/providers/material_providers.dart';
import '../domain/listing_validation.dart';
import '../providers/listing_providers.dart';
import 'listing_widgets.dart';

class ListingFormPage extends ConsumerStatefulWidget {
  const ListingFormPage({
    super.key,
    this.materialId,
    this.listingId,
    this.returnPublishedResult = false,
  });
  final String? materialId;
  final String? listingId;
  final bool returnPublishedResult;
  @override
  ConsumerState<ListingFormPage> createState() => _ListingFormPageState();
}

class _ListingFormPageState extends ConsumerState<ListingFormPage> {
  final _price = TextEditingController();
  final _description = TextEditingController();
  final _area = TextEditingController();
  MaterialDetails? _material;
  ManagedListing? _managed;
  OfferType? _offer;
  ListingCommand? _pending;
  late final String _actor;
  bool _loading = true, _busy = false, _dirty = false, _leaving = false;
  bool _needsReview = false;
  Object? _loadError;
  String? _message;
  String? _localKey;
  bool get _same => mounted && ref.read(sessionBoundaryProvider) == _actor;
  bool get _writable =>
      _material != null &&
      !_material!.isCached &&
      (_managed?.canEdit ?? _material!.canEdit);
  String get _draftId =>
      _localKey ??
      _managed?.listing.id ??
      widget.listingId ??
      widget.materialId ??
      'new';
  bool get _canType =>
      _writable ||
      (_material?.isCached == true &&
          (_managed == null ||
              _managed!.listing.status == ListingStatus.draft ||
              _managed!.listing.status == ListingStatus.hidden));

  // Lưu local chỉ chống mất dữ liệu, không có nghĩa nội dung đã đồng bộ server.
  // Tin ẩn phải lưu thay đổi lên server trước khi hiện lại đúng nội dung đó.
  bool get _contentChanged =>
      _managed != null &&
      (_offer != _managed!.listing.offerType ||
          _price.text.trim() !=
              (_managed!.listing.askingPriceVnd?.toString() ?? '') ||
          _description.text.trim() != (_managed!.listing.description ?? '') ||
          _area.text.trim() != (_managed!.listing.meetingArea ?? ''));
  @override
  void initState() {
    super.initState();
    _actor = ref.read(sessionBoundaryProvider);
    _load(restore: true);
  }

  @override
  void dispose() {
    _price.dispose();
    _description.dispose();
    _area.dispose();
    super.dispose();
  }

  void _populate(ManagedListing? d) {
    _offer = d?.listing.offerType;
    _price.text = d?.listing.askingPriceVnd?.toString() ?? '';
    _description.text = d?.listing.description ?? '';
    _area.text = d?.listing.meetingArea ?? '';
  }

  Future<void> _load({bool restore = false}) async {
    setState(() {
      _loading = true;
      _loadError = null;
      _needsReview = false;
    });
    try {
      if (widget.materialId == null && widget.listingId == null) {
        throw const AppError(DomainErrorCode.invalidInput, '');
      }
      // Luôn đọc tin hiện hành trước: chọn cùng Material không tạo Listing thứ hai.
      final d = await ref
          .read(listingWorkspaceProvider)
          .getManaged(
            listingId: widget.listingId,
            materialId: widget.materialId,
          );
      if (widget.listingId != null && d == null) {
        throw const AppError(DomainErrorCode.forbidden, '');
      }
      final materialId = d?.listing.materialId ?? widget.materialId!;
      if (widget.materialId != null && materialId != widget.materialId) {
        throw const AppError(DomainErrorCode.forbidden, '');
      }
      final m = await ref
          .read(materialWorkspaceProvider)
          .getDetails(materialId);
      if (m == null) throw const AppError(DomainErrorCode.forbidden, '');
      if (!mounted || !_same) return;
      setState(() {
        _managed = d;
        _material = m;
        _populate(d);
        _loading = false;
        _dirty = false;
      });
      if (restore) {
        var local = await ref
            .read(listingDraftsProvider)
            .read(_actor, _draftId);
        if (local == null &&
            widget.materialId != null &&
            widget.materialId != _draftId) {
          local = await ref
              .read(listingDraftsProvider)
              .read(_actor, widget.materialId!);
          if (local != null) _localKey = widget.materialId;
        }
        if (!mounted || !_same || local == null) return;
        final restoredLocal = local;
        final t = AppLocalizations.of(context)!;
        final pending = restoredLocal['pending'];
        final accept =
            pending != null ||
            await showStudyConfirm(
              context,
              title: t.listingLocal,
              message: t.listingRestore,
              confirmLabel: t.commonConfirm,
            );
        if (!mounted || !_same || !accept) return;
        setState(() {
          _offer = restoredLocal['offer'] == null
              ? null
              : OfferType.fromWire(restoredLocal['offer'] as String);
          _price.text = restoredLocal['price'] as String? ?? '';
          _description.text = restoredLocal['description'] as String? ?? '';
          _area.text = restoredLocal['area'] as String? ?? '';
          if (pending != null) {
            _pending = ListingCommand.fromRpc(
              Map<String, dynamic>.from(pending as Map),
            );
          }
          _dirty = true;
          _message = pending != null ? t.listingUnknown : t.listingLocalSaved;
          if (restoredLocal['material_revision'] != m.material.revision ||
              restoredLocal['listing_revision'] != d?.listing.revision) {
            _message = pending != null
                ? t.listingUnknown
                : t.listingMaterialChanged;
          }
        });
      }
    } catch (e) {
      if (e is AppError &&
          e.code == DomainErrorCode.networkUnavailable &&
          mounted &&
          _same) {
        final local = await ref
            .read(listingDraftsProvider)
            .read(_actor, _draftId);
        if (mounted && _same && local != null && local['material'] is Map) {
          final m = Map<String, dynamic>.from(local['material'] as Map);
          setState(() {
            _material = MaterialDetails(
              isCached: true,
              material: material_model.Material(
                id: local['material_id'] as String,
                ownerId: _actor,
                holderId: m['holder_id'] as String,
                title: m['title'] as String,
                subject: m['subject'] as String,
                condition: m['condition'] as String,
                revision: (local['material_revision'] as num).toInt(),
              ),
            );
            _offer = local['offer'] == null
                ? null
                : OfferType.fromWire(local['offer'] as String);
            _price.text = local['price'] as String? ?? '';
            _description.text = local['description'] as String? ?? '';
            _area.text = local['area'] as String? ?? '';
            if (local['listing_id'] != null) {
              _managed = ManagedListing(
                materialRevision: _material!.material.revision,
                listing: listing_model.Listing(
                  id: local['listing_id'] as String,
                  materialId: _material!.material.id,
                  offerType: _offer ?? OfferType.borrow,
                  status: ListingStatus.fromWire(local['status'] as String),
                  revision: (local['listing_revision'] as num).toInt(),
                ),
              );
            }
            if (local['pending'] != null) {
              _pending = ListingCommand.fromRpc(
                Map<String, dynamic>.from(local['pending'] as Map),
              );
            }
            _loading = false;
            _loadError = null;
            _message = AppLocalizations.of(context)!.matCached;
          });
          return;
        }
      }
      if (mounted && _same) {
        setState(() {
          _loadError = e;
          _loading = false;
        });
      }
    }
  }

  Map<String, dynamic> _local() => {
    'material_id': _material?.material.id ?? widget.materialId,
    'listing_id': _managed?.listing.id ?? widget.listingId,
    'title': _material?.material.title ?? '',
    'offer': _offer?.wire,
    'price': _price.text,
    'description': _description.text,
    'area': _area.text,
    'material_revision': _material?.material.revision,
    'listing_revision': _managed?.listing.revision,
    'pending': _pending?.toRpc(),
    'status': _managed?.listing.status.wire,
    'material': _material == null
        ? null
        : {
            'title': _material!.material.title,
            'subject': _material!.material.subject,
            'condition': _material!.material.condition,
            'holder_id': _material!.material.holderId,
          },
  };
  Future<void> _saveLocal({bool silent = false}) async {
    try {
      await ref.read(listingDraftsProvider).save(_actor, _draftId, _local());
      if (mounted && _same && !silent) {
        setState(() {
          _dirty = false;
          _message = AppLocalizations.of(context)!.listingLocalSaved;
        });
      }
    } catch (e) {
      if (mounted && _same) {
        setState(() => _message = AppLocalizations.of(context)!.matDraftError);
        rethrow;
      }
    }
  }

  Future<void> _leave() async {
    if (_busy || _leaving) return;
    final t = AppLocalizations.of(context)!;
    if (_dirty || _pending != null) {
      // Command chưa rõ ACK phải được giữ lại; không cho bỏ key để gửi bản mới.
      final choice = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(t.listingLeave),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, 'stay'),
              child: Text(t.listingStay),
            ),
            if (_pending == null)
              TextButton(
                onPressed: () => Navigator.pop(c, 'discard'),
                child: Text(t.listingDiscard),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(c, 'save'),
              child: Text(t.listingLocal),
            ),
          ],
        ),
      );
      if (!mounted || !_same || choice == null || choice == 'stay') return;
      try {
        if (choice == 'save') {
          await _saveLocal(silent: true);
        } else {
          await ref.read(listingDraftsProvider).remove(_actor, _draftId);
        }
      } catch (_) {
        return;
      }
    }
    if (!mounted || !_same) return;
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.publishTab);
        }
      }
    });
  }

  Future<void> _submit(ListingAction action) async {
    if (_busy || !_same || _pending != null) return;
    final t = AppLocalizations.of(context)!;
    if (action == ListingAction.draft || action == ListingAction.publish) {
      final error = ListingValidation.validate(
        offer: _offer,
        priceText: _price.text,
        description: _description.text,
        meetingArea: _area.text,
        publish: action == ListingAction.publish,
      );
      if (error != null) {
        setState(() => _message = error);
        return;
      }
      if (action == ListingAction.publish && _material!.images.isEmpty) {
        setState(() => _message = t.listingNoImages);
        return;
      }
    }
    final title = switch (action) {
      ListingAction.draft => t.listingSave,
      ListingAction.publish => t.listingPublish,
      ListingAction.hide => t.listingHide,
      ListingAction.show => t.listingShow,
    };
    final summary = action == ListingAction.hide
        ? t.listingHideConfirm
        : '${_material!.material.title}\n${offerLabel(_offer ?? _managed!.listing.offerType, t)}'
              '${_offer == OfferType.sell ? '\n${_price.text} VND' : ''}\n${_description.text}\n${_area.text}';
    if (!await showStudyConfirm(
      context,
      title: title,
      message: summary,
      confirmLabel: t.commonConfirm,
    )) {
      return;
    }
    if (!mounted || !_same) return;
    _pending = ListingCommand(
      action: action,
      materialId: _material!.material.id,
      listingId: _managed?.listing.id,
      expectedRevision: _managed?.listing.revision,
      expectedMaterialRevision: _material!.material.revision,
      offerType: _offer,
      askingPriceVnd: _offer == OfferType.sell
          ? ListingValidation.price(_price.text)
          : null,
      description: _description.text.trim(),
      meetingArea: _area.text.trim(),
      idempotencyKey: const Uuid().v4(),
    );
    setState(() {}); // Khóa form ngay trước lúc ghi command vào SQLite.
    try {
      await _saveLocal(silent: true);
    } catch (_) {
      _pending = null;
      return;
    }
    await _send();
  }

  Future<void> _send({bool reconcile = false}) async {
    final command = _pending;
    if (command == null || _busy || !_same) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(listingWorkspaceProvider);
      final saved = reconcile ? await repo.getCommandResult(command) : null;
      final result = saved ?? await repo.execute(command);
      if (!mounted || !_same) return;
      if (result is CommandOk<ManagedListing>) {
        final oldKey = _draftId;
        _pending = null;
        _localKey = null;
        try {
          await ref.read(listingDraftsProvider).remove(_actor, oldKey);
        } catch (_) {
          // ACK vẫn có hiệu lực; bản local còn receipt/key để đối soát lần mở sau.
        }
        if (!mounted || !_same) return;
        ref.invalidate(materialDetailsProvider(command.materialId));
        ref.invalidate(publishedListingsProvider);
        ref.invalidate(listingDetailsProvider(result.data.listing.id));
        ManagedListing current = result.data;
        try {
          current =
              await repo.getManaged(listingId: result.data.listing.id) ??
              result.data;
        } catch (_) {
          // Lệnh đã ACK; lỗi tải trạng thái mới không được biến thành rollback giả.
        }
        if (!mounted || !_same) return;
        setState(() {
          _managed = current;
          _dirty = false;
          _message = AppLocalizations.of(context)!.listingSaved;
        });
        if (command.action == ListingAction.publish &&
            current.listing.status == ListingStatus.published) {
          setState(() => _leaving = true);
          // Trả kết quả qua các màn chọn/danh sách để đóng luồng đã hoàn tất.
          // Các điểm vào khác giữ màn nguồn khi thay form bằng chi tiết công khai.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_same) return;
            if (widget.returnPublishedResult && context.canPop()) {
              context.pop(result.data.listing.id);
            } else {
              context.pushReplacement(
                AppRoutes.listingDetails(result.data.listing.id),
              );
            }
          });
        } else {
          await _load();
        }
      } else if (result is CommandError<ManagedListing>) {
        setState(
          () => _message = listingError(
            AppError(result.code, result.safeMessage),
            AppLocalizations.of(context)!,
          ),
        );
        if (result.code != DomainErrorCode.timeoutUnknown &&
            result.code != DomainErrorCode.networkUnavailable) {
          _pending = null;
          _needsReview =
              result.code == DomainErrorCode.conflict ||
              result.code == DomainErrorCode.materialUnavailable;
          await _saveLocal(silent: true);
        }
      }
    } catch (e) {
      if (mounted && _same) {
        setState(() => _message = AppLocalizations.of(context)!.listingUnknown);
      }
    } finally {
      if (mounted && _same) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final boundary = ref.watch(sessionBoundaryProvider);
    if (boundary != _actor) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(t.matForbidden)),
      );
    }
    return PopScope(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _loading || _loadError != null
                ? t.listingFormTitle
                : _managed == null
                ? t.listingCreateFormTitle
                : _managed!.listing.status == ListingStatus.draft
                ? t.listingEditDraftTitle
                : t.listingFormTitle,
          ),
          leading: BackButton(onPressed: _leave),
          actions: [
            IconButton(
              onPressed: _busy || _dirty || _pending != null
                  ? null
                  : () => _load(),
              icon: const Icon(Icons.refresh),
              tooltip: t.listingRetry,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? ListingErrorView(
                message: listingError(_loadError!, t),
                onRetry: () => _load(),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        _material!.material.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '${_material!.material.subject} · ${_material!.material.condition}',
                      ),
                      if (_managed != null)
                        Chip(
                          label: Text(
                            listingStatusLabel(_managed!.listing.status, t),
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 150,
                        child: MaterialPhotoView(
                          image: _material!.images.firstOrNull,
                          fit: BoxFit.contain,
                        ),
                      ),
                      if (_material!.images.isEmpty)
                        MaterialNotice(t.listingNoImages),
                      if (!_writable && !_material!.isCached)
                        MaterialNotice(t.listingLocked),
                      if (_message != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: MaterialNotice(_message!),
                        ),
                      if ((_managed?.canShow ?? false) && _contentChanged)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: MaterialNotice(t.listingSaveBeforeShow),
                        ),
                      if (_needsReview)
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  try {
                                    await _saveLocal(silent: true);
                                  } catch (_) {
                                    return;
                                  }
                                  if (mounted && _same) {
                                    await _load(restore: true);
                                  }
                                },
                          child: Text(t.listingRetry),
                        ),
                      if (_pending != null) ...[
                        MaterialNotice(t.listingUnknown),
                        FilledButton(
                          key: const ValueKey('listing-retry-command'),
                          onPressed: _busy
                              ? null
                              : () => _send(reconcile: true),
                          child: Text(t.listingCheck),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(t.listingOffer),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final offer in OfferType.values)
                            ChoiceChip(
                              key: ValueKey('listing-offer-${offer.wire}'),
                              label: Text(offerLabel(offer, t)),
                              selected: _offer == offer,
                              onSelected: !_canType || _busy || _pending != null
                                  ? null
                                  : (_) {
                                      // Bấm lại hình thức đang chọn không được xóa giá đã nhập.
                                      if (_offer == offer) return;
                                      setState(() {
                                        _offer = offer;
                                        _price.clear();
                                        _dirty = true;
                                      });
                                    },
                            ),
                        ],
                      ),
                      if (_offer == OfferType.sell)
                        TextField(
                          key: const ValueKey('listing-price'),
                          controller: _price,
                          keyboardType: TextInputType.number,
                          enabled: _canType && !_busy && _pending == null,
                          decoration: InputDecoration(
                            labelText: t.listingPrice,
                          ),
                          onChanged: (_) => setState(() => _dirty = true),
                        ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const ValueKey('listing-description'),
                        controller: _description,
                        maxLines: 4,
                        enabled: _canType && !_busy && _pending == null,
                        decoration: InputDecoration(
                          labelText: t.listingDescription,
                        ),
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const ValueKey('listing-area'),
                        controller: _area,
                        enabled: _canType && !_busy && _pending == null,
                        decoration: InputDecoration(labelText: t.listingArea),
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      const SizedBox(height: 20),
                      if (_busy) const LinearProgressIndicator(),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          // Chỉ hiện thao tác phù hợp; tin công bố không có form sửa/nháp.
                          if (_canType || _pending != null)
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      try {
                                        await _saveLocal();
                                      } catch (_) {}
                                    },
                              child: Text(t.listingLocal),
                            ),
                          if (_writable)
                            OutlinedButton(
                              key: const ValueKey('listing-save'),
                              onPressed: _busy || _pending != null
                                  ? null
                                  : () => _submit(ListingAction.draft),
                              child: Text(t.listingSave),
                            ),
                          if (_writable &&
                              (_managed == null ||
                                  _managed!.listing.status ==
                                      ListingStatus.draft))
                            FilledButton(
                              key: const ValueKey('listing-publish'),
                              onPressed:
                                  _busy ||
                                      _pending != null ||
                                      _material!.images.isEmpty
                                  ? null
                                  : () => _submit(ListingAction.publish),
                              child: Text(t.listingPublish),
                            ),
                          if (_managed?.canHide ?? false)
                            OutlinedButton(
                              onPressed: _busy || _pending != null
                                  ? null
                                  : () => _submit(ListingAction.hide),
                              child: Text(t.listingHide),
                            ),
                          if (_managed?.canShow ?? false)
                            FilledButton(
                              onPressed:
                                  _busy ||
                                      _pending != null ||
                                      _dirty ||
                                      _contentChanged
                                  ? null
                                  : () => _submit(ListingAction.show),
                              child: Text(t.listingShow),
                            ),
                          if (_material!.canEdit)
                            OutlinedButton(
                              onPressed: _busy || _pending != null
                                  ? null
                                  : () async {
                                      if (_dirty) {
                                        try {
                                          await _saveLocal(silent: true);
                                        } catch (_) {
                                          return;
                                        }
                                      }
                                      if (!mounted || !_same) return;
                                      if (!context.mounted) {
                                        return;
                                      }
                                      await context.push(
                                        '${AppRoutes.materialEdit(_material!.material.id)}?completion=return',
                                      );
                                      if (mounted && _same) {
                                        await _load(restore: true);
                                      }
                                    },
                              child: Text(t.matEdit),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

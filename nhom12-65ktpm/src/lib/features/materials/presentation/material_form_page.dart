import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Material;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../app/app_routes.dart';
import '../../../core/auth/auth_session_providers.dart';
import '../../../core/contracts/command_inputs.dart';
import '../../../core/contracts/command_result.dart';
import '../../../core/contracts/material_workspace.dart';
import '../../../core/contracts/models/material.dart';
import '../../../core/errors/app_error.dart';
import '../../../design_system/widgets/study_confirm.dart';
import '../../../design_system/widgets/study_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/material_validation.dart';
import '../providers/material_providers.dart';
import 'material_widgets.dart';

class MaterialFormPage extends ConsumerStatefulWidget {
  const MaterialFormPage({super.key, this.materialId});
  final String? materialId;
  @override
  ConsumerState<MaterialFormPage> createState() => _MaterialFormPageState();
}

class _PhotoEdit {
  _PhotoEdit({this.local, this.uploaded});
  final MaterialPhoto? local;
  MaterialImage? uploaded;
  bool error = false;
}

class _MaterialFormPageState extends ConsumerState<MaterialFormPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(),
      _subject = TextEditingController(),
      _condition = TextEditingController(),
      _description = TextEditingController(),
      _isbn = TextEditingController();
  final _photos = <_PhotoEdit>[];
  late final String _actor;
  late final String _draftKey;
  String _key = const Uuid().v4(), _base = '', _progress = '';
  int? _revision;
  bool _loading = true,
      _busy = false,
      _allowPop = false,
      _closing = false,
      _uncertain = false;
  Object? _error;
  MaterialDetails? _details;
  bool get _changed => _base != _fingerprint();
  bool get _editable =>
      !_loading &&
      !_busy &&
      !_uncertain &&
      (widget.materialId == null || _details != null) &&
      (_details == null || _details!.canEdit);
  String _fingerprint() => jsonEncode([
    _title.text,
    _subject.text,
    _condition.text,
    _description.text,
    _isbn.text,
    _photos.map((p) => p.local?.localId ?? p.uploaded!.id).toList(),
  ]);
  bool get _valid =>
      MaterialValidation.text(_title.text, 200) &&
      MaterialValidation.text(_subject.text, 100) &&
      MaterialValidation.text(_condition.text, 100) &&
      (_description.text.trim().isEmpty ||
          MaterialValidation.text(_description.text, 2000)) &&
      MaterialValidation.isbn(_isbn.text);
  @override
  void initState() {
    super.initState();
    _actor = ref.read(sessionBoundaryProvider);
    _draftKey = '$_actor:${widget.materialId ?? 'new'}';
    _load();
  }

  @override
  void dispose() {
    for (final c in [_title, _subject, _condition, _description, _isbn]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _sameActor =>
      ref.read(sessionBoundaryProvider) == _actor && _actor.isNotEmpty;
  void _fill(MaterialDetails? d) {
    _details = d;
    _revision = d?.material.revision;
    _title.text = d?.material.title ?? '';
    _subject.text = d?.material.subject ?? '';
    _condition.text = d?.material.condition ?? '';
    _description.text = d?.material.description ?? '';
    _isbn.text = d?.material.isbn ?? '';
    _photos
      ..clear()
      ..addAll(d?.images.map((p) => _PhotoEdit(uploaded: p)) ?? []);
    _base = _fingerprint();
  }

  Future<void> _load() async {
    try {
      final d = widget.materialId == null
          ? null
          : await ref
                .read(materialWorkspaceProvider)
                .getDetails(widget.materialId!);
      if (!mounted || !_sameActor) return;
      if (widget.materialId != null && d == null) {
        setState(() {
          _error = const AppError(DomainErrorCode.forbidden, '');
          _loading = false;
        });
        return;
      }
      _fill(d);
      Map<String, dynamic>? draft;
      try {
        draft = await ref.read(materialDraftStoreProvider).read(_draftKey);
      } catch (_) {
        /* Một nháp lỗi không chặn việc mở tài liệu server. */
      }
      if (!mounted || !_sameActor) return;
      setState(() => _loading = false);
      if (draft != null && (d == null || d.canEdit)) {
        final t = AppLocalizations.of(context)!;
        final resume = await showStudyConfirm(
          context,
          title: t.matDraftFound,
          message: t.matLeaveBody,
          confirmLabel: t.matResumeDraft,
        );
        if (!mounted || !_sameActor) return;
        if (resume) {
          _restore(draft);
        }
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final marker = await ref
            .read(materialDraftStoreProvider)
            .read('picker-context');
        if (marker?['actor'] == _actor && marker?['draftKey'] == _draftKey) {
          final lost = await ref
              .read(materialImagePickerProvider)
              .retrieveLostData();
          if (!mounted || !_sameActor) return;
          if (lost.files != null) {
            await _acceptFiles(lost.files!);
          }
          await ref.read(materialDraftStoreProvider).remove('picker-context');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  void _restore(Map<String, dynamic> value) {
    _title.text = value['title'] as String? ?? '';
    _subject.text = value['subject'] as String? ?? '';
    _condition.text = value['condition'] as String? ?? '';
    _description.text = value['description'] as String? ?? '';
    _isbn.text = value['isbn'] as String? ?? '';
    _revision = value['revision'] as int? ?? _revision;
    _key = value['key'] as String? ?? const Uuid().v4();
    _uncertain = value['uncertain'] == true;
    _photos.clear();
    for (final raw in (value['photos'] as List? ?? []).take(5)) {
      final p = raw as Map;
      _photos.add(
        _PhotoEdit(
          local: p['bytes'] == null
              ? null
              : MaterialPhoto(
                  localId: p['localId'] as String,
                  name: p['name'] as String,
                  mimeType: p['mime'] as String,
                  bytes: base64Decode(p['bytes'] as String),
                ),
          uploaded: p['id'] == null
              ? null
              : MaterialImage(
                  id: p['id'] as String,
                  storagePath: p['path'] as String,
                  url: _details?.images
                      .where((i) => i.id == p['id'])
                      .firstOrNull
                      ?.url,
                ),
        ),
      );
    }
    setState(() {});
  }

  Map<String, dynamic> _draft() => {
    'title': _title.text,
    'subject': _subject.text,
    'condition': _condition.text,
    'description': _description.text,
    'isbn': _isbn.text,
    'revision': _revision,
    'key': _key,
    'uncertain': _uncertain,
    'photos': _photos
        .map(
          (p) => {
            'id': p.uploaded?.id,
            'path': p.uploaded?.storagePath,
            'localId': p.local?.localId,
            'name': p.local?.name,
            'mime': p.local?.mimeType,
            'bytes': p.local == null ? null : base64Encode(p.local!.bytes),
          },
        )
        .toList(),
  };
  Future<bool> _saveDraft({bool notify = true}) async {
    if (!_sameActor) return false;
    try {
      await ref.read(materialDraftStoreProvider).write(_draftKey, _draft());
      if (mounted && notify) {
        StudyFeedbackHost.of(context)
            ?.show(AppLocalizations.of(context)!.matDraftSaved);
      }
      return true;
    } catch (_) {
      if (mounted) setState(() => _error = StateError('DRAFT_WRITE_FAILED'));
      return false;
    }
  }

  void _touch() {
    if (!_uncertain) {
      _key = const Uuid().v4();
    }
    setState(() {});
  }

  Future<void> _pick() async {
    if (!_editable || _photos.length >= 5) return;
    final t = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(t.matCamera),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t.matGallery),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (source == null || !mounted || !_sameActor) return;
    try {
      // Lưu trước khi Android mở activity khác để có thể phục hồi khi bị kill.
      if (!await _saveDraft(notify: false)) return;
      await ref.read(materialDraftStoreProvider).write('picker-context', {
        'actor': _actor,
        'draftKey': _draftKey,
      });
      final picker = ref.read(materialImagePickerProvider);
      final files = source == ImageSource.camera
          ? [
              await picker.pickImage(
                source: source,
                maxWidth: 2000,
                maxHeight: 2000,
                imageQuality: 88,
              ),
            ].whereType<XFile>().toList()
          : await picker.pickMultiImage(
              maxWidth: 2000,
              maxHeight: 2000,
              imageQuality: 88,
              limit: 5 - _photos.length,
            );
      if (!mounted || !_sameActor) return;
      await _acceptFiles(files);
      await ref.read(materialDraftStoreProvider).remove('picker-context');
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is AppError ? e : StateError('PHOTO_PERMISSION'),
        );
      }
    }
  }

  Future<void> _acceptFiles(List<XFile> files) async {
    for (final file in files) {
      if (_photos.length >= 5) break;
      final length = await file.length();
      if (length <= 0 || length > MaterialValidation.maxImageBytes) {
        throw const AppError(DomainErrorCode.invalidInput, '');
      }
      final bytes = await file.readAsBytes();
      final mime = _mime(bytes);
      if (mime == null) throw const AppError(DomainErrorCode.invalidInput, '');
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final pixels = frame.image.width * frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (pixels > 40000000) {
        throw const AppError(DomainErrorCode.invalidInput, '');
      }
      if (!mounted || !_sameActor) return;
      _photos.add(
        _PhotoEdit(
          local: MaterialPhoto(
            localId: const Uuid().v4(),
            name: file.name,
            mimeType: mime,
            bytes: bytes,
          ),
        ),
      );
    }
    if (mounted) {
      _touch();
      await _saveDraft(notify: false);
    }
  }

  String? _mime(Uint8List b) {
    if (b.length >= 8 &&
        b[0] == 137 &&
        b[1] == 80 &&
        b[2] == 78 &&
        b[3] == 71) {
      return 'image/png';
    }
    if (b.length >= 3 && b[0] == 255 && b[1] == 216 && b[2] == 255) {
      return 'image/jpeg';
    }
    if (b.length >= 12 &&
        ascii.decode(b.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(b.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  Future<void> _remove(_PhotoEdit p) async {
    final t = AppLocalizations.of(context)!;
    if (!await showStudyConfirm(
          context,
          title: t.matRemoveImage,
          message: t.matRemoveImageBody,
          confirmLabel: t.matRemoveImage,
          destructive: true,
        ) ||
        !mounted) {
      return;
    }
    _photos.remove(p);
    _touch();
  }

  Future<void> _leave() async {
    if (_busy || _closing) return;
    _closing = true;
    if (!_changed && !_uncertain) {
      _exit();
      _closing = false;
      return;
    }
    final t = AppLocalizations.of(context)!;
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        scrollable: true,
        title: Text(t.matLeaveTitle),
        content: Text(t.matLeaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'keep'),
            child: Text(t.matKeepEditing),
          ),
          if (!_uncertain)
            TextButton(
              onPressed: () => Navigator.pop(c, 'discard'),
              child: Text(t.matDiscard),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(c, 'draft'),
            child: Text(t.matSaveDraft),
          ),
        ],
      ),
    );
    if (!mounted) {
      _closing = false;
      return;
    }
    if (choice == 'draft' && await _saveDraft()) {
      _exit();
    }
    if (choice == 'discard') {
      await ref.read(materialDraftStoreProvider).remove(_draftKey);
      if (mounted) _exit();
    }
    _closing = false;
  }

  void _exit() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.myMaterials);
    }
  }

  Future<void> _reload() async {
    if (widget.materialId == null || _busy) return;
    if (!await _saveDraft()) return;
    try {
      final d = await ref
          .read(materialWorkspaceProvider)
          .getDetails(widget.materialId!);
      if (!mounted || !_sameActor) return;
      if (d == null) throw const AppError(DomainErrorCode.forbidden, '');
      setState(() {
        _fill(d);
        _error = null;
        _uncertain = false;
        _key = const Uuid().v4();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _save() async {
    if (_busy ||
        !_sameActor ||
        !_valid ||
        !(_form.currentState?.validate() ?? false)) {
      return;
    }
    final t = AppLocalizations.of(context)!;
    final feedback = StudyFeedbackHost.of(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_uncertain) {
        final summary =
            '${t.matConfirmBody}\n\n${_title.text.trim()}\n${t.matSubject}: ${_subject.text.trim()}\n${t.matCondition}: ${_condition.text.trim()}\n${t.matImages}: ${_photos.length}${_description.text.trim().isEmpty ? '' : '\n${t.matDescription}: ${_description.text.trim()}'}${_isbn.text.trim().isEmpty ? '' : '\nISBN: ${_isbn.text.trim()}'}';
        if (!await showStudyConfirm(
          context,
          title: widget.materialId == null
              ? t.matConfirmCreate
              : t.matConfirmEdit,
          message: summary,
          confirmLabel: widget.materialId == null
              ? t.matSave
              : t.matSaveChanges,
        )) {
          return;
        }
      }
      if (!mounted || !_sameActor) return;
      final repo = ref.read(materialWorkspaceProvider);
      for (var i = 0; i < _photos.length; i++) {
        final p = _photos[i];
        if (p.uploaded != null) continue;
        setState(() {
          _progress = '${t.matUploadProgress} ${i + 1}/${_photos.length}';
          p.error = false;
        });
        try {
          p.uploaded = await repo.uploadImage(
            p.local!,
            materialId: widget.materialId,
          );
        } catch (e) {
          p.error = true;
          rethrow;
        }
        if (!mounted || !_sameActor) return;
      }
      setState(() => _progress = t.matSaveProgress);
      // Persist same key + uploaded IDs before the network command.
      _uncertain = true;
      if (!await _saveDraft(notify: false)) {
        _uncertain = false;
        return;
      }
      final input = CreateMaterialInput(
        title: _title.text.trim(),
        subject: _subject.text.trim(),
        condition: _condition.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        isbn: _isbn.text.trim().isEmpty
            ? null
            : MaterialValidation.normalizeIsbn(_isbn.text),
        imageIds: _photos.map((p) => p.uploaded!.id).toList(),
      );
      final result = widget.materialId == null
          ? await repo.createMaterial(input, idempotencyKey: _key)
          : await repo.updateMaterial(
              widget.materialId!,
              input,
              expectedRevision: _revision!,
              idempotencyKey: _key,
            );
      if (!mounted || !_sameActor) return;
      if (result case CommandError<Material>(:final code)) {
        _uncertain = code == DomainErrorCode.timeoutUnknown;
        throw AppError(code, '');
      }
      final saved = (result as CommandOk<Material>).data;
      _uncertain = false;
      // ACK đã nhận: lỗi dọn nháp không được biến thành lỗi tạo Material.
      try {
        await ref.read(materialDraftStoreProvider).remove(_draftKey);
      } catch (_) {}
      if (!mounted || !_sameActor) return;
      ref.invalidate(materialDetailsProvider(saved.id));
      feedback?.show(t.matSaved);
      setState(() => _allowPop = true);
      context.pushReplacement(AppRoutes.materialDetails(saved.id));
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
        await _saveDraft(notify: false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final s = Theme.of(context).colorScheme;
    ref.listen(sessionBoundaryProvider, (_, next) {
      if (next != _actor && mounted) {
        setState(() => _allowPop = true);
      }
    });
    String? error;
    if (_error != null) {
      error = _error.toString().contains('DRAFT_WRITE_FAILED')
          ? t.matDraftError
          : _error.toString().contains('PHOTO_PERMISSION')
          ? t.matPhotoPermission
          : materialError(_error!, t);
    }
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.materialId == null ? t.matAdd : t.matEdit),
          leading: IconButton(
            onPressed: _busy ? null : _leave,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              onPressed: _editable ? () => _saveDraft() : null,
              tooltip: t.matSaveDraft,
              icon: const Icon(Icons.save_outlined),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.materialId == null) ...[
                              Text(
                                t.matNewTitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                t.matFormHint,
                                style: TextStyle(color: s.onSurfaceVariant),
                              ),
                              const SizedBox(height: 24),
                            ],
                            if (_details != null && !_details!.canEdit) ...[
                              MaterialNotice(
                                _details!.isCached
                                    ? t.matCached
                                    : materialBlock(
                                        _details!.editBlockedReason,
                                        t,
                                      ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.photo_library_outlined,
                                          color: s.primary,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            t.matImages,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                        ),
                                        Text('${_photos.length}/5'),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      t.matImagesHint,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    const SizedBox(height: 16),
                                    if (_photos.isEmpty)
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: s.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons
                                                  .add_photo_alternate_outlined,
                                              size: 44,
                                              color: s.primary,
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              t.matTip,
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 12,
                                      children: [
                                        for (var i = 0; i < _photos.length; i++)
                                          SizedBox(
                                            width: 126,
                                            child: Column(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  child: AspectRatio(
                                                    aspectRatio: 1,
                                                    child: MaterialPhotoView(
                                                      image:
                                                          _photos[i].local !=
                                                              null
                                                          ? MaterialImage(
                                                              id: 'local',
                                                              storagePath: '',
                                                              bytes: _photos[i]
                                                                  .local!
                                                                  .bytes,
                                                            )
                                                          : _photos[i].uploaded,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                if (_photos[i].error)
                                                  Text(
                                                    t.matImageFailed,
                                                    style: TextStyle(
                                                      color: s.error,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        i == 0
                                                            ? t.matCover
                                                            : (i + 1)
                                                                  .toString(),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .labelMedium,
                                                      ),
                                                    ),
                                                    PopupMenuButton<String>(
                                                      enabled: _editable,
                                                      tooltip: t.matImages,
                                                      onSelected: (v) {
                                                        if (v == 'remove') {
                                                          _remove(_photos[i]);
                                                        } else {
                                                          final p = _photos
                                                              .removeAt(i);
                                                          _photos.insert(0, p);
                                                          _touch();
                                                        }
                                                      },
                                                      itemBuilder: (_) => [
                                                        if (i != 0)
                                                          PopupMenuItem(
                                                            value: 'cover',
                                                            child: Text(
                                                              t.matMakeCover,
                                                            ),
                                                          ),
                                                        PopupMenuItem(
                                                          value: 'remove',
                                                          child: Text(
                                                            t.matRemoveImage,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      key: const ValueKey('material-add-photo'),
                                      onPressed: _editable && _photos.length < 5
                                          ? _pick
                                          : null,
                                      icon: const Icon(Icons.add),
                                      label: Text(t.matAddImage),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _field(
                              'material-title',
                              _title,
                              t.matName,
                              200,
                              (v) => MaterialValidation.text(v, 200)
                                  ? null
                                  : t.matRequired200,
                            ),
                            _field(
                              'material-subject',
                              _subject,
                              t.matSubject,
                              100,
                              (v) => MaterialValidation.text(v, 100)
                                  ? null
                                  : t.matRequired100,
                            ),
                            _field(
                              'material-condition',
                              _condition,
                              t.matCondition,
                              100,
                              (v) => MaterialValidation.text(v, 100)
                                  ? null
                                  : t.matRequired100,
                            ),
                            _field(
                              'material-description',
                              _description,
                              t.matDescription,
                              2000,
                              (v) =>
                                  v.trim().isEmpty ||
                                      MaterialValidation.text(v, 2000)
                                  ? null
                                  : t.matDescriptionLimit,
                              lines: 4,
                            ),
                            _field(
                              'material-isbn',
                              _isbn,
                              t.matIsbn,
                              32,
                              (v) => MaterialValidation.isbn(v)
                                  ? null
                                  : t.matInvalidIsbn,
                            ),
                            if (error != null) ...[
                              MaterialNotice(error, error: true),
                              if (_error is AppError &&
                                  (_error as AppError).code ==
                                      DomainErrorCode.conflict)
                                TextButton.icon(
                                  onPressed: _reload,
                                  icon: const Icon(Icons.refresh),
                                  label: Text(t.matRefresh),
                                ),
                            ],
                            if (_busy && _progress.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const LinearProgressIndicator(),
                              const SizedBox(height: 8),
                              Semantics(
                                liveRegion: true,
                                child: Text(_progress),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        bottomNavigationBar: AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      key: const ValueKey('material-save'),
                      onPressed:
                          !_busy &&
                              (widget.materialId == null || _details != null) &&
                              _valid &&
                              (_changed || _uncertain) &&
                              (_details == null || _details!.canEdit)
                          ? _save
                          : null,
                      icon: Icon(
                        _busy ? Icons.hourglass_top : Icons.check_rounded,
                      ),
                      label: Text(
                        widget.materialId == null
                            ? t.matSave
                            : t.matSaveChanges,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String key,
    TextEditingController controller,
    String label,
    int max,
    String? Function(String) validator, {
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      enabled: _editable,
      maxLength: max,
      maxLines: lines,
      minLines: lines,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: lines == 1
          ? TextInputAction.next
          : TextInputAction.newline,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: lines > 1,
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: (_) => _touch(),
      validator: (v) => validator(v ?? ''),
    ),
  );
}

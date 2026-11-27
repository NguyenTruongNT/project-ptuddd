import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/auth/auth_session_providers.dart';
import '../../../core/contracts/models/material.dart' as model;
import '../../../design_system/widgets/feature_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../../materials/presentation/material_widgets.dart';
import '../../materials/providers/material_providers.dart';
import 'listing_widgets.dart';
import 'publish_page.dart';

/// Bước chọn tài liệu có route riêng để Back trở về đúng tab và trạng thái cũ.
class ListingMaterialPickerPage extends ConsumerStatefulWidget {
  const ListingMaterialPickerPage({super.key});
  @override
  ConsumerState<ListingMaterialPickerPage> createState() =>
      _ListingMaterialPickerPageState();
}

class _ListingMaterialPickerPageState
    extends ConsumerState<ListingMaterialPickerPage> {
  final _search = TextEditingController();
  final _items = <model.MaterialSummary>[];
  late final String _actor;
  bool _loading = true, _more = false, _cached = false, _opening = false;
  Object? _error;
  String? _createdId;
  int _generation = 0;
  bool get _same => mounted && _actor == ref.read(sessionBoundaryProvider);

  @override
  void initState() {
    super.initState();
    _actor = ref.read(sessionBoundaryProvider);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    if (!_same) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _more = false;
    });
    try {
      // Không lọc canPublish: còn phải thấy nháp, tin ẩn và lý do bị khóa.
      final target = append || _items.length < 20 ? 20 : _items.length;
      final rows = <model.MaterialSummary>[];
      var hasMore = true, cached = false;
      while (rows.length < target && hasMore) {
        final remaining = target - rows.length;
        final page = await ref
            .read(materialWorkspaceProvider)
            .searchMaterials(
              query: _search.text.trim(),
              offset: (append ? _items.length : 0) + rows.length,
              limit: remaining > 100 ? 100 : remaining,
            );
        if (!_same || generation != _generation) return;
        rows.addAll(page.items);
        hasMore = page.hasMore && page.items.isNotEmpty;
        cached = cached || page.isCached;
      }
      if (!_same || generation != _generation) return;
      setState(() {
        if (!append) _items.clear();
        _items.addAll(rows);
        _more = hasMore;
        _cached = cached;
        _loading = false;
      });
    } catch (e) {
      if (_same && generation == _generation) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _add() async {
    if (_opening || !_same) return;
    setState(() => _opening = true);
    try {
      final saved = await context.push<model.Material>(
        '${AppRoutes.materialForm}?completion=return',
      );
      if (!mounted || !_same) return;
      if (saved != null) {
        // Chỉ dùng ID thật sau ACK; đưa tài liệu mới vào kết quả, không tự đăng tin.
        _search.text = saved.title;
        _createdId = saved.id;
      }
      await _load();
    } finally {
      if (_same) setState(() => _opening = false);
    }
  }

  Future<void> _open(model.MaterialSummary material) async {
    if (_opening || !_same) return;
    setState(() => _opening = true);
    try {
      final publishedId = await context.push<String>(
        listingFormLocation(
          materialId: material.id,
          returnPublishedResult: true,
        ),
      );
      if (!mounted || !_same) return;
      if (publishedId != null) {
        // Trả về danh sách để loại bỏ bước chọn đã hoàn tất khỏi lịch sử.
        if (context.canPop()) {
          context.pop(publishedId);
        } else {
          context.go(AppRoutes.listingDetails(publishedId));
        }
      } else {
        await _load();
      }
    } finally {
      if (_same) setState(() => _opening = false);
    }
  }

  String _action(model.MaterialSummary material, AppLocalizations t) =>
      switch (material.listingStatus) {
        'DRAFT' => t.listingContinueDraft,
        'PUBLISHED' => t.listingManagePublished,
        'HIDDEN' => t.listingManageHidden,
        _ =>
          material.hasActiveTransaction || material.holderId != material.ownerId
              ? t.listingMaterialUnavailable
              : t.listingCreateFormTitle,
      };

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final same = ref.watch(sessionBoundaryProvider) == _actor;
    return FeatureScaffold(
      title: t.listingPickerTitle,
      fallbackLocation: AppRoutes.publishTab,
      actions: [
        IconButton(
          onPressed: !same || _loading || _opening ? null : () => _load(),
          icon: const Icon(Icons.refresh),
          tooltip: t.listingRetry,
        ),
      ],
      body: !same
          ? Center(child: Text(t.matForbidden))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                key: const PageStorageKey('listing-material-picker'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(t.listingPickerHint),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('listing-add-material'),
                    onPressed: _opening ? null : _add,
                    icon: const Icon(Icons.add),
                    label: Text(t.listingAddMaterial),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('listing-material-search'),
                    controller: _search,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: t.listingMaterialSearch,
                      counterText: '',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        tooltip: t.listingMaterialSearch,
                        onPressed: () => _load(),
                      ),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                  const SizedBox(height: 16),
                  if (_cached)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MaterialNotice(t.matCached),
                    ),
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null)
                    ListingErrorView(
                      message: listingError(_error!, t),
                      onRetry: () => _load(),
                    )
                  else if (!_loading && _items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            _search.text.trim().isEmpty
                                ? t.listingNoMaterials
                                : t.listingNoResults,
                            textAlign: TextAlign.center,
                          ),
                          if (_search.text.trim().isNotEmpty)
                            TextButton(
                              onPressed: () {
                                _search.clear();
                                _load();
                              },
                              child: Text(t.listingClearSearch),
                            ),
                        ],
                      ),
                    ),
                  if (_error == null)
                    for (final material in _items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            key: ValueKey('listing-material-${material.id}'),
                            contentPadding: const EdgeInsets.all(12),
                            selected: material.id == _createdId,
                            leading: SizedBox(
                              width: 48,
                              height: 64,
                              child: MaterialPhotoView(url: material.coverUrl),
                            ),
                            title: Text(material.title),
                            subtitle: Text(
                              '${material.subject}\n${_action(material, t)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _opening ? null : () => _open(material),
                          ),
                        ),
                      ),
                  if (_more && !_loading && _error == null)
                    OutlinedButton(
                      onPressed: () => _load(append: true),
                      child: Text(t.listingMore),
                    ),
                ],
              ),
            ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../design_system/widgets/feature_scaffold.dart';
import '../../../core/auth/auth_session_providers.dart';
import '../../../core/contracts/models/material.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/material_providers.dart';
import 'material_widgets.dart';

class MyMaterialsPage extends ConsumerStatefulWidget {
  const MyMaterialsPage({super.key});
  @override
  ConsumerState<MyMaterialsPage> createState() => _MyMaterialsPageState();
}

class _MyMaterialsPageState extends ConsumerState<MyMaterialsPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<MaterialSummary> _items = [];
  String _filter = 'all';
  Object? _error;
  bool _loading = true, _more = false;
  bool _cached = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      if (!append) _items = [];
    });
    try {
      final page = await ref
          .read(materialWorkspaceProvider)
          .searchMaterials(
            query: _search.text,
            filter: _filter,
            offset: append ? _items.length : 0,
          );
      if (!mounted || request != _request) return;
      setState(() {
        _items = [if (append) ..._items, ...page.items];
        _more = page.hasMore;
        _cached = page.isCached;
      });
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final s = Theme.of(context).colorScheme;
    ref.listen(sessionBoundaryProvider, (_, _) => _load());
    // Danh sách là màn con của Home/Cá nhân; luôn có Back và dùng chung
    // khung điều hướng, kể cả khi mở URL trực tiếp hoặc tải dữ liệu lỗi.
    return FeatureScaffold(
      title: t.matTitle,
      fallbackLocation: AppRoutes.home,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _load(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  s.primaryContainer,
                                  s.secondaryContainer.withValues(alpha: .55),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [Text(t.matSubtitle)],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.auto_stories_rounded,
                                  size: 48,
                                  color: s.primary,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_cached) ...[
                            MaterialNotice(t.matCached),
                            const SizedBox(height: 12),
                          ],
                          TextField(
                            maxLength: 200,
                            key: const ValueKey('material-search'),
                            controller: _search,
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: t.matSearch,
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: t.matRefresh,
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        _search.clear();
                                        _load();
                                      },
                                    ),
                            ),
                            onChanged: (_) {
                              setState(() {});
                              _debounce?.cancel();
                              _debounce = Timer(
                                const Duration(milliseconds: 350),
                                () => _load(),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final entry in {
                                'all': t.matAll,
                                'ready': t.matReady,
                                'active': t.matActive,
                              }.entries)
                                ChoiceChip(
                                  label: Text(entry.value),
                                  selected: _filter == entry.key,
                                  onSelected: (_) {
                                    _filter = entry.key;
                                    _load();
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (_error != null) ...[
                            MaterialNotice(
                              materialError(_error!, t),
                              error: true,
                            ),
                            TextButton.icon(
                              onPressed: () => _load(),
                              icon: const Icon(Icons.refresh),
                              label: Text(t.matTryAgain),
                            ),
                          ],
                          if (_loading && _items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          if (!_loading && _error == null && _items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 44,
                                horizontal: 16,
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.shelves,
                                    size: 64,
                                    color: s.primary,
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    _search.text.isEmpty && _filter == 'all'
                                        ? t.matEmpty
                                        : t.matNoResults,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    t.matEmptyBody,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          for (final m in _items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  key: ValueKey('material-card-${m.id}'),
                                  onTap: () =>
                                      _open(AppRoutes.materialDetails(m.id)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          child: SizedBox(
                                            width: 70,
                                            height: 90,
                                            child: MaterialPhotoView(
                                              url: m.coverUrl,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                m.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                m.subject,
                                                style: TextStyle(
                                                  color: s.onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: [
                                                  _Tag(
                                                    m.hasActiveTransaction
                                                        ? t.matReserved
                                                        : m.listingStatus ==
                                                              'PUBLISHED'
                                                        ? t.matPublished
                                                        : m.listingStatus ==
                                                              'HIDDEN'
                                                        ? t.matHiddenListing
                                                        : m.listingStatus ==
                                                              'DRAFT'
                                                        ? t.matDraftListing
                                                        : t.matUnlisted,
                                                  ),
                                                  if (m.holderId != m.ownerId)
                                                    _Tag(t.matHeldOther),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right_rounded),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (_more)
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => _load(append: true),
                              child: Text(t.matLoadMore),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  key: const ValueKey('material-add'),
                  onPressed: () => _open(AppRoutes.materialForm),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(t.matAdd),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelMedium),
  );
}

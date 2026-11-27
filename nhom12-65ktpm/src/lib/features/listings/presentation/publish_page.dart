import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/auth/auth_session_providers.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/listing_workspace.dart';
import '../../../l10n/app_localizations.dart';
import '../../materials/presentation/material_widgets.dart';
import '../providers/listing_providers.dart';
import 'listing_widgets.dart';

String listingFormLocation({
  String? materialId,
  String? listingId,
  bool returnPublishedResult = false,
}) => Uri(
  path: AppRoutes.listingForm,
  queryParameters: {
    'materialId': ?materialId,
    'listingId': ?listingId,
    if (returnPublishedResult) 'completion': 'return',
  },
).toString();

class PublishPage extends ConsumerStatefulWidget {
  const PublishPage({super.key});
  @override
  ConsumerState<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends ConsumerState<PublishPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _status = 'all';
  bool _loading = true, _more = false;
  Object? _error;
  int _generation = 0;
  final _listings = <ManagedListing>[];
  Map<String, dynamic> _drafts = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    final generation = ++_generation;
    final actor = ref.read(sessionBoundaryProvider);
    bool current() =>
        mounted &&
        generation == _generation &&
        actor == ref.read(sessionBoundaryProvider);
    setState(() {
      _loading = true;
      _error = null;
      _more = false;
    });
    try {
      // Nháp local vẫn truy cập được nếu RPC danh sách gặp lỗi hoặc mất mạng.
      final drafts = await ref.read(listingDraftsProvider).all(actor);
      if (!current()) return;
      setState(() => _drafts = drafts);
      // Quay từ màn con phải nạp đủ số dòng đã xem, tránh co danh sách về trang 1
      // làm mất vị trí cuộn. Mỗi RPC vẫn tuân thủ giới hạn tối đa 100 dòng.
      final target = append || _listings.length < 20 ? 20 : _listings.length;
      final rows = <ManagedListing>[];
      var hasMore = true;
      while (rows.length < target && hasMore) {
        final remaining = target - rows.length;
        final page = await ref
            .read(listingWorkspaceProvider)
            .searchMine(
              status: _status,
              query: _search.text.trim(),
              offset: (append ? _listings.length : 0) + rows.length,
              limit: remaining > 100 ? 100 : remaining,
            );
        if (!current()) return;
        rows.addAll(page.items);
        hasMore = page.hasMore && page.items.isNotEmpty;
      }
      if (!current()) return;
      setState(() {
        if (!append) _listings.clear();
        _listings.addAll(rows);
        _more = hasMore;
        _loading = false;
      });
    } catch (e) {
      // Không hiện kết quả hoặc lỗi từ tài khoản cũ sau khi đổi phiên.
      if (current()) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _open(String location) async {
    final actor = ref.read(sessionBoundaryProvider);
    final publishedId = await context.push<String>(location);
    if (!mounted || actor != ref.read(sessionBoundaryProvider)) return;
    await _load();
    if (!mounted || actor != ref.read(sessionBoundaryProvider)) return;
    if (publishedId != null) {
      // Các bước chọn/form đã hoàn tất được đóng; Back ở chi tiết về danh sách này.
      await context.push(AppRoutes.listingDetails(publishedId));
      if (mounted && actor == ref.read(sessionBoundaryProvider)) await _load();
    }
  }

  Future<void> _filter() async {
    final t = AppLocalizations.of(context)!;
    final actor = ref.read(sessionBoundaryProvider);
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  t.listingFilterTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final status in [
                'all',
                ...ListingStatus.values.map((s) => s.wire),
              ])
                ListTile(
                  key: ValueKey('listing-status-$status'),
                  title: Text(
                    status == 'all'
                        ? t.listingAll
                        : listingStatusLabel(ListingStatus.fromWire(status), t),
                  ),
                  selected: status == _status,
                  trailing: status == _status ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, status),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (!mounted ||
        selected == null ||
        selected == _status ||
        actor != ref.read(sessionBoundaryProvider)) {
      return;
    }
    setState(() => _status = selected);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final actor = ref.watch(sessionBoundaryProvider);
    ref.listen(sessionBoundaryProvider, (_, _) {
      _generation++;
      _listings.clear();
      _drafts = {};
      _search.clear();
      _status = 'all';
      if (_scroll.hasClients) _scroll.jumpTo(0);
      Future.microtask(_load);
    });
    final filtered = _status != 'all' || _search.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.listingTitle),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh),
            tooltip: t.listingRetry,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            key: PageStorageKey('publish-$actor'),
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              // Tab chỉ giữ một thao tác chính; chọn/thêm tài liệu nằm ở màn con.
              FilledButton.icon(
                key: const ValueKey('listing-create'),
                onPressed: () => _open(AppRoutes.listingMaterialPicker),
                icon: const Icon(Icons.add),
                label: Text(t.listingCreate),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('listing-search'),
                controller: _search,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: t.listingSearch,
                  counterText: '',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: t.listingSearch,
                    onPressed: () => _load(),
                  ),
                ),
                onSubmitted: (_) => _load(),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  key: const ValueKey('listing-status-filter'),
                  onPressed: _filter,
                  icon: const Icon(Icons.filter_list),
                  label: Text(
                    t.listingFilterLabel(
                      _status == 'all'
                          ? t.listingAll
                          : listingStatusLabel(
                              ListingStatus.fromWire(_status),
                              t,
                            ),
                    ),
                  ),
                ),
              ),
              if (actor == 'demo')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(t.listingDemo),
                ),
              if (_drafts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  t.listingLocalSection,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final entry in _drafts.entries)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.phone_android),
                      title: Text(
                        (entry.value as Map)['title'] as String? ??
                            t.listingDraft,
                      ),
                      subtitle: Text(t.listingLocalSaved),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(
                        listingFormLocation(
                          materialId:
                              (entry.value as Map)['material_id'] as String?,
                          listingId:
                              (entry.value as Map)['listing_id'] as String?,
                          returnPublishedResult: true,
                        ),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                ListingErrorView(
                  message: listingError(_error!, t),
                  onRetry: () => _load(),
                )
              else if (!_loading && _listings.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        filtered ? t.listingNoResults : t.listingEmpty,
                        textAlign: TextAlign.center,
                      ),
                      if (filtered)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _status = 'all';
                              _search.clear();
                            });
                            _load();
                          },
                          child: Text(t.listingClearFilters),
                        ),
                    ],
                  ),
                ),
              if (_error == null)
                for (final d in _listings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: SizedBox(
                          width: 48,
                          height: 64,
                          child: MaterialPhotoView(url: d.coverUrl),
                        ),
                        title: Text(d.title),
                        subtitle: Text(
                          '${listingStatusLabel(d.listing.status, t)} · ${offerLabel(d.listing.offerType, t)}'
                          '${d.listing.askingPriceVnd == null ? '' : '\n${d.listing.askingPriceVnd} VND'}'
                          '${d.hasActiveTransaction ? '\n${t.listingReserved}' : ''}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(
                          listingFormLocation(
                            listingId: d.listing.id,
                            returnPublishedResult: true,
                          ),
                        ),
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
      ),
    );
  }
}

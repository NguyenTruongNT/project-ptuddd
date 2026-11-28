import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/auth/auth_session_providers.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/listing.dart';
import '../../../core/contracts/models/material.dart' as model;
import '../../../core/preferences/app_preferences.dart';
import '../../../design_system/decorations/grid_paper.dart';
import '../../../design_system/decorations/leaf_fall_overlay.dart';
import '../../../l10n/app_localizations.dart';
import '../../listings/presentation/listing_widgets.dart';
import '../../listings/presentation/publish_page.dart';
import '../../materials/presentation/material_widgets.dart';
import '../providers/home_providers.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final AppLifecycleListener _lifecycle;
  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (mounted) refreshHome(ref);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _push(String location) async {
    await context.push(location);
    if (mounted) refreshHome(ref);
  }

  Future<void> _addMaterial() async {
    // Form trả ACK về caller rồi đóng; mở detail trên Home, không để form tạo
    // cũ trong Back stack và không làm ảnh hưởng luồng chọn Material của Listing.
    final material = await context.push<model.Material>(
      '${AppRoutes.materialForm}?completion=return',
    );
    if (!mounted) return;
    refreshHome(ref);
    if (material != null) await _push(AppRoutes.materialDetails(material.id));
  }

  Widget _error(Object error, VoidCallback retry) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(listingError(error, AppLocalizations.of(context)!)),
      TextButton(
        onPressed: retry,
        child: Text(AppLocalizations.of(context)!.homeRetry),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final preferences = ref.watch(appPreferencesProvider);
    final name =
        ref.watch(currentProfileProvider).asData?.value?.displayName ??
        t.homeFallbackName;
    final overview = ref.watch(homeOverviewProvider);
    final drafts = ref.watch(homeDraftsProvider);
    final recent = ref.watch(homeRecentListingsProvider);
    return Stack(
      children: [
        if (preferences.showGrid)
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: GridPaperPainter()),
            ),
          ),
        if (preferences.showLeaves)
          const Positioned.fill(child: IgnorePointer(child: LeafFallOverlay())),
        RefreshIndicator(
          onRefresh: () async {
            refreshHome(ref);
            // Mỗi khối tự hiển thị lỗi; một nguồn lỗi không làm lỗi toàn Trang chủ.
            await Future.wait([
              ref
                  .read(homeOverviewProvider.future)
                  .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
              ref
                  .read(homeRecentListingsProvider.future)
                  .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
              ref
                  .read(homeDraftsProvider.future)
                  .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.homeHello(name),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: t.matRefresh,
                    onPressed: () => refreshHome(ref),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(t.homeIntro),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _addMaterial,
                    icon: const Icon(Icons.add),
                    label: Text(t.homeAddMaterial),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _push(AppRoutes.myMaterials),
                    icon: const Icon(Icons.menu_book),
                    label: Text(t.homeMyMaterials),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.publishTab),
                    icon: const Icon(Icons.campaign_outlined),
                    label: Text(t.homeManageListings),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                t.homeOverviewTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              overview.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) =>
                    _error(error, () => ref.invalidate(homeOverviewProvider)),
                data: (value) => LayoutBuilder(
                  builder: (context, box) {
                    final columns = box.maxWidth < 600 ? 2 : 4;
                    final width = (box.maxWidth - (columns - 1) * 12) / columns;
                    Widget metric(
                      String label,
                      int count,
                      VoidCallback onTap,
                    ) => SizedBox(
                      width: width,
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$count',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                Text(label),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        metric(
                          t.homeOwnedCount,
                          value.materialCount,
                          () => _push(AppRoutes.myMaterials),
                        ),
                        metric(
                          t.homePublishedCount,
                          value.publishedCount,
                          () => context.go(AppRoutes.publishTab),
                        ),
                        metric(
                          t.homeDraftCount,
                          value.draftCount,
                          () => context.go(AppRoutes.publishTab),
                        ),
                        metric(
                          t.homeActiveCount,
                          value.activeTransactionCount,
                          () => context.go(AppRoutes.transactions),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                t.homeContinueDraft,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              drafts.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) =>
                    _error(error, () => ref.invalidate(homeDraftsProvider)),
                data: (items) => items.isEmpty
                    ? Text(t.homeNoDrafts)
                    : Column(
                        children: [
                          for (final item in items)
                            Card(
                              child: ListTile(
                                title: Text(item.title),
                                subtitle: Text(
                                  offerLabel(item.listing.offerType, t),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _push(
                                  listingFormLocation(
                                    listingId: item.listing.id,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
              Text(
                t.homeRecentTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              recent.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => _error(
                  error,
                  () => ref.invalidate(homeRecentListingsProvider),
                ),
                data: (items) => items.isEmpty
                    ? Text(t.homeNoListings)
                    : Column(
                        children: [
                          for (final item in items)
                            _ListingPreview(
                              item: item,
                              onTap: () => _push(
                                AppRoutes.listingDetails(item.listingId),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _ListingPreview extends StatelessWidget {
  const _ListingPreview({required this.item, required this.onTap});
  final ListingCardModel item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 86,
                child: MaterialPhotoView(url: item.coverUrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(offerLabel(item.offerType, t)),
                    if (item.offerType == OfferType.sell &&
                        item.askingPriceVnd != null)
                      Text('${item.askingPriceVnd} VND'),
                    if (item.isReserved) Text(t.listingReserved),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

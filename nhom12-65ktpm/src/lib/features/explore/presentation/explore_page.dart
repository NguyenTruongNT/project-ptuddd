import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/listing.dart';
import '../../../core/providers/mock_query_providers.dart';
import '../../../design_system/decorations/grid_paper.dart';
import '../../../design_system/widgets/study_async_view.dart';
import 'widgets/explore_listing_card.dart';

enum ExploreOfferFilter { all, borrow, donate, sell }

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;

  String _keyword = '';
  ExploreOfferFilter _filter = ExploreOfferFilter.all;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) {
    setState(() {});

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _keyword = value.trim().toLowerCase();
      });
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();

    setState(() {
      _keyword = '';
    });
  }

  void _retry() {
    ref.invalidate(publishedListingsProvider);
  }

  bool _matchesFilter(ListingCardModel listing) {
    return switch (_filter) {
      ExploreOfferFilter.all => true,
      ExploreOfferFilter.borrow => listing.offerType == OfferType.borrow,
      ExploreOfferFilter.donate => listing.offerType == OfferType.donate,
      ExploreOfferFilter.sell => listing.offerType == OfferType.sell,
    };
  }

  bool _matchesKeyword(ListingCardModel listing) {
    if (_keyword.isEmpty) {
      return true;
    }

    return listing.title.toLowerCase().contains(_keyword) ||
        listing.subject.toLowerCase().contains(_keyword);
  }

  List<ListingCardModel> _visibleListings(List<ListingCardModel> listings) {
    return listings
        .where(_matchesFilter)
        .where(_matchesKeyword)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ListingCardModel>> listings = ref.watch(
      publishedListingsProvider,
    );

    return Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: GridPaperPainter())),
        ),
        SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(publishedListingsProvider);
              await ref.read(publishedListingsProvider.future);
            },
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
                            _buildHeader(context),
                            const SizedBox(height: 20),
                            _buildSearchField(),
                            const SizedBox(height: 12),
                            _buildFilters(),
                            const SizedBox(height: 16),
                            StudyAsyncView<List<ListingCardModel>>(
                              value: listings,
                              onRetry: _retry,
                              isEmpty: (items) =>
                                  _visibleListings(items).isEmpty,
                              emptyMessage:
                                  _keyword.isEmpty &&
                                      _filter == ExploreOfferFilter.all
                                  ? 'Chưa có tin đăng công khai.'
                                  : 'Không tìm thấy tài liệu phù hợp.',
                              builder: (items) {
                                final visible = _visibleListings(items);

                                return Column(
                                  children: [
                                    for (final listing in visible)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: ExploreListingCard(
                                          listing: listing,
                                          onTap: () {
                                            context.push(
                                              AppRoutes.listingDetails(
                                                listing.listingId,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                );
                              },
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
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer,
            scheme.secondaryContainer.withValues(alpha: .55),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khám phá tài liệu',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tìm sách, giáo trình và tài liệu '
                  'đang được chia sẻ.',
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Icon(
                Icons.travel_explore_rounded,
                size: 48,
                color: scheme.primary,
              ),
              const SizedBox(height: 8),
              IconButton.filledTonal(
                key: const ValueKey('explore-open-requests'),
                tooltip: 'Yêu cầu của tôi',
                onPressed: () => context.push(AppRoutes.requestCenter),
                icon: const Icon(Icons.inbox_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      key: const ValueKey('explore-search'),
      controller: _searchController,
      maxLength: 200,
      decoration: InputDecoration(
        counterText: '',
        hintText: 'Tìm theo tên hoặc môn học',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                key: const ValueKey('explore-clear-search'),
                tooltip: 'Xóa tìm kiếm',
                onPressed: _clearSearch,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
      textInputAction: TextInputAction.search,
      onChanged: _handleSearchChanged,
    );
  }

  Widget _buildFilters() {
    const labels = <ExploreOfferFilter, String>{
      ExploreOfferFilter.all: 'Tất cả',
      ExploreOfferFilter.borrow: 'Mượn',
      ExploreOfferFilter.donate: 'Tặng',
      ExploreOfferFilter.sell: 'Bán',
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in labels.entries)
          ChoiceChip(
            key: ValueKey('explore-filter-${entry.key.name}'),
            label: Text(entry.value),
            selected: _filter == entry.key,
            onSelected: (_) {
              setState(() {
                _filter = entry.key;
              });
            },
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/contracts/domain_enums.dart';
import '../../../../core/contracts/models/listing.dart';
import '../../../materials/presentation/material_widgets.dart';

class ExploreListingCard extends StatelessWidget {
  const ExploreListingCard({
    super.key,
    required this.listing,
    required this.onTap,
  });

  final ListingCardModel listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('explore-card-${listing.listingId}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 76,
                  height: 100,
                  child: MaterialPhotoView(url: listing.coverUrl),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      listing.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _ListingTag(
                          label: _offerLabel(listing.offerType),
                          background: scheme.primaryContainer,
                          foreground: scheme.onPrimaryContainer,
                        ),
                        _ListingTag(
                          label: listing.isReserved
                              ? 'Đã giữ chỗ'
                              : 'Có thể yêu cầu',
                          background: listing.isReserved
                              ? scheme.errorContainer
                              : scheme.secondaryContainer,
                          foreground: listing.isReserved
                              ? scheme.onErrorContainer
                              : scheme.onSecondaryContainer,
                        ),
                      ],
                    ),
                    if (listing.offerType == OfferType.sell) ...[
                      const SizedBox(height: 10),
                      Text(
                        _formatVnd(listing.askingPriceVnd),
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListingTag extends StatelessWidget {
  const _ListingTag({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _offerLabel(OfferType offerType) {
  return switch (offerType) {
    OfferType.borrow => 'Cho mượn',
    OfferType.donate => 'Tặng miễn phí',
    OfferType.sell => 'Bán lại',
  };
}

String _formatVnd(int? value) {
  if (value == null) {
    return 'Chưa có giá';
  }

  final String digits = value.toString();
  final StringBuffer output = StringBuffer();

  for (int index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      output.write('.');
    }
    output.write(digits[index]);
  }

  return '${output.toString()} đ';
}

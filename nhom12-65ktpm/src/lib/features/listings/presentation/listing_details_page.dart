import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../design_system/widgets/feature_scaffold.dart';
import '../../materials/presentation/material_widgets.dart';
import '../providers/listing_providers.dart';
import 'listing_widgets.dart';
import 'publish_page.dart';

// Bề mặt đọc tối thiểu của contract ngày 3; Khanh tiếp tục module SCR-06/Request.
class ListingDetailsPage extends ConsumerWidget {
  const ListingDetailsPage({super.key, required this.listingId});
  final String listingId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final data = ref.watch(listingDetailsProvider(listingId));
    return FeatureScaffold(
      title: t.listingDetailsTitle,
      fallbackLocation: AppRoutes.publishTab,
      actions: [
        IconButton(
          onPressed: () => ref.invalidate(listingDetailsProvider(listingId)),
          icon: const Icon(Icons.refresh),
          tooltip: t.listingRetry,
        ),
      ],
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListingErrorView(
          message: listingError(e, t),
          onRetry: () => ref.invalidate(listingDetailsProvider(listingId)),
        ),
        data: (d) {
          if (d == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.listingNotFound),
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (d.images.isNotEmpty)
                    SizedBox(
                      height: 260,
                      child: PageView(
                        children: [
                          for (final i in d.images)
                            MaterialPhotoView(url: i.url, fit: BoxFit.contain),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    d.card.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text('${d.card.subject} · ${d.card.condition}'),
                  Chip(label: Text(offerLabel(d.card.offerType, t))),
                  if (d.card.askingPriceVnd != null)
                    Text(
                      '${d.card.askingPriceVnd} VND',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  if (d.card.isReserved) MaterialNotice(t.listingReserved),
                  const SizedBox(height: 16),
                  Text('${t.listingOwner}: ${d.ownerName}'),
                  if (d.isbn != null) Text('ISBN: ${d.isbn}'),
                  if (d.materialDescription != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(d.materialDescription!),
                    ),
                  if (d.description != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(d.description!),
                    ),
                  if (d.meetingArea != null)
                    Text('${t.listingArea}: ${d.meetingArea}'),
                  if (d.card.offerType.wire == 'BORROW')
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(t.listingBorrowPolicy),
                    ),
                  const SizedBox(height: 20),
                  if (d.card.isOwner)
                    FilledButton(
                      onPressed: () => context.push(
                        listingFormLocation(listingId: listingId),
                      ),
                      child: Text(t.listingManage),
                    )
                  else if (d.card.hasPendingRequest)
                    OutlinedButton(
                      onPressed: () => context.push(AppRoutes.requestCenter),
                      child: Text(t.listingOwnRequest),
                    )
                  else
                    FilledButton(
                      onPressed: d.card.isRequestable
                          ? () =>
                                context.push(AppRoutes.createRequest(listingId))
                          : null,
                      child: Text(
                        d.card.isReserved
                            ? t.listingReserved
                            : t.listingRequest,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

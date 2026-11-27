import 'package:flutter/material.dart';

import '../../../core/contracts/domain_enums.dart';
import '../../../core/errors/app_error.dart';
import '../../../l10n/app_localizations.dart';

String offerLabel(OfferType offer, AppLocalizations t) => switch (offer) {
  OfferType.borrow => t.listingBorrow,
  OfferType.sell => t.listingSell,
  OfferType.donate => t.listingDonate,
};
String listingStatusLabel(ListingStatus status, AppLocalizations t) =>
    switch (status) {
      ListingStatus.draft => t.listingDraft,
      ListingStatus.published => t.listingPublished,
      ListingStatus.hidden => t.listingHidden,
      ListingStatus.archived => t.listingArchived,
    };
String listingError(Object error, AppLocalizations t) {
  final code = error is AppError ? error.code : null;
  return switch (code) {
    DomainErrorCode.authRequired || DomainErrorCode.forbidden => t.matForbidden,
    DomainErrorCode.invalidInput => t.listingInvalid,
    DomainErrorCode.conflict => t.listingMaterialChanged,
    DomainErrorCode.materialUnavailable => t.listingLocked,
    DomainErrorCode.timeoutUnknown => t.listingUnknown,
    DomainErrorCode.backendUnavailable => t.listingBackendUnavailable,
    DomainErrorCode.unexpectedError => t.listingUnexpectedError,
    _ => t.matNetwork,
  };
}

class ListingErrorView extends StatelessWidget {
  const ListingErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context)!.listingRetry),
          ),
        ],
      ),
    ),
  );
}

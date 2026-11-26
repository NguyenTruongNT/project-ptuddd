import 'package:flutter/material.dart';

import '../../../core/contracts/material_workspace.dart';
import '../../../core/errors/app_error.dart';
import '../../../l10n/app_localizations.dart';

String materialError(Object error, AppLocalizations t) {
  final code = error is AppError ? error.code : null;
  return switch (code) {
    DomainErrorCode.conflict => t.matConflict,
    DomainErrorCode.forbidden || DomainErrorCode.authRequired => t.matForbidden,
    DomainErrorCode.invalidInput => t.matImageInvalid,
    DomainErrorCode.evidenceUploadFailed => t.matImageFailed,
    DomainErrorCode.materialUnavailable => t.matLockedTransaction,
    DomainErrorCode.timeoutUnknown => t.matUnknown,
    _ => t.matNetwork,
  };
}

String materialBlock(String? reason, AppLocalizations t) => switch (reason) {
  'TRANSACTION_ACTIVE' => t.matLockedTransaction,
  'LISTING_PUBLISHED' => t.matLockedListing,
  'REQUEST_PENDING' => t.matLockedRequest,
  'NOT_CURRENT_HOLDER' => t.matLockedHolder,
  _ => t.matForbidden,
};

class MaterialPhotoView extends StatelessWidget {
  const MaterialPhotoView({
    super.key,
    this.image,
    this.url,
    this.fit = BoxFit.cover,
  });
  final MaterialImage? image;
  final String? url;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: scheme.primaryContainer.withValues(alpha: .4),
      child: Center(
        child: Icon(Icons.menu_book_rounded, size: 36, color: scheme.primary),
      ),
    );
    if (image?.bytes != null) {
      return Image.memory(
        image!.bytes!,
        fit: fit,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    final source = url ?? image?.url;
    if (source == null) return fallback;
    return Image.network(
      source,
      fit: fit,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
    );
  }
}

class MaterialNotice extends StatelessWidget {
  const MaterialNotice(this.message, {super.key, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: error ? s.errorContainer : s.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              error ? Icons.error_outline : Icons.info_outline,
              size: 20,
              color: error ? s.onErrorContainer : s.onSecondaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: error ? s.onErrorContainer : s.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

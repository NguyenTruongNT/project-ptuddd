import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/contracts/material_workspace.dart';
import '../../../design_system/widgets/study_feedback.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/material_providers.dart';
import 'material_widgets.dart';

class MaterialDetailsPage extends ConsumerWidget {
  const MaterialDetailsPage({super.key, required this.materialId});
  final String materialId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final data = ref.watch(materialDetailsProvider(materialId));
    return Scaffold(
      appBar: AppBar(
        title: Text(t.matDetails),
        actions: [
          IconButton(
            tooltip: t.matRefresh,
            onPressed: () =>
                ref.invalidate(materialDetailsProvider(materialId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: MaterialNotice(materialError(e, t), error: true),
          ),
        ),
        data: (d) => d == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(t.matNotFound, textAlign: TextAlign.center),
                ),
              )
            : _DetailsBody(
                details: d,
                onEdit: () async {
                  await context.push(AppRoutes.materialEdit(materialId));
                  if (context.mounted) {
                    ref.invalidate(materialDetailsProvider(materialId));
                  }
                },
              ),
      ),
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.details, required this.onEdit});
  final MaterialDetails details;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final s = Theme.of(context).colorScheme;
    final m = details.material;
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (details.isCached) ...[
                  MaterialNotice(t.matCached),
                  const SizedBox(height: 16),
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: details.images.isEmpty
                        ? const MaterialPhotoView()
                        : PageView(
                            children: [
                              for (final image in details.images)
                                Semantics(
                                  label: t.matImages,
                                  child: MaterialPhotoView(
                                    image: image,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  details.images.isEmpty
                      ? t.matNoImage
                      : '${details.images.length} ${t.matImages.toLowerCase()}',
                  style: TextStyle(color: s.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Text(
                  m.title,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  m.subject,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: s.primary),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Info(t.matCondition, m.condition),
                        if (m.description?.isNotEmpty ?? false) ...[
                          const Divider(height: 28),
                          _Info(t.matDescription, m.description!),
                        ],
                        if (m.isbn?.isNotEmpty ?? false) ...[
                          const Divider(height: 28),
                          _Info('ISBN', m.isbn!),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Info(t.matOwner, t.matYou),
                        const SizedBox(height: 16),
                        _Info(
                          t.matHolder,
                          m.ownerId == m.holderId
                              ? t.matYou
                              : (details.holderName ?? t.matHeldOther),
                        ),
                        const Divider(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                m.id,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            IconButton(
                              tooltip: t.matCopyId,
                              icon: const Icon(Icons.copy_outlined),
                              onPressed: () async {
                                final feedback = StudyFeedbackHost.of(context);
                                await Clipboard.setData(
                                  ClipboardData(text: m.id),
                                );
                                feedback?.show(t.matIdCopied);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!details.canEdit)
                  MaterialNotice(materialBlock(details.editBlockedReason, t)),
                if (details.canEdit && details.images.isEmpty)
                  MaterialNotice(t.matNoImageHint),
                if (details.canEdit) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      key: const ValueKey('material-edit'),
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(t.matEdit),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 6),
      SelectableText(value),
    ],
  );
}

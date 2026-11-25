import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/contracts/models/issue.dart';
import '../../../design_system/widgets/study_async_view.dart';
import '../../../design_system/widgets/study_empty.dart';
import '../../transactions/domain/transaction_labels.dart' show formatServerTimeVn;
import '../domain/issue_labels.dart';
import '../providers/issue_providers.dart';
import 'widgets/issue_actions.dart';
import 'widgets/issue_chips.dart';
import 'widgets/issue_timeline.dart';

// SCR-23 – Chi tiết sự cố (UI-09/UI-16, màn con). Chủ trì: Sơn.
// Các bên trao đổi phương án và cùng xác nhận; không ai (kể cả admin) đóng thay.
class IssueDetailsPage extends ConsumerWidget {
  const IssueDetailsPage({super.key, required this.issueId});

  final String issueId;

  static const noAccessMessage =
      'Không tìm thấy sự cố hoặc bạn không có quyền xem.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(issueDetailsProvider(issueId));

    Future<void> refresh() async {
      ref.invalidate(issueTimelineProvider(issueId));
      ref.invalidate(issueDetailsProvider(issueId));
      await ref.read(issueDetailsProvider(issueId).future);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết sự cố')),
      body: StudyAsyncView<IssueDetails?>(
        value: details,
        onRetry: () => ref.invalidate(issueDetailsProvider(issueId)),
        // Không phân biệt "không tồn tại" và "không có quyền" để tránh lộ dữ liệu.
        isEmpty: (data) => data == null,
        emptyMessage: noAccessMessage,
        builder: (data) => RefreshIndicator(
          onRefresh: refresh,
          child: _DetailsBody(details: data!),
        ),
      ),
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.details});
  final IssueDetails details;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _HeaderCard(details: details),
        if (details.proposal != null) _ProposalCard(details: details),
        IssueActionsCard(details: details),
        _TimelineSection(issueId: details.id),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.details});
  final IssueDetails details;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final issue = details.issue;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(details.materialTitle, style: textTheme.titleLarge),
            const SizedBox(height: 10),
            IssueChips(details: details),
            const SizedBox(height: 10),
            Text(issue.reason, style: textTheme.bodyMedium),
            const SizedBox(height: 10),
            Text(issueProgressVi(details), style: textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              '${issueRelationLabelVi(details)} · mở lúc '
              '${formatServerTimeVn(issue.openedAt)}',
              style: textTheme.bodySmall,
            ),
            if (issue.resolvedAt != null)
              Text(
                'Giải quyết lúc ${formatServerTimeVn(issue.resolvedAt!)}',
                style: textTheme.bodySmall,
              ),
            // C chỉ liên quan tới một chặng, không được xem toàn bộ giao dịch.
            if (details.canViewTransaction) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context
                      .push(AppRoutes.transactionDetails(issue.transactionId)),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Xem giao dịch'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({required this.details});
  final IssueDetails details;

  @override
  Widget build(BuildContext context) {
    final proposal = details.proposal!;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return _Section(
      title: 'Phương án giải quyết (bản ${proposal.revision})',
      children: [
        Text(proposal.summary, style: textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          '${proposal.proposedByDisplayName} đề xuất lúc '
          '${formatServerTimeVn(proposal.proposedAt)}',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        for (final consent in proposal.consents)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  consent.isApproved
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: consent.isApproved
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    consent.isApproved
                        ? '${consent.participantDisplayName} đã xác nhận lúc '
                            '${formatServerTimeVn(consent.approvedAt!)}'
                        : '${consent.participantDisplayName} chưa xác nhận',
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TimelineSection extends ConsumerWidget {
  const _TimelineSection({required this.issueId});
  final String issueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(issueTimelineProvider(issueId));
    return _Section(
      title: 'Diễn biến',
      children: [
        StudyAsyncView<List<IssueEventItem>>(
          value: timeline,
          isEmpty: (events) => events.isEmpty,
          emptyMessage: 'Chưa có sự kiện nào.',
          onRetry: () => ref.invalidate(issueTimelineProvider(issueId)),
          builder: (events) => events.isEmpty
              ? const StudyEmpty()
              : IssueTimeline(events: events),
        ),
      ],
    );
  }
}

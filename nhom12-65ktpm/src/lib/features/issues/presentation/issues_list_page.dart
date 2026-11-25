import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/contracts/models/issue.dart';
import '../../../design_system/widgets/study_empty.dart';
import '../../../design_system/widgets/study_error.dart';
import '../../../design_system/widgets/study_loading.dart';
import '../domain/issue_labels.dart';
import '../providers/issue_providers.dart';
import 'widgets/issue_card.dart';

// SCR-21 – Danh sách sự cố (UI-09/UI-16). Chủ trì: Sơn.
// Không có nút tạo Issue tại đây: Issue luôn gắn với một giao dịch/lượt bàn giao
// nên được tạo từ SCR-14 hoặc SCR-20 (SCR-22).
class IssuesListPage extends ConsumerWidget {
  const IssuesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issues = ref.watch(myIssuesProvider);

    return DefaultTabController(
      length: IssueTab.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sự cố'),
          bottom: TabBar(
            tabs: [
              for (final tab in IssueTab.values) Tab(text: issueTabLabelVi(tab)),
            ],
          ),
        ),
        body: issues.when(
          loading: () => const StudyLoading(),
          error: (error, stackTrace) =>
              StudyError(onRetry: () => ref.invalidate(myIssuesProvider)),
          data: (items) => TabBarView(
            children: [
              for (final tab in IssueTab.values)
                _IssueTabList(
                  tab: tab,
                  items: items.where((item) => belongsToIssueTab(item, tab)).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IssueTabList extends ConsumerWidget {
  const _IssueTabList({required this.tab, required this.items});

  final IssueTab tab;
  final List<IssueDetails> items;

  String get _emptyMessage => switch (tab) {
    IssueTab.open =>
      'Không có sự cố nào đang mở.\nBạn có thể báo sự cố từ màn hình chi tiết giao dịch.',
    IssueTab.resolved => 'Chưa có sự cố nào được giải quyết.',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kéo để tải lại snapshot server; không tự cập nhật trạng thái ở client.
    Future<void> refresh() => ref.refresh(myIssuesProvider.future);

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: items.isEmpty
            ? [StudyEmpty(message: _emptyMessage)]
            : [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: IssueCard(
                      details: item,
                      onTap: () => context.push(AppRoutes.issueDetails(item.id)),
                    ),
                  ),
              ],
      ),
    );
  }
}

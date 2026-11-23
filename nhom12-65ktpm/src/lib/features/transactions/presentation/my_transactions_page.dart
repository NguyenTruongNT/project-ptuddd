import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../../design_system/widgets/study_empty.dart';
import '../../../design_system/widgets/study_error.dart';
import '../../../design_system/widgets/study_loading.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/transaction_labels.dart';
import '../providers/transaction_providers.dart';
import 'widgets/transaction_card.dart';

// SCR-13 – Giao dịch của tôi (UI-16 + UI-09). Chủ trì: Sơn.
class MyTransactionsPage extends ConsumerWidget {
  const MyTransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final transactions = ref.watch(myTransactionsProvider);

    return DefaultTabController(
      length: TransactionTab.values.length,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                l10n.navTransactions,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            TabBar(
              tabs: [
                for (final tab in TransactionTab.values)
                  Tab(text: transactionTabLabelVi(tab)),
              ],
            ),
            Expanded(
              child: transactions.when(
                loading: () => const StudyLoading(),
                error: (error, stackTrace) => StudyError(
                  onRetry: () => ref.invalidate(myTransactionsProvider),
                ),
                data: (items) => TabBarView(
                  children: [
                    for (final tab in TransactionTab.values)
                      _TransactionTabList(
                        tab: tab,
                        items: items.where((item) => belongsToTab(item, tab)).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTabList extends ConsumerWidget {
  const _TransactionTabList({required this.tab, required this.items});

  final TransactionTab tab;
  final List<TransactionDetails> items;

  String get _emptyMessage => switch (tab) {
    TransactionTab.active =>
      'Chưa có giao dịch đang xử lý.\nKhi yêu cầu được duyệt, giao dịch sẽ xuất hiện ở đây.',
    TransactionTab.completed => 'Chưa có giao dịch đã hoàn tất hoặc đã hủy.',
    TransactionTab.withIssue => 'Không có giao dịch nào đang có sự cố.',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowUtc = ref.watch(nowUtcProvider)();
    // Kéo để tải lại snapshot server; không tự cập nhật trạng thái ở client.
    Future<void> refresh() => ref.refresh(myTransactionsProvider.future);

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
                    child: TransactionCard(
                      details: item,
                      nowUtc: nowUtc,
                      onTap: () =>
                          context.push(AppRoutes.transactionDetails(item.id)),
                    ),
                  ),
              ],
      ),
    );
  }
}

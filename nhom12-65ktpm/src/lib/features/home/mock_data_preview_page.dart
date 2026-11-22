import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../core/providers/mock_query_providers.dart';
import '../../design_system/widgets/study_async_view.dart';

// Trang dành riêng cho người phát triển: xem repository mock đọc dữ liệu.
// Không có hành động duyệt yêu cầu, giao sách hay cập nhật trạng thái.
class MockDataPreviewPage extends ConsumerWidget {
  const MockDataPreviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(publishedListingsProvider);
    final materials = ref.watch(myMaterialsPreviewProvider);
    final transactions = ref.watch(myTransactionsPreviewProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dữ liệu mô phỏng (demo)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'CHỈ DỮ LIỆU GIẢ: tài khoản mô phỏng A. '
            'Không phải dữ liệu Supabase; không thực hiện giao dịch thật.',
          ),
          const SizedBox(height: 16),
          Text('Tin đăng công khai',
              style: Theme.of(context).textTheme.titleLarge),
          StudyAsyncView(
            value: listings,
            isEmpty: (items) => items.isEmpty,
            onRetry: () => ref.invalidate(publishedListingsProvider),
            builder: (items) => Column(
              children: [
                for (final item in items)
                  ListTile(
                    title: Text(item.title),
                    subtitle: Text(item.isReserved
                        ? 'Đã được đặt – không thể gửi yêu cầu'
                        : 'Có thể xem chi tiết'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      AppRoutes.listingDetails(item.listingId),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 32),
          Text('Tài liệu của tài khoản A (demo)',
              style: Theme.of(context).textTheme.titleLarge),
          StudyAsyncView(
            value: materials,
            isEmpty: (items) => items.isEmpty,
            onRetry: () => ref.invalidate(myMaterialsPreviewProvider),
            builder: (items) => Column(
              children: [
                for (final item in items)
                  ListTile(
                    title: Text(item.title),
                    subtitle: Text(item.subject),
                  ),
              ],
            ),
          ),
          const Divider(height: 32),
          Text('Giao dịch liên quan tài khoản A (demo)',
              style: Theme.of(context).textTheme.titleLarge),
          StudyAsyncView(
            value: transactions,
            isEmpty: (items) => items.isEmpty,
            onRetry: () => ref.invalidate(myTransactionsPreviewProvider),
            builder: (items) => Column(
              children: [
                for (final item in items)
                  ListTile(
                    title: Text('Giao dịch ${item.id}'),
                    subtitle: Text('Trạng thái: ${item.status.name}'),
                    onTap: () => context.push(
                      AppRoutes.transactionDetails(item.id),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

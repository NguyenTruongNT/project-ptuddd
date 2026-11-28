import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/delivery.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/providers/mock_query_providers.dart';
import '../../../design_system/widgets/study_empty.dart';
import '../../../design_system/widgets/study_error.dart';
import '../../../design_system/widgets/study_loading.dart';
import '../domain/delivery_labels.dart';
import '../providers/delivery_providers.dart';
import 'widgets/delivery_task_card.dart';

/// SCR-15 – Danh sách giao hộ (UI-11). Phụ trách: Vũ Hải Đăng.
/// Gồm 4 tab phân loại: Có thể nhận (OPEN), Đã ứng tuyển, Đang giao, Lịch sử.
class DeliveryListPage extends ConsumerWidget {
  const DeliveryListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(demoViewerIdProvider);
    final myTasksAsync = ref.watch(myDeliveryTasksProvider);
    final availableTasksAsync = ref.watch(availableDeliveryTasksProvider);

    final router = GoRouter.of(context);
    void handleBack() {
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(AppRoutes.profile);
      }
    }

    return PopScope(
      canPop: router.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) handleBack();
      },
      child: DefaultTabController(
        length: DeliveryTab.values.length,
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: handleBack),
            title: const Text('Nhiệm vụ giao hộ'),
            actions: [
              IconButton(
                tooltip: 'Tải lại',
                icon: const Icon(Icons.refresh),
                onPressed: () => refreshDeliveries(ref),
              ),
            ],
            bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final tab in DeliveryTab.values)
                Tab(text: deliveryTabLabelVi(tab)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Có thể nhận (Nhiệm vụ OPEN đang tìm Courier)
            availableTasksAsync.when(
              loading: () => const StudyLoading(),
              error: (err, stack) => StudyError(
                message: err is AppError
                    ? err.safeMessage
                    : 'Không thể tải dữ liệu. Vui lòng thử lại.',
                onRetry: () => ref.invalidate(availableDeliveryTasksProvider),
              ),
              data: (availableList) {
                if (availableList.isEmpty) {
                  return const StudyEmpty(
                    message: 'Hiện chưa có nhiệm vụ giao hộ nào đang mở.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: availableList.length,
                  itemBuilder: (context, index) {
                    final summary = availableList[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          child: Icon(Icons.local_shipping, color: theme.colorScheme.primary),
                        ),
                        title: Text(summary.publicTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Mã: ${summary.id} • Đang tìm người nhận'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.deliveryDetails(summary.id)),
                      ),
                    );
                  },
                );
              },
            ),

            // Tab 2: Đã ứng tuyển
            myTasksAsync.when(
              loading: () => const StudyLoading(),
              error: (err, stack) => StudyError(
                message: err is AppError
                    ? err.safeMessage
                    : 'Không thể tải dữ liệu. Vui lòng thử lại.',
                onRetry: () => ref.invalidate(myDeliveryTasksProvider),
              ),
              data: (allTasks) {
                final appliedTasks = allTasks
                    .where((t) =>
                        t.status == DeliveryTaskStatus.open &&
                        t.senderId != currentUserId &&
                        t.finalReceiverId != currentUserId)
                    .toList();
                if (appliedTasks.isEmpty) {
                  return const StudyEmpty(
                    message: 'Bạn chưa nộp đơn ứng tuyển nhiệm vụ nào.',
                  );
                }
                return _buildTaskList(appliedTasks, context);
              },
            ),

            // Tab 3: Đang giao (Assigned / PickedUp / DeliveryPendingConfirmation)
            myTasksAsync.when(
              loading: () => const StudyLoading(),
              error: (err, stack) => StudyError(
                message: err is AppError
                    ? err.safeMessage
                    : 'Không thể tải dữ liệu. Vui lòng thử lại.',
                onRetry: () => ref.invalidate(myDeliveryTasksProvider),
              ),
              data: (allTasks) {
                final activeTasks = allTasks.where((t) =>
                    t.status == DeliveryTaskStatus.assigned ||
                    t.status == DeliveryTaskStatus.pickedUp ||
                    t.status == DeliveryTaskStatus.deliveryPendingConfirmation).toList();
                if (activeTasks.isEmpty) {
                  return const StudyEmpty(
                    message: 'Không có nhiệm vụ giao hộ nào đang thực hiện.',
                  );
                }
                return _buildTaskList(activeTasks, context);
              },
            ),

            // Tab 4: Lịch sử (Completed / Failed / Cancelled)
            myTasksAsync.when(
              loading: () => const StudyLoading(),
              error: (err, stack) => StudyError(
                message: err is AppError
                    ? err.safeMessage
                    : 'Không thể tải dữ liệu. Vui lòng thử lại.',
                onRetry: () => ref.invalidate(myDeliveryTasksProvider),
              ),
              data: (allTasks) {
                final historyTasks = allTasks.where((t) =>
                    t.status == DeliveryTaskStatus.completed ||
                    t.status == DeliveryTaskStatus.failed ||
                    t.status == DeliveryTaskStatus.cancelled).toList();
                if (historyTasks.isEmpty) {
                  return const StudyEmpty(
                    message: 'Chưa có lịch sử nhiệm vụ giao hộ.',
                  );
                }
                return _buildTaskList(historyTasks, context);
              },
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTaskList(List<DeliveryTask> tasks, BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return DeliveryTaskCard(
          task: task,
          onTap: () => context.push(AppRoutes.deliveryDetails(task.id)),
        );
      },
    );
  }
}

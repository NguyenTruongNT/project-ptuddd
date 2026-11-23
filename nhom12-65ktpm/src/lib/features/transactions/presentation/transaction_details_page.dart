import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/contracts/domain_enums.dart';
import '../../../core/contracts/models/transaction.dart';
import '../../../design_system/widgets/study_async_view.dart';
import '../../../design_system/widgets/study_empty.dart';
import '../domain/transaction_labels.dart';
import '../providers/transaction_providers.dart';
import 'widgets/transaction_status_chip.dart';
import 'widgets/transaction_timeline.dart';

// SCR-14 – Chi tiết giao dịch (UI-09). Chủ trì: Sơn (+ Khanh phần mượn/trả).
// Trang chỉ ĐỌC trong PR này: không gọi command, chỉ điều hướng.
class TransactionDetailsPage extends ConsumerWidget {
  const TransactionDetailsPage({super.key, required this.transactionId});

  final String transactionId;

  static const noAccessMessage =
      'Không tìm thấy giao dịch hoặc bạn không có quyền xem.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(transactionDetailsProvider(transactionId));

    Future<void> refresh() async {
      ref.invalidate(transactionTimelineProvider(transactionId));
      ref.invalidate(transactionDetailsProvider(transactionId));
      await ref.read(transactionDetailsProvider(transactionId).future);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết giao dịch')),
      body: StudyAsyncView<TransactionDetails?>(
        value: details,
        onRetry: () => ref.invalidate(transactionDetailsProvider(transactionId)),
        isEmpty: (data) => data == null,
        // Không phân biệt "không tồn tại" và "không có quyền" để tránh lộ dữ liệu.
        emptyMessage: noAccessMessage,
        builder: (data) => RefreshIndicator(
          onRefresh: refresh,
          child: _DetailsBody(details: data!),
        ),
      ),
    );
  }
}

class _DetailsBody extends ConsumerWidget {
  const _DetailsBody({required this.details});
  final TransactionDetails details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nowUtc = ref.watch(nowUtcProvider)();
    final txn = details.transaction;

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _HeaderCard(details: details, nowUtc: nowUtc),
        if (needsResolution(details)) _IssueBanner(details: details),
        _PartiesCard(details: details),
        if (txn.type == OfferType.borrow) _BorrowCard(details: details, nowUtc: nowUtc),
        if (txn.type == OfferType.sell) _SellPaymentCard(details: details),
        _ActionsCard(details: details),
        _TimelineSection(transactionId: details.id),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: textTheme.bodySmall)),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.details, required this.nowUtc});
  final TransactionDetails details;
  final DateTime nowUtc;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final txn = details.transaction;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(details.materialTitle, style: textTheme.titleLarge),
            Text(details.materialSubject, style: textTheme.bodySmall),
            const SizedBox(height: 10),
            TransactionChips(
              type: txn.type,
              status: txn.status,
              overdue: isOverdue(details, nowUtc),
              reHandoverOverdue: isReHandoverOverdue(details, nowUtc),
              hasOpenIssue: needsResolution(details),
            ),
            const SizedBox(height: 10),
            Text(waitingOnVi(details), style: textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              'Tạo lúc ${formatServerTimeVn(details.createdAt)}',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueBanner extends StatelessWidget {
  const _IssueBanner({required this.details});
  final TransactionDetails details;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.report_outlined, color: scheme.onErrorContainer),
        title: Text(
          'Có ${details.openIssueCount} sự cố đang mở',
          style: TextStyle(color: scheme.onErrorContainer),
        ),
        subtitle: Text(
          'Một số thao tác có thể bị chặn cho tới khi các bên thống nhất phương án.',
          style: TextStyle(color: scheme.onErrorContainer),
        ),
        trailing: Icon(Icons.chevron_right, color: scheme.onErrorContainer),
        onTap: () => context.push(AppRoutes.issues),
      ),
    );
  }
}

class _PartiesCard extends StatelessWidget {
  const _PartiesCard({required this.details});
  final TransactionDetails details;

  @override
  Widget build(BuildContext context) {
    final isOwner = details.viewerRole == TransactionViewerRole.owner;
    final ownerRole = switch (details.transaction.type) {
      OfferType.borrow => 'Người cho mượn',
      OfferType.sell => 'Người bán',
      OfferType.donate => 'Người tặng',
    };
    final receiverRole = switch (details.transaction.type) {
      OfferType.borrow => 'Người mượn',
      OfferType.sell => 'Người mua',
      OfferType.donate => 'Người nhận',
    };
    return _Section(
      title: 'Các bên',
      children: [
        _InfoRow(ownerRole,
            '${details.ownerDisplayName}${isOwner ? ' (bạn)' : ''}'),
        _InfoRow(receiverRole,
            '${details.receiverDisplayName}${isOwner ? '' : ' (bạn)'}'),
      ],
    );
  }
}

class _BorrowCard extends StatelessWidget {
  const _BorrowCard({required this.details, required this.nowUtc});
  final TransactionDetails details;
  final DateTime nowUtc;

  @override
  Widget build(BuildContext context) {
    final record = details.borrowing;
    final days = details.transaction.agreedBorrowDays;
    return _Section(
      title: 'Thông tin mượn',
      children: [
        _InfoRow('Số ngày mượn', days == null ? '—' : '$days ngày'),
        if (record?.startedAt == null)
          const Text(
            'Kỳ mượn chỉ bắt đầu khi người mượn xác nhận đã nhận tài liệu.',
          )
        else ...[
          _InfoRow('Bắt đầu', formatServerTimeVn(record!.startedAt!)),
          _InfoRow(
            'Hạn trả',
            '${formatVnDate(record.dueDateVn)} (hết ngày, giờ Việt Nam)'
                '${isOverdue(details, nowUtc) ? ' – đã quá hạn' : ''}',
          ),
        ],
        if (record?.returnToCourierAt != null)
          _InfoRow('Đã giao cho người giao hộ',
              formatServerTimeVn(record!.returnToCourierAt!)),
        if (record?.reHandoverDueDateVn != null)
          _InfoRow('Hạn tái bàn giao', formatVnDate(record!.reHandoverDueDateVn)),
      ],
    );
  }
}

class _SellPaymentCard extends StatelessWidget {
  const _SellPaymentCard({required this.details});
  final TransactionDetails details;

  @override
  Widget build(BuildContext context) {
    final price = details.transaction.agreedPriceVnd;
    final payment = details.payment;
    final String paymentState;
    if (payment?.sellerConfirmedAt != null) {
      paymentState =
          'Người bán đã xác nhận nhận tiền lúc ${formatServerTimeVn(payment!.sellerConfirmedAt!)}.';
    } else if (payment?.buyerReportedAt != null) {
      // B báo chuyển khoản KHÔNG tương đương A xác nhận đã nhận tiền.
      paymentState =
          'Người mua đã báo chuyển khoản lúc ${formatServerTimeVn(payment!.buyerReportedAt!)}. '
          'Chưa có xác nhận của người bán.';
    } else {
      paymentState = 'Chưa có thông báo chuyển khoản.';
    }
    final locked = !(payment?.isSellerConfirmed ?? false);

    return _Section(
      title: 'Thanh toán (ngoài ứng dụng)',
      children: [
        _InfoRow('Giá đã chốt', price == null ? '—' : formatVnd(price)),
        _InfoRow('Trạng thái tiền', paymentState),
        if (locked)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Mọi bàn giao bị khóa cho tới khi người bán xác nhận đã nhận tiền.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text(
          'StudyShare không chuyển tiền và không kiểm tra giao dịch ngân hàng.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({required this.details});
  final TransactionDetails details;

  @override
  Widget build(BuildContext context) {
    // allowedActions chỉ là gợi ý; màn hình đích/RPC phải kiểm tra lại.
    final buttons = <Widget>[
      if (details.can(TransactionAction.startHandover))
        FilledButton.icon(
          onPressed: () => context.push(
            '${AppRoutes.createDelivery}?transactionId=${Uri.encodeComponent(details.id)}',
          ),
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('Tạo nhiệm vụ giao hộ'),
        ),
      if (details.can(TransactionAction.reportIssue))
        OutlinedButton.icon(
          onPressed: () => context.push(
            '${AppRoutes.createIssue}?transactionId=${Uri.encodeComponent(details.id)}',
          ),
          icon: const Icon(Icons.report_outlined),
          label: const Text('Báo sự cố'),
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return _Section(
      title: 'Thao tác',
      children: [Wrap(spacing: 8, runSpacing: 8, children: buttons)],
    );
  }
}

class _TimelineSection extends ConsumerWidget {
  const _TimelineSection({required this.transactionId});
  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(transactionTimelineProvider(transactionId));
    return _Section(
      title: 'Lịch sử giao dịch',
      children: [
        StudyAsyncView<List<TransactionEventItem>>(
          value: timeline,
          isEmpty: (events) => events.isEmpty,
          emptyMessage: 'Chưa có sự kiện nào.',
          onRetry: () =>
              ref.invalidate(transactionTimelineProvider(transactionId)),
          builder: (events) => events.isEmpty
              ? const StudyEmpty()
              : TransactionTimeline(events: events),
        ),
      ],
    );
  }
}

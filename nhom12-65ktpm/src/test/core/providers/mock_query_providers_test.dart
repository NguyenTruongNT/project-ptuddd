import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/contracts/command_inputs.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';
import 'package:studyshare/features/issues/data/mock_issue_command_runner.dart';
import 'package:studyshare/features/issues/data/mock_issue_repository.dart';
import 'package:studyshare/core/providers/mock_query_providers.dart';

void main() {
  test('Danh sách tin đăng mock có thể đọc công khai', () async {
    final container = ProviderContainer(overrides: [workflowRpcProvider.overrideWithValue(null)]);
    addTearDown(container.dispose);
    final listings = await container.read(publishedListingsProvider.future);
    expect(listings, isNotEmpty);
    // Vẫn hiển thị tin đã đặt nhưng không cho gửi Request.
    expect(
      listings.any((item) => item.isReserved && !item.isRequestable),
      isTrue,
    );
  });

  test('Người ngoài không đọc được tài liệu và giao dịch của A', () async {
    final container = ProviderContainer(
      overrides: [
        workflowRpcProvider.overrideWithValue(null),
        demoViewerIdProvider.overrideWith((ref) => MockFixtures.outsider),
      ],
    );
    addTearDown(container.dispose);
    final materials = await container.read(myMaterialsPreviewProvider.future);
    final transactions = await container.read(
      myTransactionsPreviewProvider.future,
    );
    expect(materials, isEmpty);
    expect(transactions, isEmpty);
  });

  test('Tài khoản A đọc được dữ liệu mock của chính mình', () async {
    final container = ProviderContainer(
      overrides: [
        workflowRpcProvider.overrideWithValue(null),
        demoViewerIdProvider.overrideWith((ref) => MockFixtures.userA),
      ],
    );
    addTearDown(container.dispose);
    final materials = await container.read(myMaterialsPreviewProvider.future);
    expect(materials, isNotEmpty);
  });

  test('Issue mới tạo dùng chung store nên giao dịch hiện sự cố đang mở', () async {
    final container = ProviderContainer(
      overrides: [
        workflowRpcProvider.overrideWithValue(null),
        demoViewerIdProvider.overrideWith((ref) => MockFixtures.userA),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(issueQueryRepositoryProvider).getMyIssues(), isEmpty);

    final store = container.read(mockTransactionStoreProvider);
    await MockIssueRepository(
            MockIssueCommandRunner(store: store, actorId: MockFixtures.userA))
        .reportIssue(
            const CreateIssueInput(
                transactionId: 'txn-sell-01',
                type: IssueType.other,
                reason: 'Cần đối soát.'),
            idempotencyKey: 'k1');

    final issues = await container.read(issueQueryRepositoryProvider).getMyIssues();
    expect(issues.length, 1);
    final transactions = await container.read(myTransactionsPreviewProvider.future);
    final sell = transactions.firstWhere((item) => item.id == 'txn-sell-01');
    expect(sell.openIssueCount, 1);
  });
}

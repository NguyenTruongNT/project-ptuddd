import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/contracts/command_inputs.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/models/issue.dart';
import 'package:studyshare/core/contracts/models/transaction.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/features/issues/data/supabase_issue_repository.dart';
import 'package:studyshare/features/transactions/data/supabase_transaction_repository.dart';

// Opt-in. Chỉ đọc tài khoản được truyền riêng; không tạo/nạp/reset dữ liệu.
// Phép ghi chỉ chạy với fixture QA tách biệt được nhóm trưởng chuẩn bị riêng.
void main() {
  const run = bool.fromEnvironment('RUN_WORKFLOW_SUPABASE');
  const write = bool.fromEnvironment('RUN_WORKFLOW_WRITE_TESTS');

  Future<SupabaseClient> login(Map<String, dynamic> account) async {
    final config = jsonDecode(
      await File('assets/config/supabase.public.json').readAsString(),
    ) as Map;
    expect(config['SUPABASE_URL'], 'https://dacrjfgleursgtnzeoix.supabase.co');
    final client = SupabaseClient(
      config['SUPABASE_URL'] as String,
      config['SUPABASE_PUBLISHABLE_KEY'] as String,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(
      email: account['email'] as String,
      password: account['password'] as String,
    );
    expect(client.auth.currentUser!.id, account['id']);
    return client;
  }

  T ok<T>(CommandResult<T> result) {
    expect(result, isA<CommandOk<T>>());
    final success = result as CommandOk<T>;
    expect(success.serverEventId, isNotEmpty);
    return success.data;
  }

  test(
    'Bốn JWT thật: DTO, timeline, phân quyền và đăng nhập lại',
    () async {
      final path = Platform.environment['WORKFLOW_TEST_ACCOUNTS_FILE'];
      expect(
        path,
        isNotNull,
        reason: 'Credentials phải ở file local bị Git bỏ qua',
      );
      final credentials = jsonDecode(await File(path!).readAsString()) as Map;
      expect(credentials['project_ref'], 'dacrjfgleursgtnzeoix');
      final accounts = (credentials['accounts'] as List)
          .cast<Map<String, dynamic>>();
      expect(accounts.length, 4);
      final transactions = <String, List<TransactionDetails>>{};
      final issues = <String, List<IssueDetails>>{};
      final txQueries = <String, SupabaseTransactionQueryRepository>{};
      final issueQueries = <String, SupabaseIssueQueryRepository>{};
      final clients = <SupabaseClient>[];
      for (final account in accounts) {
        final client = await login(account);
        clients.add(client);
        final actor = client.auth.currentUser!.id;
        final rpc = WorkflowRpc(client, actor);
        final tx = SupabaseTransactionQueryRepository(rpc);
        final issue = SupabaseIssueQueryRepository(rpc);
        txQueries[actor] = tx;
        issueQueries[actor] = issue;
        final tt = await tx.getMyTransactions();
        transactions[actor] = tt;
        final ii = await issue.getMyIssues();
        issues[actor] = ii;
        expect(tt, isNotEmpty);
        expect(ii, isNotEmpty);
        expect(
          tt.every(
            (d) => [
              d.transaction.ownerAtAcceptance,
              d.transaction.receiverId,
            ].contains(actor),
          ),
          isTrue,
        );
        final details = await tx.getTransactionDetails(tt.first.id);
        expect(details!.id, tt.first.id);
        final timeline = await tx.getTimeline(tt.first.id);
        expect(timeline, isNotEmpty);
        for (var n = 1; n < timeline.length; n++) {
          expect(
            timeline[n].serverAt.isBefore(timeline[n - 1].serverAt),
            isFalse,
          );
        }
        final issueDetails = await issue.getIssueDetails(ii.first.id);
        expect(issueDetails!.id, ii.first.id);
        expect(await issue.getTimeline(ii.first.id), isNotEmpty);
      }
      final allTransactions = transactions.values.expand((v) => v).toList();
      final allIssues = issues.values.expand((v) => v).toList();
      for (final account in accounts) {
        final actor = account['id'] as String;
        final hidden = allTransactions.firstWhere(
          (d) => ![
            d.transaction.ownerAtAcceptance,
            d.transaction.receiverId,
          ].contains(actor),
        );
        expect(
          await txQueries[actor]!.getTransactionDetails(hidden.id),
          isNull,
        );
        expect(await txQueries[actor]!.getTimeline(hidden.id), isEmpty);
        final visibleIssues = issues[actor]!.map((i) => i.id).toSet();
        final hiddenIssue = allIssues.firstWhere(
          (i) => !visibleIssues.contains(i.id),
        );
        expect(
          await issueQueries[actor]!.getIssueDetails(hiddenIssue.id),
          isNull,
        );
        expect(await issueQueries[actor]!.getTimeline(hiddenIssue.id), isEmpty);
      }
      final first = accounts.first;
      final initial = transactions[first['id']]!.map((d) => d.id).toSet();
      await clients.first.auth.signOut(scope: SignOutScope.local);
      final restored = await login(first);
      final read = SupabaseTransactionQueryRepository(
        WorkflowRpc(restored, first['id'] as String),
      );
      expect(
        (await read.getMyTransactions()).map((d) => d.id).toSet(),
        containsAll(initial),
      );
      // Không in email/mật khẩu, JWT hoặc nội dung giao dịch vào log test.
    },
    skip: !run,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'RPC ghi thật trên fixture QA riêng: tiền, hoàn tiền, hủy, Issue và retry',
    () async {
      final path = Platform.environment['WORKFLOW_WRITE_FIXTURE_FILE'];
      expect(path, isNotNull);
      final fixture =
          jsonDecode(await File(path!).readAsString()) as Map<String, dynamic>;
      expect(fixture['project_ref'], 'dacrjfgleursgtnzeoix');
      expect(fixture['purpose'], 'workflow-adapter-integration-test');
      final accounts = (fixture['accounts'] as List)
          .cast<Map<String, dynamic>>();
      expect(accounts.length, 3);
      expect(
        accounts.every(
          (a) => (a['email'] as String).startsWith('workflow-qa-'),
        ),
        isTrue,
        reason: 'Không chạy lệnh ghi trên bộ dữ liệu demo dùng chung',
      );
      final clients = <SupabaseClient>[];
      for (final account in accounts) {
        clients.add(await login(account));
      }
      final aa = [
        for (final c in clients) WorkflowRpc(c, c.auth.currentUser!.id),
      ];
      final tx = [for (final r in aa) SupabaseTransactionQueryRepository(r)];
      final pay = [for (final r in aa) SupabaseSellerPaymentRepository(r)];
      final cancel = [
        for (final r in aa) SupabaseTransactionCancellationRepository(r),
      ];
      final issue = [for (final r in aa) SupabaseIssueRepository(r)];
      final iq = [for (final r in aa) SupabaseIssueQueryRepository(r)];
      final cases = Map<String, String>.from(fixture['cases'] as Map);
      for (final id in cases.values) {
        final d = (await tx[0].getTransactionDetails(id))!;
        expect(d.materialTitle, startsWith('[WORKFLOW QA '));
        expect(d.transaction.ownerAtAcceptance, accounts[0]['id']);
        expect(d.transaction.receiverId, accounts[1]['id']);
        expect(await tx[2].getTransactionDetails(id), isNull);
      }
      final key = fixture['run_id'] as String;
      final sell = cases['payment']!;
      final buyer = await pay[1].reportBuyerTransfer(
        sell,
        idempotencyKey: '$key:transfer',
      );
      expect(ok(buyer).transaction.status, TransactionStatus.awaitingPayment);
      final retry = await pay[1].reportBuyerTransfer(
        sell,
        idempotencyKey: '$key:transfer',
      );
      expect(
        (retry as CommandOk).serverEventId,
        (buyer as CommandOk).serverEventId,
      );
      expect(
        (await pay[1].confirmSellerPayment(
          sell,
          idempotencyKey: '$key:wrong-seller',
        ) as CommandError).code,
        DomainErrorCode.forbidden,
      );
      final paid = ok(
        await pay[0].confirmSellerPayment(sell, idempotencyKey: '$key:paid'),
      );
      expect(paid.transaction.status, TransactionStatus.awaitingHandover);
      expect(paid.payment!.isSellerConfirmed, isTrue);
      ok(
        await cancel[0].proposeCancellation(
          sell,
          '[QA] Kết thúc thử adapter',
          idempotencyKey: '$key:cancel-paid',
        ),
      );
      expect(
        (await cancel[1].acceptCancellation(
          sell,
          idempotencyKey: '$key:blocked-cancel',
        ) as CommandError).code,
        DomainErrorCode.cancellationObligationPending,
      );
      ok(await pay[0].reportSellerRefund(sell, idempotencyKey: '$key:refund'));
      final refunded = ok(
        await pay[1].confirmRefundReceived(
          sell,
          idempotencyKey: '$key:refund-confirm',
        ),
      );
      expect(refunded.payment!.hasOutstandingRefund, isFalse);
      expect(
        ok(
          await cancel[1].acceptCancellation(
            sell,
            idempotencyKey: '$key:cancel-finish',
          ),
        ).transaction.status,
        TransactionStatus.cancelled,
      );

      final donate = cases['cancellation']!;
      ok(
        await cancel[0].proposeCancellation(
          donate,
          '[QA] Đề nghị lần một',
          idempotencyKey: '$key:propose-1',
        ),
      );
      expect(
        ok(
          await cancel[0].withdrawCancellation(
            donate,
            idempotencyKey: '$key:withdraw',
          ),
        ).cancellationProposal,
        isNull,
      );
      ok(
        await cancel[1].proposeCancellation(
          donate,
          '[QA] Đề nghị lần hai',
          idempotencyKey: '$key:propose-2',
        ),
      );
      expect(
        ok(
          await cancel[0].declineCancellation(
            donate,
            idempotencyKey: '$key:decline',
          ),
        ).cancellationProposal,
        isNull,
      );
      ok(
        await cancel[1].proposeCancellation(
          donate,
          '[QA] Đề nghị lần ba',
          idempotencyKey: '$key:propose-3',
        ),
      );
      expect(
        ok(
          await cancel[0].acceptCancellation(
            donate,
            idempotencyKey: '$key:accept',
          ),
        ).transaction.status,
        TransactionStatus.cancelled,
      );

      final borrow = cases['issue']!;
      final before = (await tx[0].getTransactionDetails(borrow))!
          .transaction
          .status;
      final reported = await issue[1].reportIssue(
        CreateIssueInput(
          transactionId: borrow,
          type: IssueType.other,
          reason: '[QA] Kiểm tra đồng thuận',
        ),
        idempotencyKey: '$key:issue',
      );
      final issueId = ok(reported).id;
      final again = await issue[1].reportIssue(
        CreateIssueInput(
          transactionId: borrow,
          type: IssueType.other,
          reason: '[QA] Kiểm tra đồng thuận',
        ),
        idempotencyKey: '$key:issue',
      );
      expect(ok(again).id, issueId);
      expect(
        (again as CommandOk).serverEventId,
        (reported as CommandOk).serverEventId,
      );
      final proposal = ok(
        await issue[0].proposeResolution(
          issueId,
          '[QA] Phương án một',
          idempotencyKey: '$key:resolution-1',
        ),
      );
      expect(proposal.proposal!.approvedCount, 0);
      final firstConsent = ok(
        await issue[1].confirmResolution(
          issueId,
          1,
          idempotencyKey: '$key:consent-1',
        ),
      );
      expect(firstConsent.issue.status, IssueStatus.open);
      final revision = ok(
        await issue[0].proposeResolution(
          issueId,
          '[QA] Phương án hai',
          idempotencyKey: '$key:resolution-2',
        ),
      );
      expect(revision.proposal!.revision, 2);
      expect(revision.proposal!.approvedCount, 0);
      expect(
        (await issue[1].confirmResolution(
          issueId,
          1,
          idempotencyKey: '$key:stale',
        ) as CommandError).code,
        DomainErrorCode.conflict,
      );
      ok(
        await issue[0].confirmResolution(
          issueId,
          2,
          idempotencyKey: '$key:a-consent-2',
        ),
      );
      final finished = ok(
        await issue[1].confirmResolution(
          issueId,
          2,
          idempotencyKey: '$key:b-consent-2',
        ),
      );
      expect(finished.issue.status, IssueStatus.resolved);
      expect(
        (await tx[0].getTransactionDetails(borrow))!.transaction.status,
        before,
      );
      expect(await iq[2].getIssueDetails(issueId), isNull);
      expect(
        (await issue[2].proposeResolution(
          issueId,
          '[QA] Trái quyền',
          idempotencyKey: '$key:outsider',
        ) as CommandError).code,
        DomainErrorCode.forbidden,
      );
    },
    skip: !run || !write,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

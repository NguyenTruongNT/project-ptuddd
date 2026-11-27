import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/contracts/command_inputs.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/material_qr.dart';
import 'package:studyshare/core/contracts/models/material.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/features/handovers/data/supabase_handover_repository.dart';
import 'package:studyshare/features/home/data/home_repository.dart';
import 'package:studyshare/features/materials/data/material_qr_repository.dart';
import 'package:studyshare/features/materials/data/supabase_material_workspace.dart';
import 'package:studyshare/features/listings/data/supabase_listing_workspace.dart';

import '../support/qr_cloud_qa.dart';

class _DropAck extends http.BaseClient {
  final _inner = http.Client();
  bool drop = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (drop && request.url.path.endsWith('/ensure_material_qr')) {
      drop = false;
      await response.stream.drain<void>();
      throw http.ClientException('Mô phỏng mất ACK sau khi server đã xử lý.');
    }
    return response;
  }

  @override
  void close() => _inner.close();
}

T _ok<T>(CommandResult<T> result) {
  expect(result, isA<CommandOk<T>>());
  return (result as CommandOk<T>).data;
}

void main() {
  const local = bool.fromEnvironment('RUN_QR_HOME_LOCAL');
  const cloud = bool.fromEnvironment('RUN_QR_HOME_CLOUD');
  const url = String.fromEnvironment('QR_TEST_URL');
  const key = String.fromEnvironment('QR_TEST_PUBLIC_KEY');
  test(
    'JWT Supabase: QR đồng thời, mất ACK, đổi chủ, hard block và tổng Home',
    () async {
      // Cloud phải opt-in riêng và khớp đúng project development được phép.
      // Service key chỉ dùng fixture/cleanup ở host, không đưa vào ứng dụng.
      expect(local != cloud, isTrue, reason: 'Chọn đúng một môi trường test.');
      expect(
        url,
        cloud
            ? 'https://dacrjfgleursgtnzeoix.supabase.co'
            : 'http://127.0.0.1:54321',
      );
      final adminKey = Platform.environment['QR_TEST_ADMIN_KEY'];
      expect(adminKey, isNotEmpty);
      final admin = SupabaseClient(
        url,
        adminKey!,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final gate = _DropAck();
      final a = SupabaseClient(
        url,
        key,
        httpClient: gate,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final b = SupabaseClient(
        url,
        key,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final users = <String>[];
      final materials = <String>[];
      String? listingId, transactionId;
      final suffix = const Uuid().v4();
      final password = 'QrHome-$suffix!Aa1';
      final qa = QrCloudQa(suffix);
      final recovery = File('.dart_tool/qr-home-fixture-$suffix.json');
      Future<void> checkpoint() async {
        if (!cloud) return;
        // Chỉ lưu ID để khôi phục cleanup; không lưu mật khẩu, JWT hoặc QR.
        await recovery.writeAsString(
          jsonEncode({
            'url': url,
            'suffix': suffix,
            'users': users,
            'materials': materials,
            'listing': listingId,
            'transaction': transactionId,
          }),
        );
      }

      addTearDown(() async {
        try {
          if (cloud) {
            // Cloud khóa bảng workflow/credential kể cả service_role. Dọn qua
            // kết nối quản trị theo đúng fixture, không nới quyền app/backend.
            await qa.cleanup(users);
            for (final user in users) {
              await admin.auth.admin.deleteUser(user);
            }
            if (await recovery.exists()) await recovery.delete();
            return;
          }
          // Xóa đúng fixture vừa tạo theo ID; không reset hoặc dọn dữ liệu nhóm.
          if (transactionId != null) {
            final handovers = await admin
                .from('handovers')
                .select('id')
                .eq('transaction_id', transactionId);
            final ids = handovers.map((h) => h['id'] as String).toList();
            if (ids.isNotEmpty) {
              await admin
                  .from('handover_evidence')
                  .delete()
                  .inFilter('handover_id', ids);
            }
            await admin
                .from('handovers')
                .delete()
                .eq('transaction_id', transactionId!);
            await admin
                .from('transaction_events')
                .delete()
                .eq('transaction_id', transactionId!);
            await admin.from('transactions').delete().eq('id', transactionId!);
          }
          if (listingId != null) {
            await admin
                .from('exchange_requests')
                .delete()
                .eq('listing_id', listingId);
            await admin.from('listings').delete().eq('id', listingId!);
          }
          if (materials.isNotEmpty) {
            await admin
                .from('material_qr_credentials')
                .delete()
                .inFilter('material_id', materials);
            await admin.from('materials').delete().inFilter('id', materials);
          }
          if (users.isNotEmpty) {
            await admin
                .from('command_receipts')
                .delete()
                .inFilter('actor_id', users);
          }
          for (final user in users) {
            await admin.auth.admin.deleteUser(user);
          }
        } finally {
          await a.dispose();
          await b.dispose();
          await admin.dispose();
          gate.close();
        }
      });
      for (final pair in [(a, 'a'), (b, 'b')]) {
        final email = 'n4-${pair.$2}-$suffix@example.test';
        final user = await admin.auth.admin.createUser(
          AdminUserAttributes(
            email: email,
            password: password,
            emailConfirm: true,
          ),
        );
        users.add(user.user!.id);
        await checkpoint();
        await pair.$1.auth.signInWithPassword(email: email, password: password);
      }
      final rpcA = WorkflowRpc(a, users[0]);
      final rpcB = WorkflowRpc(b, users[1]);
      final qrA = SupabaseMaterialQrRepository(rpcA);
      final qrB = SupabaseMaterialQrRepository(rpcB);
      final workspace = SupabaseMaterialWorkspace(a, users[0]);
      for (var i = 0; i < 2; i++) {
        final material = _ok<Material>(
          await workspace.createMaterial(
            const CreateMaterialInput(
              title: 'Hai bản sách cùng tên',
              subject: 'Tin học',
              condition: 'Tốt',
            ),
            idempotencyKey: 'material-$i',
          ),
        );
        materials.add(material.id);
        await checkpoint();
      }
      final concurrent = await Future.wait(
        List.generate(
          8,
          (i) => qrA.ensureQr(materials[0], idempotencyKey: 'parallel-$i'),
        ),
      );
      final first = _ok<MaterialQr>(concurrent.first);
      expect(
        concurrent.map((r) => _ok<MaterialQr>(r).payload).toSet(),
        hasLength(1),
      );
      if (cloud) {
        final rows = await qa.query(
          'credential-count',
          'select count(*) as count from public.material_qr_credentials where material_id=${qa.uuid(materials[0])}',
        );
        expect(rows.single['count'], 1);
      } else {
        expect(
          await admin
              .from('material_qr_credentials')
              .select('material_id')
              .eq('material_id', materials[0]),
          hasLength(1),
        );
      }
      expect(
        (await qrB.ensureQr(
          materials[0],
          idempotencyKey: 'outsider',
        ) as CommandError).code,
        DomainErrorCode.forbidden,
      );

      gate.drop = true;
      expect(
        (await qrA.ensureQr(
          materials[1],
          idempotencyKey: 'lost-ack',
        ) as CommandError).code,
        DomainErrorCode.timeoutUnknown,
      );
      final second = _ok<MaterialQr>(
        await qrA.ensureQr(materials[1], idempotencyKey: 'lost-ack'),
      );
      expect(second.payload == first.payload, isFalse);
      expect(
        await admin
            .from('command_receipts')
            .select('idempotency_key')
            .eq('actor_id', users[0])
            .eq('command_name', 'ensure_material_qr')
            .eq('idempotency_key', 'lost-ack'),
        hasLength(1),
      );
      // Holder khác owner không làm mất quyền xem QR của owner.
      await admin
          .from('materials')
          .update({'holder_id': users[1]})
          .eq('id', materials[0]);
      expect(
        _ok<MaterialQr>(
              await qrA.ensureQr(materials[0], idempotencyKey: 'not-holder'),
            ).payload ==
            first.payload,
        isTrue,
      );
      await admin
          .from('materials')
          .update({'owner_id': users[1]})
          .eq('id', materials[0]);
      expect(
        _ok<MaterialQr>(
              await qrB.ensureQr(materials[0], idempotencyKey: 'new-owner'),
            ).payload ==
            first.payload,
        isTrue,
      );
      expect(
        (await qrA.ensureQr(
          materials[0],
          idempotencyKey: 'parallel-0',
        ) as CommandError).code,
        DomainErrorCode.forbidden,
      );

      // Fixture Transaction riêng chỉ chuẩn bị bằng admin của môi trường test; các lệnh bàn giao
      // bên dưới dùng JWT thật và chính repository sản phẩm, không dùng RPC test.
      if (cloud) {
        listingId = const Uuid().v4();
        transactionId = const Uuid().v4();
        await checkpoint();
        await qa.prepareTransaction(
          material: materials[1],
          owner: users[0],
          receiver: users[1],
          listing: listingId,
          request: const Uuid().v4(),
          transaction: transactionId,
        );
      } else {
        final listing = await admin
            .from('listings')
            .insert({
              'material_id': materials[1],
              'created_by': users[0],
              'offer_type': 'BORROW',
              'status': 'PUBLISHED',
            })
            .select('id')
            .single();
        listingId = listing['id'] as String;
        final request = await admin
            .from('exchange_requests')
            .insert({
              'listing_id': listingId,
              'requester_id': users[1],
              'requested_borrow_days': 7,
              'status': 'ACCEPTED',
            })
            .select('id')
            .single();
        final transaction = await admin
            .from('transactions')
            .insert({
              'listing_id': listingId,
              'request_id': request['id'],
              'material_id': materials[1],
              'type': 'BORROW',
              'owner_at_acceptance': users[0],
              'receiver_id': users[1],
              'status': 'AWAITING_HANDOVER',
              'agreed_borrow_days': 7,
            })
            .select('id')
            .single();
        transactionId = transaction['id'] as String;
      }
      final handovers = SupabaseHandoverRepository(rpcA);
      final h = _ok(
        await handovers.createHandover(
          transactionId: transactionId,
          toUserId: users[1],
          idempotencyKey: 'create-h',
        ),
      );
      expect(
        (await handovers.verifyMaterialCode(
          h.id,
          materials[1],
          idempotencyKey: 'raw-uuid',
        ) as CommandError).code,
        DomainErrorCode.qrMismatch,
      );
      expect((await handovers.getHandover(h.id))!.qrMismatchBlocked, isTrue);
      expect(
        (await handovers.verifyWithFallback(
          h.id,
          'Mã bị rách',
          idempotencyKey: 'fallback',
        ) as CommandError).code,
        DomainErrorCode.qrMismatch,
      );
      expect(
        _ok(
          await handovers.verifyMaterialCode(
            h.id,
            second.payload,
            idempotencyKey: 'real-qr',
          ),
        ),
        isTrue,
      );
      expect((await handovers.getHandover(h.id))!.qrMismatchBlocked, isFalse);
      expect(
        (await admin
            .from('materials')
            .select('holder_id')
            .eq('id', materials[1])
            .single())['holder_id'],
        users[0],
      );
      final transactionStatus = cloud
          ? (await qa.query(
              'transaction-status',
              'select status from public.transactions where id=${qa.uuid(transactionId)}',
            )).single['status']
          : (await admin
                .from('transactions')
                .select('status')
                .eq('id', transactionId)
                .single())['status'];
      expect(transactionStatus, 'HANDOVER_IN_PROGRESS');
      expect(
        (await handovers.submitEvidence(
          SubmitHandoverEvidenceInput(
            handoverId: h.id,
            uploadedEvidenceIds: const [],
          ),
          idempotencyKey: 'no-photo',
        ) as CommandError).code,
        DomainErrorCode.evidenceRequired,
      );

      final more = await admin
          .from('materials')
          .insert(
            List.generate(
              25,
              (i) => {
                'owner_id': users[0],
                'holder_id': users[0],
                'title': 'Sách $i',
                'subject': 'Tin học',
                'condition': 'Tốt',
              },
            ),
          )
          .select('id');
      materials.addAll(more.map((m) => m['id'] as String));
      await checkpoint();
      final homeA = await SupabaseHomeRepository(rpcA).getOverview();
      final homeB = await SupabaseHomeRepository(rpcB).getOverview();
      expect(homeA.materialCount, 26);
      expect(homeA.publishedCount, 1);
      expect(homeA.activeTransactionCount, 1);
      expect(homeB.materialCount, 1);
      expect(homeB.publishedCount, 0);
      // Đọc đúng nguồn Home sử dụng, kể cả ký URL ảnh qua policy Storage mới.
      final listingReads = SupabaseListingWorkspace(rpcA);
      final recent = await listingReads.searchPage(limit: 6);
      expect(recent.items.length, lessThanOrEqualTo(6));
      if (cloud) {
        expect(recent.items, hasLength(6));
      }
      final drafts = await listingReads.searchMine(status: 'DRAFT', limit: 3);
      expect(drafts.items, isEmpty);
      await a.auth.signOut();
      expect(
        (await qrA.ensureQr(
          materials[1],
          idempotencyKey: 'lost-ack',
        ) as CommandError).code,
        DomainErrorCode.authRequired,
      );
    },
    skip: !(local || cloud),
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

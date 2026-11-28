import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/material_qr.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/features/home/data/home_repository.dart';
import 'package:studyshare/features/materials/data/material_qr_repository.dart';

import '../../support/workflow_rpc_fixture.dart';

const qrMaterialId = 'e4400000-0000-4000-8000-000000000001';
Map<String, dynamic> qrResponse() => {
  'ok': true,
  'command_id': 'receipt-qr',
  'server_revision': 1,
  'data': {
    'material_id': qrMaterialId,
    'title': 'Sách không có ảnh',
    'kind': 'MATERIAL',
    'version': 1,
    'payload': 'studyshare:material:1:$qrMaterialId:${'a' * 64}',
    'issued_at': '2026-11-27T09:00:00+07:00',
  },
};

void main() {
  late WorkflowTestBackend backend;
  late SupabaseMaterialQrRepository repo;
  setUp(() async {
    backend = WorkflowTestBackend();
    await backend.login();
    repo = SupabaseMaterialQrRepository(
      WorkflowRpc(backend.client, workflowActorA),
    );
  });
  tearDown(() => backend.dispose());

  test('QR dùng RPC riêng và receipt; không gửi actor hay phát sinh TransactionEvent', () async {
    backend.onRpc = (_) => workflowResponse(qrResponse());
    final result = await repo.ensureQr(
      qrMaterialId,
      idempotencyKey: 'same-intent',
    );
    expect(result, isA<CommandOk<MaterialQr>>());
    final ok = result as CommandOk<MaterialQr>;
    expect(ok.commandId, 'receipt-qr');
    expect(ok.serverEventId, isNull);
    expect(ok.data.issuedAt, DateTime.utc(2026, 11, 27, 2));
    expect(ok.data.isDemo, isFalse);
    expect(backend.requests.single.url.path, '/rest/v1/rpc/ensure_material_qr');
    expect(jsonDecode(backend.requests.single.body), {
      'p_material_id': qrMaterialId,
      'p_idempotency_key': 'same-intent',
    });
  });

  test('ID và key không hợp lệ bị chặn trước HTTP', () async {
    for (final pair in [
      ('', 'ok'),
      ('raw-id', 'ok'),
      (qrMaterialId, ''),
      (qrMaterialId, ' x'),
      (qrMaterialId, 'x\ny'),
      (qrMaterialId, 'x' * 129),
    ]) {
      final result = await repo.ensureQr(pair.$1, idempotencyKey: pair.$2);
      expect((result as CommandError).code, DomainErrorCode.invalidInput);
    }
    expect(backend.requests, isEmpty);
  });

  test(
    'Không nhận nhầm QR Material khác, version lạ hoặc UUID thay token',
    () async {
      for (final change in [
        {'material_id': workflowActorA},
        {'version': 2},
        {'kind': 'HANDOVER'},
        {'payload': qrMaterialId},
        {'issued_at': '2026-11-27T09:00:00'},
      ]) {
        final response = qrResponse();
        (response['data'] as Map).addAll(change);
        backend.onRpc = (_) => workflowResponse(response);
        final result = await repo.ensureQr(qrMaterialId, idempotencyKey: 'key');
        // DTO hỏng sau lệnh ghi có thể đã phát hành QR: giữ ý định để retry.
        expect((result as CommandError).code, DomainErrorCode.timeoutUnknown);
      }
    },
  );

  test(
    'Thiếu migration và bị từ chối quyền không dùng QR demo để thay thế',
    () async {
      for (final row in [
        ('42883', 'missing function', DomainErrorCode.backendUnavailable),
        ('P0001', 'FORBIDDEN', DomainErrorCode.forbidden),
      ]) {
        backend.onRpc = (_) =>
            workflowResponse({'code': row.$1, 'message': row.$2}, status: 400);
        expect(
          (await repo.ensureQr(
            qrMaterialId,
            idempotencyKey: 'key',
          ) as CommandError).code,
          row.$3,
        );
      }
    },
  );

  test('HTTP về sau khi đổi tài khoản không trả QR của phiên cũ', () async {
    final pending = Completer<http.Response>();
    backend.onRpc = (_) => pending.future;
    final result = repo.ensureQr(qrMaterialId, idempotencyKey: 'key');
    await Future<void>.delayed(Duration.zero);
    await backend.login(asB: true);
    pending.complete(workflowResponse(qrResponse()));
    expect((await result as CommandError).code, DomainErrorCode.authRequired);
  });

  test(
    'Home giữ tổng server vượt một trang; từ chối số âm hoặc DTO thiếu trường',
    () async {
      final row = <String, dynamic>{
        'material_count': 57,
        'published_count': 31,
        'draft_count': 8,
        'hidden_count': 2,
        'active_transaction_count': 4,
        'server_at': '2026-11-27T02:00:00Z',
      };
      backend.onRpc = (_) => workflowResponse(row);
      final home = SupabaseHomeRepository(
        WorkflowRpc(backend.client, workflowActorA),
      );
      expect((await home.getOverview()).materialCount, 57);
      expect(
        backend.requests.single.url.path,
        '/rest/v1/rpc/get_home_overview',
      );
      row['material_count'] = -1;
      await expectLater(home.getOverview(), throwsA(isA<AppError>()));
      row.remove('material_count');
      await expectLater(home.getOverview(), throwsA(isA<AppError>()));
    },
  );
}

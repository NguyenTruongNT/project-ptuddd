import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/contracts/command_inputs.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/listing_workspace.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/features/listings/data/supabase_listing_workspace.dart';

import '../../support/workflow_rpc_fixture.dart';

Map<String, dynamic> _receipt() => {
  'ok': true,
  'command_id': 'server-receipt',
  'server_revision': 3,
  'data': {
    'id': 'l',
    'material_id': 'm',
    'offer_type': 'SELL',
    'status': 'PUBLISHED',
    'revision': 3,
    'asking_price_vnd': 100,
    'material_revision': 7,
    'has_active_transaction': false,
  },
};
void main() {
  late WorkflowTestBackend backend;
  late SupabaseListingWorkspace repo;
  setUp(() async {
    backend = WorkflowTestBackend();
    await backend.login();
    repo = SupabaseListingWorkspace(
      WorkflowRpc(backend.client, workflowActorA),
    );
  });
  tearDown(() async => backend.dispose());
  const command = ListingCommand(
    action: ListingAction.publish,
    materialId: 'm',
    listingId: 'l',
    expectedRevision: 1,
    expectedMaterialRevision: 7,
    offerType: OfferType.sell,
    askingPriceVnd: 100,
    idempotencyKey: 'key',
  );
  test(
    'Thiếu RPC không bị báo nhầm là dữ liệu thay đổi; lỗi lạ không lộ payload',
    () async {
      for (final code in ['PGRST202', '42883', '42703']) {
        backend.onRpc = (_) => workflowResponse({
          'code': code,
          'message': 'PRIVATE_BACKEND_DETAILS',
        }, status: 404);
        await expectLater(
          repo.searchMine(),
          throwsA(
            isA<AppError>()
                .having(
                  (e) => e.code,
                  'code',
                  DomainErrorCode.backendUnavailable,
                )
                .having(
                  (e) => e.safeMessage,
                  'safeMessage',
                  isNot(contains('PRIVATE_BACKEND_DETAILS')),
                ),
          ),
        );
        expect(
          (await repo.execute(command) as CommandError).code,
          DomainErrorCode.backendUnavailable,
        );
      }
      backend.onRpc = (_) => workflowResponse({
        'code': 'XX000',
        'message': 'PRIVATE_BACKEND_DETAILS',
      }, status: 500);
      await expectLater(
        repo.searchMine(),
        throwsA(
          isA<AppError>().having(
            (e) => e.code,
            'code',
            DomainErrorCode.unexpectedError,
          ),
        ),
      );
    },
  );
  test(
    'ACK dùng receipt thật, giữ revisions/key và không gửi actor/status',
    () async {
      backend.onRpc = (request) {
        expect(jsonDecode(request.body), command.toRpc());
        return workflowResponse(_receipt());
      };
      final result = await repo.execute(command) as CommandOk<ManagedListing>;
      expect(result.commandId, 'server-receipt');
      expect(result.serverEventId, isNull);
      expect(result.serverRevision, 3);
    },
  );
  test(
    'SQL validation giữ đúng code, ACK thiếu receipt là chưa xác định',
    () async {
      backend.onRpc = (_) => workflowResponse({
        'code': 'P0001',
        'message': 'INVALID_INPUT',
      }, status: 400);
      expect(
        (await repo.execute(command) as CommandError).code,
        DomainErrorCode.invalidInput,
      );
      backend.onRpc = (_) =>
          workflowResponse({'ok': true, 'data': _receipt()['data']});
      expect(
        (await repo.execute(command) as CommandError).code,
        DomainErrorCode.timeoutUnknown,
      );
    },
  );
  test('Query lỗi không trả fixtures; client đã đổi user không gửi mutation bằng actor cũ', () async {
    backend.onRpc = (_) => workflowResponse({
      'code': 'P0001',
      'message': 'FORBIDDEN',
    }, status: 400);
    await expectLater(
      repo.searchPublished(),
      throwsA(
        isA<AppError>().having(
          (e) => e.code,
          'code',
          DomainErrorCode.forbidden,
        ),
      ),
    );
    await backend.login(asB: true);
    backend.requests.clear();
    expect(
      (await repo.execute(command) as CommandError).code,
      DomainErrorCode.authRequired,
    );
    expect(backend.requests, isEmpty);
  });
  test('Adapter publish interface cũ tra receipt trước, không dựng revisions mới khi retry', () async {
    backend.onRpc = (request) {
      expect(request.url.path, endsWith('/get_listing_command_result'));
      return workflowResponse(_receipt());
    };
    final result =
        await repo.publishListing('l', idempotencyKey: 'key') as CommandOk;
    expect(result.commandId, 'server-receipt');
    expect(
      (await repo.publishListing(
        'other',
        idempotencyKey: 'key',
      ) as CommandError).code,
      DomainErrorCode.conflict,
    );
  });
  test('Adapter create không tái sử dụng key cho payload khác', () async {
    backend.onRpc = (_) => workflowResponse(_receipt());
    expect(
      await repo.createListing(
        const CreateListingInput(
          materialId: 'm',
          offerType: OfferType.sell,
          askingPriceVnd: 100,
        ),
        idempotencyKey: 'key',
      ),
      isA<CommandOk>(),
    );
    expect(
      (await repo.createListing(
        const CreateListingInput(materialId: 'm', offerType: OfferType.donate),
        idempotencyKey: 'key',
      ) as CommandError).code,
      DomainErrorCode.conflict,
    );
  });
}

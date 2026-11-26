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
  for (final offer in OfferType.values) {
    test(
      'SCR-06 giải mã ${offer.wire} cùng policy, giữ metadata khi ảnh không cấp được URL',
      () async {
        backend.onRpc = (request) {
          if (request.url.path.endsWith('/get_listing_image_path')) {
            // Không có quyền/ảnh không còn cấp được: không ký URL tùy ý ở client.
            expect(jsonDecode(request.body)['p_image_id'], 'image-1');
            return workflowResponse(null);
          }
          expect(request.url.path, endsWith('/get_published_listing'));
          expect(jsonDecode(request.body), {'p_listing_id': 'listing-public'});
          return workflowResponse({
            'id': 'listing-public',
            'material_id': 'material-public',
            'title': 'Tài liệu công khai',
            'subject': 'Lập trình',
            'condition': 'Tốt',
            'offer_type': offer.wire,
            'asking_price_vnd': offer == OfferType.sell ? 90000 : null,
            'is_requestable': true,
            'is_reserved': false,
            'owner_id': workflowActorB,
            'owner_name': 'Người đăng công khai',
            'material_description': 'Nội dung tài liệu',
            'description': 'Nội dung tin đăng',
            'meeting_area': 'Khu vực thư viện',
            'images': [
              {'id': 'image-1'},
            ],
          });
        };
        final details = (await repo.getPublishedDetails('listing-public'))!;
        expect(details.card.condition, 'Tốt');
        expect(details.ownerName, 'Người đăng công khai');
        expect(details.materialDescription, 'Nội dung tài liệu');
        expect(details.description, 'Nội dung tin đăng');
        expect(details.meetingArea, 'Khu vực thư viện');
        expect(details.images.single.id, 'image-1');
        expect(details.images.single.url, isNull);
        expect(details.requestBlockedReason, isEmpty);
        if (offer == OfferType.borrow) {
          expect(details.borrowPolicy!.minDays, 1);
          expect(details.borrowPolicy!.maxDays, 30);
        } else {
          expect(details.borrowPolicy, isNull);
        }
      },
    );
  }
  test(
    'Tin không còn công khai trả null, không chuyển về dữ liệu demo',
    () async {
      backend.onRpc = (_) => workflowResponse(null);
      expect(await repo.getPublishedDetails('hidden-listing'), isNull);
    },
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

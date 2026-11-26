import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:studyshare/core/backend/workflow_rpc.dart';
import 'package:studyshare/core/contracts/command_inputs.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/listing_workspace.dart';
import 'package:studyshare/core/contracts/material_workspace.dart';
import 'package:studyshare/core/contracts/models/material.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/features/listings/data/supabase_listing_workspace.dart';
import 'package:studyshare/features/materials/data/supabase_material_workspace.dart';
import 'package:studyshare/features/transactions/data/supabase_transaction_repository.dart';

import '../support/material_image_fixtures.dart';

class _DropAck extends http.BaseClient {
  final inner = http.Client();
  bool drop = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final result = await inner.send(request);
    if (drop && request.url.path.endsWith('/rpc/save_listing')) {
      drop = false;
      await result.stream.drain<void>();
      throw http.ClientException('Lost ACK');
    }
    return result;
  }

  @override
  void close() => inner.close();
}

void main() {
  const run = bool.fromEnvironment('RUN_LISTING_SUPABASE');
  const shared = bool.fromEnvironment('RUN_LISTING_SHARED');
  const url = String.fromEnvironment('LISTING_TEST_URL');
  const publicKey = String.fromEnvironment('LISTING_TEST_PUBLIC_KEY');
  test(
    shared
        ? 'Listing local + shared JWT: Request, rollback, snapshot, hide và archive'
        : 'Listing local: ảnh thật, A/B, command/retry, race, snapshot và quyền đọc',
    () async {
      expect(url, 'http://127.0.0.1:54321');
      final key = Platform.environment['LISTING_TEST_ADMIN_KEY'];
      expect(key, isNotEmpty);
      final admin = SupabaseClient(
        url,
        key!,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final gate = _DropAck();
      final a = SupabaseClient(
        url,
        publicKey,
        httpClient: gate,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final b = SupabaseClient(
        url,
        publicKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final users = <String>[];
      final materials = <String>[];
      final suffix = const Uuid().v4();
      final password = 'Listing-$suffix!Aa1';
      addTearDown(() async {
        // Dọn đúng fixture của lần chạy; không reset DB và không sửa cloud.
        if (materials.isNotEmpty) {
          final listings = await admin
              .from('listings')
              .select('id')
              .inFilter('material_id', materials);
          final ids = listings.map((e) => e['id'] as String).toList();
          if (ids.isNotEmpty) {
            final txns = await admin
                .from('transactions')
                .select('id')
                .inFilter('listing_id', ids);
            final txnIds = txns.map((t) => t['id'] as String).toList();
            if (txnIds.isNotEmpty) {
              // Chỉ fixture do test tạo: dọn các FK trước domain chính.
              for (final table in [
                'transaction_cancellations',
                'transaction_events',
                'payment_confirmations',
              ]) {
                await admin
                    .from(table)
                    .delete()
                    .inFilter('transaction_id', txnIds);
              }
              await admin.from('transactions').delete().inFilter('id', txnIds);
            }
            await admin
                .from('exchange_requests')
                .delete()
                .inFilter('listing_id', ids);
            await admin
                .from('listing_snapshot_images')
                .delete()
                .inFilter('listing_id', ids);
            await admin.from('listings').delete().inFilter('id', ids);
          }
          final paths = await admin
              .from('material_image_uploads')
              .select('storage_path')
              .inFilter('actor_id', users);
          if (paths.isNotEmpty) {
            await admin.storage
                .from(SupabaseMaterialWorkspace.bucket)
                .remove(paths.map((e) => e['storage_path'] as String).toList());
          }
          await admin
              .from('material_images')
              .delete()
              .inFilter('material_id', materials);
          await admin
              .from('material_image_uploads')
              .delete()
              .inFilter('actor_id', users);
          await admin
              .from('command_receipts')
              .delete()
              .inFilter('actor_id', users);
          await admin.from('materials').delete().inFilter('id', materials);
        }
        for (final user in users) {
          await admin.auth.admin.deleteUser(user);
        }
        await a.dispose();
        await b.dispose();
        await admin.dispose();
        gate.close();
      });
      for (final pair in [(a, 'a'), (b, 'b')]) {
        final email = 'n3-${pair.$2}-$suffix@example.test';
        final u = await admin.auth.admin.createUser(
          AdminUserAttributes(
            email: email,
            password: password,
            emailConfirm: true,
          ),
        );
        users.add(u.user!.id);
        await pair.$1.auth.signInWithPassword(email: email, password: password);
        await pair.$1.from('profiles').insert({
          'user_id': u.user!.id,
          'display_name': 'Ngày 3 ${pair.$2}',
        });
      }
      final ma = SupabaseMaterialWorkspace(a, users[0]);
      final ra = SupabaseListingWorkspace(WorkflowRpc(a, users[0]));
      final rb = SupabaseListingWorkspace(WorkflowRpc(b, users[1]));
      Future<Material> make({bool photo = true}) async {
        final ids = <String>[];
        if (photo) {
          final image = await ma.uploadImage(
            MaterialPhoto(
              localId: const Uuid().v4(),
              name: 'cover.jpg',
              mimeType: 'image/jpeg',
              bytes: materialJpegFixture(),
            ),
          );
          ids.add(image.id);
        }
        final result = await ma.createMaterial(
          CreateMaterialInput(
            title: 'Cùng một tên',
            subject: 'Toán',
            condition: 'Tốt',
            imageIds: ids,
          ),
          idempotencyKey: const Uuid().v4(),
        );
        expect(result, isA<CommandOk<Material>>());
        final m = (result as CommandOk<Material>).data;
        materials.add(m.id);
        return m;
      }

      final m = await make(photo: false);
      final draft = await ra.execute(
        ListingCommand(
          action: ListingAction.draft,
          materialId: m.id,
          offerType: OfferType.sell,
          expectedMaterialRevision: m.revision,
          idempotencyKey: 'draft-$suffix',
        ),
      );
      expect(draft, isA<CommandOk<ManagedListing>>());
      final d = (draft as CommandOk<ManagedListing>).data;
      final missing = await ra.execute(
        ListingCommand(
          action: ListingAction.publish,
          materialId: m.id,
          listingId: d.listing.id,
          expectedRevision: d.listing.revision,
          expectedMaterialRevision: m.revision,
          offerType: OfferType.sell,
          askingPriceVnd: 1,
          idempotencyKey: 'missing-$suffix',
        ),
      );
      expect((missing as CommandError).code, DomainErrorCode.invalidInput);
      final image = await ma.uploadImage(
        MaterialPhoto(
          localId: const Uuid().v4(),
          name: 'cover.jpg',
          mimeType: 'image/jpeg',
          bytes: materialJpegFixture(),
        ),
        materialId: m.id,
      );
      final edited = await ma.updateMaterial(
        m.id,
        CreateMaterialInput(
          title: m.title,
          subject: m.subject,
          condition: m.condition,
          imageIds: [image.id],
        ),
        expectedRevision: m.revision,
        idempotencyKey: 'image-$suffix',
      );
      final newM = (edited as CommandOk<Material>).data;
      final publish = ListingCommand(
        action: ListingAction.publish,
        materialId: m.id,
        listingId: d.listing.id,
        expectedRevision: d.listing.revision,
        expectedMaterialRevision: newM.revision,
        offerType: OfferType.sell,
        askingPriceVnd: 123456,
        description: 'Snapshot giữ giá',
        idempotencyKey: 'publish-$suffix',
      );
      gate.drop = true;
      expect(
        (await ra.execute(publish) as CommandError).code,
        DomainErrorCode.timeoutUnknown,
      );
      final receipt = await ra.getCommandResult(publish);
      expect(receipt, isA<CommandOk<ManagedListing>>());
      expect(
        (await ra.execute(publish) as CommandOk).commandId,
        (receipt as CommandOk).commandId,
      );
      final pub = await rb.getPublishedDetails(d.listing.id);
      expect(pub!.card.askingPriceVnd, 123456);
      expect(pub.card.isRequestable, isTrue);
      expect(pub.images.single.url, isNotNull);
      expect(
        (await http.get(Uri.parse(pub.images.single.url!))).statusCode,
        200,
      );
      final managed = await ra.getManaged(listingId: d.listing.id);
      final forged = await rb.execute(
        ListingCommand(
          action: ListingAction.hide,
          materialId: m.id,
          listingId: d.listing.id,
          expectedRevision: managed!.listing.revision,
          idempotencyKey: 'forged-$suffix',
        ),
      );
      expect((forged as CommandError).code, DomainErrorCode.forbidden);
      final hide = ListingCommand(
        action: ListingAction.hide,
        materialId: m.id,
        listingId: d.listing.id,
        expectedRevision: managed.listing.revision,
        idempotencyKey: 'hide-$suffix',
      );
      expect(await ra.execute(hide), isA<CommandOk<ManagedListing>>());
      expect(await rb.getPublishedDetails(d.listing.id), isNull);
      expect(
        await b.rpc(
          'get_listing_image_path',
          params: {'p_listing_id': d.listing.id, 'p_image_id': image.id},
        ),
        isNull,
      );
      final hidden = await ra.getManaged(listingId: d.listing.id);
      expect(
        (await ra.execute(
          ListingCommand(
            action: ListingAction.draft,
            materialId: m.id,
            listingId: d.listing.id,
            expectedRevision: hidden!.listing.revision,
            expectedMaterialRevision: newM.revision,
            offerType: OfferType.sell,
            idempotencyKey: 'hidden-null-$suffix',
          ),
        ) as CommandError).code,
        DomainErrorCode.invalidInput,
      );
      expect(
        (await ra.getManaged(listingId: d.listing.id))!.listing.revision,
        hidden.listing.revision,
      );
      expect(
        (await ra.getManaged(listingId: d.listing.id))!.listing.askingPriceVnd,
        123456,
      );
      expect(
        await ra.execute(
          ListingCommand(
            action: ListingAction.show,
            materialId: m.id,
            listingId: d.listing.id,
            expectedRevision: hidden.listing.revision,
            expectedMaterialRevision: newM.revision,
            idempotencyKey: 'show-$suffix',
          ),
        ),
        isA<CommandOk<ManagedListing>>(),
      );
      for (final type in [OfferType.borrow, OfferType.donate]) {
        final next = await make();
        final first = ListingCommand(
          action: ListingAction.publish,
          materialId: next.id,
          expectedMaterialRevision: next.revision,
          offerType: type,
          idempotencyKey: 'race-a-${type.wire}-$suffix',
        );
        final second = ListingCommand(
          action: ListingAction.publish,
          materialId: next.id,
          expectedMaterialRevision: next.revision,
          offerType: type,
          idempotencyKey: 'race-b-${type.wire}-$suffix',
        );
        final race = await Future.wait([ra.execute(first), ra.execute(second)]);
        expect(race.whereType<CommandOk<ManagedListing>>().length, 1);
        expect(
          race.whereType<CommandError<ManagedListing>>().single.code,
          DomainErrorCode.conflict,
        );
      }
      final cards = await rb.searchPublished(keyword: 'Cùng một tên');
      expect(cards.where((e) => materials.contains(e.materialId)).length, 3);
      expect(
        await b.from('materials').select().inFilter('id', materials),
        isEmpty,
      );
      if (shared) {
        // Các RPC _test chỉ tồn tại trong lượt chạy local, gọi bằng JWT A/B thật.
        // Đây là kiểm tra giao điểm trigger, không xác nhận RPC Request của Khanh đã hoàn chỉnh.
        Future<ManagedListing> makeShared() async {
          final material = await make();
          return (await ra.execute(
            ListingCommand(
              action: ListingAction.publish,
              materialId: material.id,
              expectedMaterialRevision: material.revision,
              offerType: OfferType.sell,
              askingPriceVnd: 100,
              idempotencyKey: const Uuid().v4(),
            ),
          ) as CommandOk<ManagedListing>).data;
        }

        Future<String> request(String listingId) async => await b.rpc(
          '_test_listing_review_request',
          params: {'p_listing_id': listingId},
        ) as String;
        Future<Object?> approve(
          String requestId, {
          bool wrongOrder = false,
          bool fail = false,
        }) => a
            .rpc(
              '_test_listing_review_approve',
              params: {
                'p_request_id': requestId,
                'p_wrong_order': wrongOrder,
                'p_fail_after_insert': fail,
              },
            )
            .timeout(const Duration(seconds: 20));
        Future<CommandResult<ManagedListing>> visibility(
          ManagedListing row,
          ListingAction action,
        ) => ra.execute(
          ListingCommand(
            action: action,
            materialId: row.listing.materialId,
            listingId: row.listing.id,
            expectedRevision: row.listing.revision,
            expectedMaterialRevision: row.materialRevision,
            idempotencyKey: const Uuid().v4(),
          ),
        );
        Matcher unavailable(String message) => isA<PostgrestException>()
            .having((e) => e.code, 'SQLSTATE', 'P0001')
            .having((e) => e.message, 'message', message);

        final current = await makeShared();
        final lid = current.listing.id;
        final requestId = await request(lid);
        final hiddenPending = (await visibility(
          current,
          ListingAction.hide,
        ) as CommandOk<ManagedListing>).data;
        await expectLater(
          approve(requestId),
          throwsA(unavailable('MATERIAL_UNAVAILABLE')),
        );
        await visibility(hiddenPending, ListingAction.show);
        await expectLater(
          approve(requestId, wrongOrder: true),
          throwsA(unavailable('MATERIAL_UNAVAILABLE')),
        );
        await expectLater(
          approve(requestId, fail: true),
          throwsA(unavailable('CONFLICT')),
        );
        expect(
          (await admin
              .from('exchange_requests')
              .select('status')
              .eq('id', requestId)
              .single())['status'],
          'PENDING',
        );
        expect(
          await admin.from('transactions').select('id').eq('listing_id', lid),
          isEmpty,
        );

        final txnId = await approve(requestId) as String;
        final before = await admin
            .from('transactions')
            .select('terms_snapshot')
            .eq('id', txnId)
            .single();
        final terms = before['terms_snapshot'] as Map;
        final publication = await admin
            .from('listings')
            .select('publication_snapshot')
            .eq('id', lid)
            .single();
        expect(terms['listing'], publication['publication_snapshot']);
        expect(terms['transaction_contract'], 'kept');
        expect((terms['listing'] as Map).containsKey('caller_fake'), isFalse);
        await expectLater(
          request(lid),
          throwsA(unavailable('MATERIAL_UNAVAILABLE')),
        );
        final active = (await ra.getManaged(listingId: lid))!;
        final hiddenActive = (await visibility(
          active,
          ListingAction.hide,
        ) as CommandOk<ManagedListing>).data;
        final shownActive = (await visibility(
          hiddenActive,
          ListingAction.show,
        ) as CommandOk<ManagedListing>).data;
        expect((await rb.getPublishedDetails(lid))!.card.isReserved, isTrue);
        final cancelHidden = (await visibility(
          shownActive,
          ListingAction.hide,
        ) as CommandOk<ManagedListing>).data;

        // Chạy chính RPC/repository hủy của Sơn; cạnh tranh với show không hồi sinh ARCHIVED.
        final ca = SupabaseTransactionCancellationRepository(
          WorkflowRpc(a, users[0]),
        );
        final cb = SupabaseTransactionCancellationRepository(
          WorkflowRpc(b, users[1]),
        );
        expect(
          await ca.proposeCancellation(
            txnId,
            'Kiểm tra tích hợp local',
            idempotencyKey: 'propose-$suffix',
          ),
          isA<CommandOk>(),
        );
        final endings = await Future.wait<Object?>([
          cb.acceptCancellation(txnId, idempotencyKey: 'cancel-$suffix'),
          visibility(cancelHidden, ListingAction.show),
        ]);
        expect(endings[0], isA<CommandOk>());
        expect(
          endings[1],
          anyOf(
            isA<CommandOk>(),
            isA<CommandError>().having(
              (e) => e.code,
              'code',
              DomainErrorCode.conflict,
            ),
          ),
        );
        final archived = await admin
            .from('listings')
            .select('status,revision')
            .eq('id', lid)
            .single();
        expect(archived['status'], 'ARCHIVED');
        expect(
          archived['revision'] as int,
          greaterThan(cancelHidden.listing.revision),
        );
        expect(
          (await admin
              .from('transactions')
              .select('terms_snapshot,status')
              .eq('id', txnId)
              .single())['terms_snapshot'],
          terms,
        );
        final holder = await admin
            .from('materials')
            .select('owner_id,holder_id')
            .eq('id', current.listing.materialId)
            .single();
        expect(holder, {'owner_id': users[0], 'holder_id': users[0]});
        final replay = await cb.acceptCancellation(
          txnId,
          idempotencyKey: 'cancel-$suffix',
        ) as CommandOk;
        expect(replay.serverEventId, (endings[0] as CommandOk).serverEventId);
        expect(
          (await admin
              .from('listings')
              .select('revision')
              .eq('id', lid)
              .single())['revision'],
          archived['revision'],
        );

        for (var order = 0; order < 2; order++) {
          final raced = await makeShared();
          final rid = await request(raced.listing.id);
          Future<Object?> tryApprove() async {
            try {
              return await approve(rid);
            } on PostgrestException catch (e) {
              return e;
            }
          }

          // Hai HTTP request cạnh tranh thật, không dùng sleep để ép kết quả giả.
          final outcomes = await Future.wait<Object?>(
            order == 0
                ? [tryApprove(), visibility(raced, ListingAction.hide)]
                : [visibility(raced, ListingAction.hide), tryApprove()],
          );
          final result = outcomes[order == 0 ? 0 : 1];
          expect(outcomes[order == 0 ? 1 : 0], isA<CommandOk>());
          final state = await admin
              .from('exchange_requests')
              .select('status')
              .eq('id', rid)
              .single();
          final transactions = await admin
              .from('transactions')
              .select('id')
              .eq('listing_id', raced.listing.id);
          if (result is String) {
            expect(state['status'], 'ACCEPTED');
            expect(transactions.length, 1);
          } else {
            expect(result, unavailable('MATERIAL_UNAVAILABLE'));
            expect(state['status'], 'PENDING');
            expect(transactions, isEmpty);
          }
          expect(
            (await admin
                .from('listings')
                .select('status')
                .eq('id', raced.listing.id)
                .single())['status'],
            'HIDDEN',
          );
        }
      }
      await a.auth.signOut();
      expect(
        (await ra.execute(publish) as CommandError).code,
        DomainErrorCode.authRequired,
      );
    },
    skip: !run,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

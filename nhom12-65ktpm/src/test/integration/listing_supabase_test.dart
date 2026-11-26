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
  const url = String.fromEnvironment('LISTING_TEST_URL');
  const publicKey = String.fromEnvironment('LISTING_TEST_PUBLIC_KEY');
  test(
    'Listing local: ảnh thật, A/B, command/retry, race, snapshot và quyền đọc',
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
        await ra.execute(
          ListingCommand(
            action: ListingAction.show,
            materialId: m.id,
            listingId: d.listing.id,
            expectedRevision: hidden!.listing.revision,
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
      await a.auth.signOut();
      expect(
        (await ra.execute(publish) as CommandError).code,
        DomainErrorCode.authRequired,
      );
    },
    skip: !run,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

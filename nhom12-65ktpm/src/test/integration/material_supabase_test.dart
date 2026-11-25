import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:studyshare/features/materials/data/material_draft_store.dart';
import 'package:studyshare/core/contracts/command_inputs.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/material_workspace.dart';
import 'package:studyshare/core/contracts/models/material.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/features/materials/data/supabase_material_workspace.dart';

import '../support/material_image_fixtures.dart';

class _DeviceCache extends MaterialDraftStore {
  final _values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

class _NetworkGate extends http.BaseClient {
  final _inner = http.Client();
  bool offline = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (offline) throw http.ClientException('Offline test');
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

void main() {
  const run = bool.fromEnvironment('RUN_MATERIAL_SUPABASE');
  const url = String.fromEnvironment('MATERIAL_TEST_URL');
  const publicKey = String.fromEnvironment('MATERIAL_TEST_PUBLIC_KEY');
  test(
    'Material Supabase thật: Auth A/B, upload bytes, RPC, retry, RLS, chuyển chủ',
    () async {
      final adminKey = Platform.environment['MATERIAL_TEST_ADMIN_KEY'];
      expect(adminKey, isNotEmpty);
      expect(
        url == 'http://127.0.0.1:54321' ||
            url == 'https://dacrjfgleursgtnzeoix.supabase.co',
        isTrue,
        reason: 'Only local or approved StudyShare development project',
      );
      final admin = SupabaseClient(
        url,
        adminKey!,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final clients = <SupabaseClient>[];
      final users = <String>[];
      final materials = <String>[];
      final suffix = const Uuid().v4();
      final recoveryFile = File('.dart_tool/material-test-users-$suffix.json');
      final password = 'Material-$suffix!Aa1';
      final emails = [
        'day2-a-$suffix@example.test',
        'day2-b-$suffix@example.test',
      ];
      addTearDown(() async {
        // Chỉ dọn dữ liệu của chính hai account vừa tạo; không reset DB.
        if (users.isNotEmpty) {
          final uploads = await admin
              .from('material_image_uploads')
              .select('storage_path')
              .inFilter('actor_id', users);
          final paths = uploads
              .map((r) => r['storage_path'] as String)
              .toList();
          if (paths.isNotEmpty) {
            await admin.storage
                .from(SupabaseMaterialWorkspace.bucket)
                .remove(paths);
          }
          if (materials.isNotEmpty) {
            await admin
                .from('listings')
                .delete()
                .inFilter('material_id', materials);
            await admin
                .from('material_images')
                .delete()
                .inFilter('material_id', materials);
          }
          await admin
              .from('material_image_uploads')
              .delete()
              .inFilter('actor_id', users);
          await admin
              .from('command_receipts')
              .delete()
              .inFilter('actor_id', users);
          if (materials.isNotEmpty) {
            await admin.from('materials').delete().inFilter('id', materials);
          }
          for (final id in users) {
            await admin.auth.admin.deleteUser(id);
          }
        }
        for (final c in clients) {
          await c.dispose();
        }
        await admin.dispose();
        if (await recoveryFile.exists()) await recoveryFile.delete();
      });
      for (final email in emails) {
        final user = await admin.auth.admin.createUser(
          AdminUserAttributes(
            email: email,
            password: password,
            emailConfirm: true,
          ),
        );
        users.add(user.user!.id);
        await recoveryFile.writeAsString(
          jsonEncode({'url': url, 'ids': users}),
        );
        final c = SupabaseClient(
          url,
          publicKey,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        clients.add(c);
        await c.auth.signInWithPassword(email: email, password: password);
      }
      final a = SupabaseMaterialWorkspace(clients[0], users[0]);
      final b = SupabaseMaterialWorkspace(clients[1], users[1]);
      final bytes = await File('assets/branding/google_g.png').readAsBytes();
      final photo = MaterialPhoto(
        localId: const Uuid().v4(),
        name: 'cover.png',
        mimeType: 'image/png',
        bytes: bytes,
      );
      final first = await a.uploadImage(photo);
      final second = await a.uploadImage(photo);
      for (final image in [
        ('image/jpeg', materialJpegFixture()),
        ('image/webp', materialWebpFixture()),
      ]) {
        final uploaded = await a.uploadImage(
          MaterialPhoto(
            localId: const Uuid().v4(),
            name: 'fixture',
            mimeType: image.$1,
            bytes: image.$2,
          ),
        );
        await a.discardUpload(uploaded.id);
      }
      final input = CreateMaterialInput(
        title: 'Day 2 book',
        subject: 'Toán',
        condition: 'Có ghi chú',
        description: 'Dòng thứ nhất\nDòng thứ hai',
        isbn: '9780131103627',
        imageIds: [first.id, second.id],
      );
      final create = await a.createMaterial(
        input,
        idempotencyKey: 'create-$suffix',
      );
      expect(create, isA<CommandOk<Material>>());
      final created = (create as CommandOk<Material>).data;
      materials.add(created.id);
      expect(created.ownerId, users[0]);
      expect(created.holderId, users[0]);
      final retry = await a.createMaterial(
        input,
        idempotencyKey: 'create-$suffix',
      ) as CommandOk<Material>;
      expect(retry.data.id, created.id);
      expect(retry.commandId, create.commandId);
      final conflict = await a.createMaterial(
        const CreateMaterialInput(
          title: 'Different',
          subject: 'Toán',
          condition: 'Tốt',
        ),
        idempotencyKey: 'create-$suffix',
      );
      expect((conflict as CommandError).code, DomainErrorCode.conflict);
      final duplicate = await a.createMaterial(
        const CreateMaterialInput(
          title: 'Day 2 book',
          subject: 'Toán',
          condition: 'Tốt',
          isbn: '9780131103627',
        ),
        idempotencyKey: 'duplicate-$suffix',
      ) as CommandOk<Material>;
      materials.add(duplicate.data.id);
      expect(duplicate.data.id, isNot(created.id));
      final details = (await a.getDetails(created.id))!;
      expect(details.images.map((i) => i.id), [first.id, second.id]);
      expect(details.images.every((i) => i.url != null), isTrue);
      expect(
        await clients[0].storage
            .from(SupabaseMaterialWorkspace.bucket)
            .download(first.storagePath),
        bytes,
      );
      expect(await b.getDetails(created.id), isNull);
      expect((await b.searchMaterials()).items, isEmpty);
      await expectLater(
        clients[1].storage
            .from(SupabaseMaterialWorkspace.bucket)
            .download(first.storagePath),
        throwsA(isA<StorageException>()),
      );
      expect(
        (await b.updateMaterial(
          created.id,
          input,
          expectedRevision: 1,
          idempotencyKey: 'attack-$suffix',
        ) as CommandError).code,
        DomainErrorCode.forbidden,
      );
      final steal = await b.createMaterial(
        input,
        idempotencyKey: 'steal-$suffix',
      );
      expect((steal as CommandError).code, DomainErrorCode.forbidden);
      await expectLater(
        clients[0].rpc(
          'verify_material_image_upload',
          params: {'p_image_id': first.id, 'p_actor_id': users[0]},
        ),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        clients[0]
            .from('materials')
            .update({'owner_id': users[1]})
            .eq('id', created.id),
        throwsA(isA<PostgrestException>()),
      );
      final edit = CreateMaterialInput(
        title: 'Day 2 edited',
        subject: input.subject,
        condition: input.condition,
        description: input.description,
        isbn: input.isbn,
        imageIds: [second.id, first.id],
      );
      final updated = await a.updateMaterial(
        created.id,
        edit,
        expectedRevision: 1,
        idempotencyKey: 'edit-$suffix',
      ) as CommandOk<Material>;
      expect(updated.data.revision, 2);
      expect((await a.getDetails(created.id))!.images.first.id, second.id);
      final races = await Future.wait([
        a.updateMaterial(
          created.id,
          edit,
          expectedRevision: 2,
          idempotencyKey: 'race-a-$suffix',
        ),
        a.updateMaterial(
          created.id,
          edit,
          expectedRevision: 2,
          idempotencyKey: 'race-b-$suffix',
        ),
      ]);
      expect(races.whereType<CommandOk<Material>>(), hasLength(1));
      expect(
        races.whereType<CommandError<Material>>().single.code,
        DomainErrorCode.conflict,
      );
      // Reopen with a newly authenticated client, independent of UI memory.
      final reopened = SupabaseClient(
        url,
        publicKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      clients.add(reopened);
      await reopened.auth.signInWithPassword(
        email: emails[0],
        password: password,
      );
      expect(
        (await SupabaseMaterialWorkspace(
          reopened,
          users[0],
        ).getDetails(created.id))!.material.title,
        'Day 2 edited',
      );
      expect(
        (await a.searchMaterials(query: 'edited', filter: 'ready')).items,
        hasLength(1),
      );
      final gate = _NetworkGate();
      final cachedClient = SupabaseClient(
        url,
        publicKey,
        httpClient: gate,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      clients.add(cachedClient);
      await cachedClient.auth.signInWithPassword(
        email: emails[0],
        password: password,
      );
      final deviceCache = _DeviceCache();
      final cachedRepo = SupabaseMaterialWorkspace(
        cachedClient,
        users[0],
        cache: deviceCache,
      );
      await cachedRepo.getDetails(created.id);
      await cachedRepo.searchMaterials();
      gate.offline = true;
      final offlineDetails = (await cachedRepo.getDetails(created.id))!;
      expect(offlineDetails.isCached, isTrue);
      expect(offlineDetails.canEdit, isFalse);
      expect((await cachedRepo.searchMaterials()).isCached, isTrue);
      // A cache shared with another repository is still partitioned by actor.
      expect(
        await SupabaseMaterialWorkspace(
          clients[1],
          users[1],
          cache: deviceCache,
        ).getDetails(created.id),
        isNull,
      );
      final listed = await admin
          .from('listings')
          .insert({
            'material_id': duplicate.data.id,
            'offer_type': 'DONATE',
            'status': 'PUBLISHED',
          })
          .select('id')
          .single();
      expect((await a.getDetails(duplicate.data.id))!.canEdit, isFalse);
      expect(
        (await a.updateMaterial(
          duplicate.data.id,
          input,
          expectedRevision: 1,
          idempotencyKey: 'published-$suffix',
        ) as CommandError).code,
        DomainErrorCode.materialUnavailable,
      );
      await admin.from('listings').delete().eq('id', listed['id']);
      // Structural image verification rejects a file with a forged MIME.
      final forged = MaterialPhoto(
        localId: 'bad',
        name: 'bad.png',
        mimeType: 'image/png',
        bytes: bytes.sublist(0, 20),
      );
      await expectLater(a.uploadImage(forged), throwsA(isA<AppError>()));
      // Transfer is test setup only; the mobile app has no setOwner API.
      await admin
          .from('materials')
          .update({'owner_id': users[1], 'holder_id': users[1]})
          .eq('id', created.id);
      expect(await a.getDetails(created.id), isNull);
      final transferred = (await b.getDetails(created.id))!;
      expect(transferred.images.every((i) => i.url != null), isTrue);
      await expectLater(
        clients[0].storage
            .from(SupabaseMaterialWorkspace.bucket)
            .createSignedUrl(first.storagePath, 60),
        throwsA(isA<StorageException>()),
      );
      expect(
        await clients[1].storage
            .from(SupabaseMaterialWorkspace.bucket)
            .download(first.storagePath),
        bytes,
      );
      final afterTransfer = await b.updateMaterial(
        created.id,
        edit,
        expectedRevision: 3,
        idempotencyKey: 'new-owner-$suffix',
      );
      expect(afterTransfer, isA<CommandOk<Material>>());
    },
    skip: !run,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

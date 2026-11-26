import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/contracts/command_inputs.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/contracts/material_workspace.dart';
import 'package:studyshare/core/contracts/models/material.dart';
import 'package:studyshare/core/errors/app_error.dart';
import 'package:studyshare/core/mock/mock_fixtures.dart';
import 'package:studyshare/features/materials/data/mock_material_workspace.dart';
import 'package:studyshare/features/materials/domain/material_validation.dart';

void main() {
  const input = CreateMaterialInput(
    title: 'Giải tích',
    subject: 'Toán',
    condition: 'Có ghi chú',
    isbn: '9780131103627',
  );
  MaterialPhoto photo() => MaterialPhoto(
    localId: 'local',
    name: 'cover.png',
    mimeType: 'image/png',
    bytes: Uint8List.fromList([137, 80, 78, 71]),
  );
  test('ISBN checksum, text giới hạn và chống ký tự điều khiển', () {
    expect(MaterialValidation.isbn('978-0-13-110362-7'), isTrue);
    expect(MaterialValidation.isbn('0-8044-2957-X'), isTrue);
    expect(MaterialValidation.isbn('9780131103628'), isFalse);
    expect(
      MaterialValidation.isbn('1234567890128'),
      isFalse,
      reason: 'EAN checksum alone does not make an ISBN',
    );
    expect(MaterialValidation.isbn('123'), isFalse);
    expect(MaterialValidation.text(' \n ', 200), isFalse);
    expect(MaterialValidation.text('abc\u0000', 200), isFalse);
    expect(
      MaterialValidation.input(
        const CreateMaterialInput(
          title: 'a',
          subject: 'b',
          condition: 'c',
          imageIds: ['x', 'x'],
        ),
      ),
      isFalse,
    );
  });
  test(
    'Tạo cùng ISBN khác key có ID riêng; retry cùng key giữ một bản',
    () async {
      final store = MockMaterialStore(seeded: false);
      final a = MockMaterialWorkspace(store, MockFixtures.userA);
      final first = await a.createMaterial(input, idempotencyKey: 'one');
      final retry = await a.createMaterial(input, idempotencyKey: 'one');
      final second = await a.createMaterial(input, idempotencyKey: 'two');
      expect(
        (first as CommandOk<Material>).data.id,
        (retry as CommandOk<Material>).data.id,
      );
      expect(first.commandId, retry.commandId);
      expect(first.data.id, isNot((second as CommandOk<Material>).data.id));
      expect(store.values, hasLength(2));
      final changed = await a.createMaterial(
        const CreateMaterialInput(
          title: 'Khác',
          subject: 'Toán',
          condition: 'Tốt',
        ),
        idempotencyKey: 'one',
      );
      expect((changed as CommandError).code, DomainErrorCode.conflict);
    },
  );
  test('Ảnh riêng tư, sửa quyền owner, revision và bộ lọc', () async {
    final store = MockMaterialStore(seeded: false);
    final a = MockMaterialWorkspace(store, MockFixtures.userA);
    final b = MockMaterialWorkspace(store, MockFixtures.userB);
    final image = await a.uploadImage(photo());
    final created = await a.createMaterial(
      CreateMaterialInput(
        title: input.title,
        subject: input.subject,
        condition: input.condition,
        imageIds: [image.id],
      ),
      idempotencyKey: 'create',
    ) as CommandOk<Material>;
    expect((await a.getDetails(created.data.id))!.images.single.id, image.id);
    expect((await a.searchMaterials(filter: 'ready')).items, hasLength(1));
    expect(await b.getDetails(created.data.id), isNull);
    final forged = await b.updateMaterial(
      created.data.id,
      input,
      expectedRevision: 1,
      idempotencyKey: 'forge',
    );
    expect((forged as CommandError).code, DomainErrorCode.forbidden);
    final edited = await a.updateMaterial(
      created.data.id,
      input,
      expectedRevision: 1,
      idempotencyKey: 'edit',
    ) as CommandOk<Material>;
    expect(edited.data.revision, 2);
    expect(edited.data.ownerId, MockFixtures.userA);
    final conflict = await a.updateMaterial(
      created.data.id,
      input,
      expectedRevision: 1,
      idempotencyKey: 'other-device',
    );
    expect((conflict as CommandError).code, DomainErrorCode.conflict);
    expect((await a.searchMaterials(filter: 'ready')).items, isEmpty);
  });
  test(
    'Không lấy upload của A gắn vào sách B; lỗi không ghi success',
    () async {
      final store = MockMaterialStore(seeded: false);
      final a = MockMaterialWorkspace(store, MockFixtures.userA);
      final b = MockMaterialWorkspace(store, MockFixtures.userB);
      final image = await a.uploadImage(photo());
      final result = await b.createMaterial(
        CreateMaterialInput(
          title: 'B',
          subject: 'B',
          condition: 'B',
          imageIds: [image.id],
        ),
        idempotencyKey: 'b',
      );
      expect((result as CommandError).code, DomainErrorCode.forbidden);
      a.failUpload = true;
      await expectLater(a.uploadImage(photo()), throwsA(isA<AppError>()));
      a.failSave = true;
      expect(
        await a.createMaterial(input, idempotencyKey: 'failed'),
        isA<CommandError>(),
      );
      expect(store.values, isEmpty);
    },
  );
  test(
    'Fixture giữ nguyên: sách đang mượn và tin công khai bị khóa sửa',
    () async {
      final a = MockMaterialWorkspace(MockMaterialStore(), MockFixtures.userA);
      expect(
        (await a.getDetails('mat-borrow-01'))!.editBlockedReason,
        'TRANSACTION_ACTIVE',
      );
      expect(
        (await a.getDetails('mat-donate-01'))!.editBlockedReason,
        'LISTING_PUBLISHED',
      );
      expect((await a.getDetails('mat-borrow-02'))!.canEdit, isTrue);
      final result = await a.updateMaterial(
        'mat-borrow-01',
        input,
        expectedRevision: 1,
        idempotencyKey: 'locked',
      );
      expect(
        (result as CommandError).code,
        DomainErrorCode.materialUnavailable,
      );
    },
  );
}

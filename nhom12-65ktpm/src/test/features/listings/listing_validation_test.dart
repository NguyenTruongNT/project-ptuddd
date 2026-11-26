import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/contracts/domain_enums.dart';
import 'package:studyshare/core/contracts/listing_workspace.dart';
import 'package:studyshare/features/listings/data/listing_drafts.dart';
import 'package:studyshare/features/materials/data/material_draft_store.dart';
import 'package:studyshare/features/listings/domain/listing_validation.dart';

class _MemoryStore extends MaterialDraftStore {
  final values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    values[key] = value;
  }
}

void main() {
  test('Giá không được xóa dấu lẻ, làm tròn hoặc overflow', () {
    for (final raw in [
      '',
      '0',
      '-1',
      '1.5',
      '1,5',
      '1e3',
      'NaN',
      'Infinity',
      '9223372036854775808',
    ]) {
      expect(ListingValidation.price(raw), isNull, reason: raw);
    }
    expect(ListingValidation.price('0001'), 1);
    expect(ListingValidation.price('9223372036854775807'), 9223372036854775807);
  });
  test(
    'Nháp SELL được thiếu giá, công bố thì không; BORROW không nhận tiền',
    () {
      String? validate(OfferType? offer, String price, bool publish) =>
          ListingValidation.validate(
            offer: offer,
            priceText: price,
            description: '',
            meetingArea: '',
            publish: publish,
          );
      expect(validate(OfferType.sell, '', false), isNull);
      expect(validate(OfferType.sell, '', true), isNotNull);
      expect(validate(OfferType.sell, '0', false), isNotNull);
      expect(validate(OfferType.borrow, '1', false), isNotNull);
      expect(validate(null, '', false), isNotNull);
    },
  );
  test(
    'Văn bản đếm Unicode, giữ newline hợp lệ, chặn control và vượt biên',
    () {
      expect(ListingValidation.text('😀' * 2000, 2000), isTrue);
      expect(ListingValidation.text('á' * 2001, 2000), isFalse);
      expect(ListingValidation.text('Dòng 1\nDòng 2', 2000), isTrue);
      expect(ListingValidation.text('ẩn\x00', 2000), isFalse);
    },
  );
  test('Lưu HIDDEN SELL bắt buộc giá; DRAFT vẫn được thiếu giá', () {
    String? validate(ListingStatus? status, String price) =>
        ListingValidation.validate(
          offer: OfferType.sell,
          priceText: price,
          description: '',
          meetingArea: '',
          publish: false,
          currentStatus: status,
        );
    expect(validate(null, ''), isNull);
    expect(validate(ListingStatus.draft, ''), isNull);
    for (final status in [
      ListingStatus.hidden,
      ListingStatus.published,
      ListingStatus.archived,
    ]) {
      expect(validate(status, ''), isNotNull);
      expect(validate(status, '0'), isNotNull);
      expect(validate(status, '1'), isNull);
    }
  });
  test(
    'Khôi phục command giữ key và revisions; hide không gửi field nội dung',
    () {
      const command = ListingCommand(
        action: ListingAction.publish,
        materialId: 'm',
        listingId: 'l',
        expectedRevision: 3,
        expectedMaterialRevision: 7,
        offerType: OfferType.sell,
        askingPriceVnd: 123456,
        idempotencyKey: 'key',
      );
      expect(ListingCommand.fromRpc(command.toRpc()).toRpc(), command.toRpc());
      expect(
        const ListingCommand(
          action: ListingAction.hide,
          materialId: 'm',
          idempotencyKey: 'k',
        ).toRpc()['p_payload'],
        isEmpty,
      );
    },
  );
  test(
    'Nháp tách theo account, giữ được lệnh đang chờ sau tạo lại store wrapper',
    () async {
      final store = _MemoryStore();
      final a = ListingDrafts(store);
      await a.save('A', 'm', {
        'pending': {'key': 'one'},
        'description': 'riêng tư',
      });
      expect(await a.all('B'), isEmpty);
      expect(
        (await ListingDrafts(store).read('A', 'm'))?['description'],
        'riêng tư',
      );
      await a.remove('A', 'm');
      expect(await a.all('A'), isEmpty);
    },
  );
}

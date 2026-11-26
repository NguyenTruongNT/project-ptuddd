import 'dart:convert';

import '../../../core/contracts/domain_enums.dart';

class ListingValidation {
  static final _maxPrice = BigInt.parse('9223372036854775807');
  // Chỉ nhận chữ số nguyên VND: không tự bỏ dấu chấm/phẩy hoặc làm tròn giá.
  // So bằng BigInt trước khi đổi kiểu để chặn tràn giới hạn bigint của PostgreSQL.
  static int? price(String raw) {
    final v = raw.trim();
    if (!RegExp(r'^[0-9]+$').hasMatch(v)) return null;
    final parsed = BigInt.tryParse(v);
    if (parsed == null || parsed <= BigInt.zero || parsed > _maxPrice) {
      return null;
    }
    final value = parsed.toInt();
    // Dart biên dịch JavaScript có thể làm tròn số nguyên lớn. Chỉ gửi khi số
    // trong JSON vẫn đúng từng chữ số; không để giá người dùng bị đổi âm thầm.
    if (BigInt.tryParse(jsonEncode(value)) != parsed) return null;
    return value;
  }

  static bool text(String raw, int max) =>
      // Đếm Unicode theo code point như char_length phía SQL, vẫn cho xuống dòng.
      raw.trim().runes.length <= max &&
      !RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]').hasMatch(raw);
  static String? validate({
    required OfferType? offer,
    required String priceText,
    required String description,
    required String meetingArea,
    required bool publish,
    ListingStatus? currentStatus,
  }) {
    if (offer == null) return 'Chọn một hình thức đăng tin.';
    if (offer == OfferType.sell) {
      // Nút lưu nháp trên tin HIDDEN vẫn giữ HIDDEN, không chuyển về DRAFT.
      // Chỉ tin mới/DRAFT được để trống giá; lưu local không gọi validation server này.
      final requiresPrice =
          publish ||
          (currentStatus != null && currentStatus != ListingStatus.draft);
      if ((requiresPrice || priceText.trim().isNotEmpty) &&
          price(priceText) == null) {
        return 'Giá bán phải là số nguyên VND lớn hơn 0 và trong giới hạn cho phép.';
      }
    } else if (priceText.trim().isNotEmpty) {
      return 'Tin cho mượn/tặng không có giá bán.';
    }
    if (!text(description, 2000)) {
      return 'Mô tả tối đa 2.000 ký tự, không có ký tự điều khiển.';
    }
    if (!text(meetingArea, 200)) {
      return 'Khu vực hẹn tối đa 200 ký tự, không có ký tự điều khiển.';
    }
    return null;
  }
}

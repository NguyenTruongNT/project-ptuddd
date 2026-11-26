import 'package:studyshare/features/listings/domain/listing_validation.dart';

// Chạy bản JavaScript thật để kiểm tra giới hạn số của Chrome, không dùng VM
// thay thế vì VM biểu diễn được đầy đủ bigint 64-bit của Android.
void main() {
  const javascript = bool.fromEnvironment('dart.library.js_interop');
  if (!javascript) throw StateError('Can bien dich bang dart compile js.');
  for (final raw in ['1', '100000', '9007199254740991']) {
    if (ListingValidation.price(raw)?.toString() != raw) {
      throw StateError('Gia hop le bi thay doi: $raw');
    }
  }
  for (final raw in ['9007199254740993', '9223372036854775807', '1.5', '0']) {
    if (ListingValidation.price(raw) != null) {
      throw StateError('Gia khong an toan da duoc nhan: $raw');
    }
  }
  // Đây là tiện ích CLI; stdout là kết quả để script kiểm tra, không là log ứng dụng.
  // ignore: avoid_print
  print('PASS listing price JavaScript');
}

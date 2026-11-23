import 'dart:math';

// Mỗi ý định thao tác của người dùng có MỘT idempotency key.
// Retry sau timeout/mất mạng dùng lại đúng key để server không ghi trùng.
String newIdempotencyKey([Random? random]) {
  final source = random ?? Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < 16; i++) {
    buffer.write(source.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

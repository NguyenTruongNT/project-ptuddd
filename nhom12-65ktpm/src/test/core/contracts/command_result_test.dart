import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/contracts/command_result.dart';
import 'package:studyshare/core/errors/app_error.dart';

void main() {
  test('Kết quả thành công lưu event ID do server xác nhận', () {
    const result = CommandOk<String>('txn-borrow-01', 'evt-server-01');
    expect(result.data, 'txn-borrow-01');
    expect(result.serverEventId, 'evt-server-01');
  });

  test('QR mismatch có mã lỗi riêng, không chuyển thành success', () {
    const result = CommandError<bool>(
      DomainErrorCode.qrMismatch, 'Mã QR không trùng với tài liệu.',
    );
    expect(result.code.wire, 'QR_MISMATCH');
  });

  test('Phân biệt lỗi timeout chưa rõ ACK', () {
    expect(DomainErrorCode.timeoutUnknown.wire, 'TIMEOUT_UNKNOWN');
  });
}

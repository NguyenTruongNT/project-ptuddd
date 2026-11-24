import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/app/app_routes.dart';
import 'package:studyshare/app/auth_redirect.dart';
import 'package:studyshare/core/auth/auth_repository.dart';

void main() {
  const signedIn = AuthSnapshot.signedIn(AuthIdentity(id: 'a'));
  test('Chỉ khôi phục đường dẫn nội bộ đã biết, không giữ token/query', () {
    for (final path in [
      'https://evil.test/profile',
      '//evil.test',
      '/login',
      '/dev/mock',
      '/unknown',
      '/auth/reset-password',
      '/home/../profile',
      '/\\evil.test',
    ]) {
      expect(safeAuthDestination(path), AppRoutes.home, reason: path);
    }
    expect(
      safeAuthDestination('/transactions/txn-1?access_token=secret#token'),
      '/transactions/txn-1',
    );
    expect(safeAuthDestination('/materials'), '/materials');
  });
  test('Người chưa login bị chuyển tới login và giữ đúng đích', () {
    final redirect = authRedirect(
      location: Uri.parse('/transactions/txn-1'),
      session: const AuthSnapshot.signedOut(),
      loading: false,
      demo: false,
    )!;
    final uri = Uri.parse(redirect);
    expect(uri.path, '/login');
    expect(uri.queryParameters['from'], '/transactions/txn-1');
  });
  test('Sau login quay lại đích hợp lệ, bỏ external redirect', () {
    expect(
      authRedirect(
        location: Uri.parse('/login?from=%2Fmaterials'),
        session: signedIn,
        loading: false,
        demo: false,
      ),
      '/materials',
    );
    expect(
      authRedirect(
        location: Uri.parse('/login?from=https://evil.test'),
        session: signedIn,
        loading: false,
        demo: false,
      ),
      '/home',
    );
  });
  test('Query recovery giả không mở được form đổi mật khẩu', () {
    expect(
      authRedirect(
        location: Uri.parse('/auth/reset-password?type=recovery'),
        session: const AuthSnapshot.signedOut(),
        loading: false,
        demo: false,
      ),
      startsWith('/login'),
    );
    expect(
      authRedirect(
        location: Uri.parse('/auth/reset-password'),
        session: signedIn,
        loading: false,
        demo: false,
      ),
      '/home',
    );
  });
  test(
    'Recovery đã xác thực buộc hoàn thành trước khi vào nội dung riêng tư',
    () {
      const recovery = AuthSnapshot.signedIn(
        AuthIdentity(id: 'a'),
        recovering: true,
      );
      expect(
        authRedirect(
          location: Uri.parse('/materials'),
          session: recovery,
          loading: false,
          demo: false,
        ),
        '/auth/reset-password',
      );
      expect(
        authRedirect(
          location: Uri.parse('/auth/reset-password'),
          session: recovery,
          loading: false,
          demo: false,
        ),
        isNull,
      );
    },
  );
  test('Demo không vượt qua guard của backend thật', () {
    expect(
      authRedirect(
        location: Uri.parse('/materials'),
        session: const AuthSnapshot.signedOut(),
        loading: false,
        demo: true,
      ),
      startsWith('/login'),
    );
    expect(
      authRedirect(
        location: Uri.parse('/materials'),
        session: const AuthSnapshot.unconfigured(),
        loading: false,
        demo: true,
      ),
      isNull,
    );
  });
  test('Đang kiểm tra session chỉ hiển thị splash', () {
    expect(
      authRedirect(
        location: Uri.parse('/materials'),
        session: null,
        loading: true,
        demo: false,
      ),
      startsWith('/splash'),
    );
  });
}

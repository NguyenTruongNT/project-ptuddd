import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:studyshare/app/app_router.dart';
import 'package:studyshare/app/studyshare_app.dart';
import 'package:studyshare/core/auth/auth_repository.dart';
import 'package:studyshare/core/auth/auth_session_providers.dart';
import 'package:studyshare/core/providers/mock_query_providers.dart';

import '../../support/fake_auth_repository.dart';

Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> start(
  WidgetTester tester,
  FakeAuthRepository auth,
  FakeProfileRepository profiles,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
      child: const StudyShareApp(),
    ),
  );
  await frames(tester);
}

Future<void> submit(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('auth-submit'));
  await tester.pump();
  await tester.ensureVisible(button);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(button);
  await frames(tester);
}

void main() {
  testWidgets('Đăng ký chặn mật khẩu thiếu từng điều kiện trước confirm/API', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.close);
    await start(tester, auth, FakeProfileRepository());
    await tester.ensureVisible(find.text('Tạo tài khoản'));
    await tester.tap(find.text('Tạo tài khoản'));
    await frames(tester);
    await tester.enterText(find.byKey(const ValueKey('auth-name')), 'Trường');
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'truong@example.test',
    );
    for (final password in [
      'abc123!@',
      'ABC123!@',
      'Abcdef!@',
      'Abcdef12',
      'Aa1!',
    ]) {
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        password,
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirmation')),
        password,
      );
      await submit(tester);
      expect(auth.registerCalls, 0);
      expect(find.byKey(const ValueKey('study-confirm')), findsNothing);
      expect(find.textContaining('Mật khẩu còn thiếu:'), findsOneWidget);
    }
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'StrongPassword123!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirmation')),
      'StrongPassword123!',
    );
    await submit(tester);
    expect(find.byKey(const ValueKey('study-confirm')), findsOneWidget);
    expect(auth.registerCalls, 0);
    await tester.tap(find.byKey(const ValueKey('confirm-action')));
    await frames(tester);
    expect(auth.registerCalls, 1);
  });
  testWidgets('Đặt lại mật khẩu áp dụng cùng policy, không gọi API khi sai', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.close);
    auth.snapshot = const AuthSnapshot.signedIn(
      AuthIdentity(id: 'qa'),
      recovering: true,
    );
    await start(tester, auth, FakeProfileRepository());
    for (final password in [
      'abc123!@',
      'ABC123!@',
      'Abcdef!@',
      'Abcdef12',
      'Aa1!',
    ]) {
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        password,
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirmation')),
        password,
      );
      await submit(tester);
      expect(auth.recoveryCalls, 0);
      expect(find.byKey(const ValueKey('study-confirm')), findsNothing);
      expect(find.textContaining('Mật khẩu còn thiếu:'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Hủy đăng ký không gọi API và giữ nội dung form', (tester) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.close);
    await start(tester, auth, FakeProfileRepository());
    await tester.ensureVisible(find.text('Tạo tài khoản'));
    await tester.tap(find.text('Tạo tài khoản'));
    await frames(tester);
    await tester.enterText(find.byKey(const ValueKey('auth-name')), 'Trường');
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'a@example.test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'Test-pass-123!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirmation')),
      'Test-pass-123!',
    );
    await submit(tester);
    await tester.tap(find.text('Hủy'));
    await frames(tester);
    expect(auth.registerCalls, 0);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('auth-password')))
          .controller!
          .text,
      'Test-pass-123!',
    );
  });

  testWidgets(
    'Hồ sơ không lưu khi chưa sửa; bỏ bản nháp không gọi repository',
    (tester) async {
      final auth = FakeAuthRepository();
      final profiles = FakeProfileRepository();
      addTearDown(auth.close);
      auth.snapshot = const AuthSnapshot.signedIn(
        AuthIdentity(id: 'user-a', displayName: 'Tên cũ'),
      );
      await start(tester, auth, profiles);
      await tester.tap(find.text('Cá nhân').first);
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('profile-edit')));
      await frames(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('profile-save')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('profile-name')),
        'Nháp',
      );
      await frames(tester);
      await tester.tap(find.text('Hủy'));
      await frames(tester);
      expect(find.text('Bỏ thay đổi chưa lưu?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-action')));
      await frames(tester);
      expect(profiles.updateCalls, 0);
      expect(find.text('Tên cũ'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-edit-dialog')), findsNothing);
    },
  );

  testWidgets(
    'Hoàn tất request sau khi đóng form không dùng controller đã dispose',
    (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.close);
      await start(tester, auth, FakeProfileRepository());
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        'a@example.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        'Test-pass-123!',
      );
      auth.loginPending = Completer<void>();
      await submit(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.loginPending!.complete();
      await frames(tester);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Chưa cấu hình: không giả login, chỉ mở demo sau lựa chọn tường minh',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: StudyShareApp()));
      await frames(tester);
      expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
      expect(find.text('Khám phá'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Xem bản demo'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('Xem bản demo'));
      await frames(tester);
      expect(find.text('Khám phá'), findsOneWidget);
      expect(find.textContaining('Bản demo:'), findsOneWidget);
    },
  );

  testWidgets('Validation và chống bấm lặp; lỗi server không lộ nội dung thô', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.close);
    await start(tester, auth, FakeProfileRepository());
    await submit(tester);
    expect(auth.loginCalls, 0);
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      ' a@example.test ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'secret-test-password',
    );
    auth.loginPending = Completer<void>();
    auth.loginError = const AuthException(
      'sensitive server details',
      code: 'invalid_credentials',
    );
    await submit(tester);
    await submit(tester);
    expect(auth.loginCalls, 1);
    auth.loginPending!.complete();
    await frames(tester);
    expect(find.text('Email hoặc mật khẩu không hợp lệ.'), findsOneWidget);
    expect(find.textContaining('sensitive server details'), findsNothing);
    expect(auth.submittedEmail, 'a@example.test');
  });

  testWidgets('Signup cần xác minh không tự coi là đã login', (tester) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.close);
    await start(tester, auth, FakeProfileRepository());
    await tester.ensureVisible(find.text('Tạo tài khoản'));
    await tester.tap(find.text('Tạo tài khoản'));
    await frames(tester);
    await tester.enterText(find.byKey(const ValueKey('auth-name')), ' Trường ');
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'a@example.test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'Test-pass-123!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirmation')),
      'wrong',
    );
    await submit(tester);
    expect(auth.registerCalls, 0);
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirmation')),
      'Test-pass-123!',
    );
    await submit(tester);
    expect(auth.registerCalls, 0);
    await tester.tap(find.byKey(const ValueKey('confirm-action')));
    await frames(tester);
    expect(auth.registerCalls, 1);
    expect(auth.submittedName, 'Trường');
    expect(find.text('Kiểm tra email'), findsOneWidget);
    expect(auth.snapshot.isAuthenticated, isFalse);
  });

  testWidgets(
    'Quên mật khẩu trả thông báo trung lập và chặn gửi lại liên tục',
    (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.close);
      await start(tester, auth, FakeProfileRepository());
      await tester.ensureVisible(find.text('Quên mật khẩu?'));
      await tester.tap(find.text('Quên mật khẩu?'));
      await frames(tester);
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        'unknown@example.test',
      );
      await submit(tester);
      expect(find.textContaining('Nếu email đủ điều kiện'), findsWidgets);
      await submit(tester);
      expect(auth.resetCalls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Đổi user/logout xóa cache, không hiển thị profile người trước', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final profiles = FakeProfileRepository();
    addTearDown(auth.close);
    auth.snapshot = const AuthSnapshot.signedIn(
      AuthIdentity(id: 'user-a', displayName: 'Người A'),
    );
    await start(tester, auth, profiles);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(StudyShareApp)),
    );
    final storeA = container.read(mockTransactionStoreProvider);
    await tester.tap(find.text('Cá nhân').first);
    await frames(tester);
    expect(find.text('Người A'), findsWidgets);
    auth.emit(
      const AuthSnapshot.signedIn(
        AuthIdentity(id: 'user-b', displayName: 'Người B'),
      ),
    );
    await frames(tester);
    expect(find.text('Người A'), findsNothing);
    expect(find.text('Người B'), findsWidgets);
    expect(
      identical(storeA, container.read(mockTransactionStoreProvider)),
      isFalse,
    );
    auth.emit(const AuthSnapshot.signedOut());
    await frames(tester);
    expect(find.text('Người B'), findsNothing);
    expect(container.read(currentProfileProvider).asData?.value, isNull);
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/login',
    );
  });

  testWidgets('Lưu profile đợi repository; logout yêu cầu xác nhận', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    final profiles = FakeProfileRepository();
    addTearDown(auth.close);
    auth.snapshot = const AuthSnapshot.signedIn(
      AuthIdentity(id: 'user-a', displayName: 'Tên cũ'),
    );
    await start(tester, auth, profiles);
    await tester.tap(find.text('Cá nhân').first);
    await frames(tester);
    await tester.tap(find.byKey(const ValueKey('profile-edit')));
    await frames(tester);
    await tester.enterText(
      find.byKey(const ValueKey('profile-name')),
      'Tên mới',
    );
    await frames(tester);
    await tester.tap(find.text('Lưu thay đổi'));
    await frames(tester);
    expect(profiles.updateCalls, 0);
    await tester.tap(find.byKey(const ValueKey('confirm-action')));
    await frames(tester);
    expect(profiles.names['user-a'], 'Tên mới');
    await tester.pump(const Duration(seconds: 4));
    await frames(tester);
    final logout = find.text('Đăng xuất').first;
    await tester.ensureVisible(logout);
    await tester.pump();
    await tester.tap(logout);
    await frames(tester);
    expect(auth.signOutCalls, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
    await frames(tester);
    expect(auth.signOutCalls, 1);
    expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
  });

  testWidgets(
    'Recovery đã xác thực mở form riêng và đăng xuất sau đổi mật khẩu',
    (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.close);
      auth.snapshot = const AuthSnapshot.signedIn(
        AuthIdentity(id: 'a'),
        recovering: true,
      );
      await start(tester, auth, FakeProfileRepository());
      expect(find.text('Đặt mật khẩu mới'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        'New-test-pass-123!',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirmation')),
        'New-test-pass-123!',
      );
      await submit(tester);
      expect(auth.recoveryCalls, 0);
      await tester.tap(find.byKey(const ValueKey('confirm-action')));
      await frames(tester);
      expect(auth.recoveryCalls, 1);
      expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
    },
  );
}

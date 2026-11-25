import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/app/studyshare_app.dart';
import 'package:studyshare/core/auth/auth_session_providers.dart';

void main() {
  testWidgets('StudyShare shows five tabs in Vietnamese', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoModeProvider.overrideWith(
            () => DemoModeController(initial: true),
          ),
        ],
        child: const StudyShareApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Trang chủ'), findsWidgets);
    expect(find.text('Khám phá'), findsOneWidget);
    expect(find.text('Đăng tin'), findsOneWidget);
    expect(find.text('Giao dịch'), findsOneWidget);
    expect(find.text('Cá nhân'), findsOneWidget);
  });
}

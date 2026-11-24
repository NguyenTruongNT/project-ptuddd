import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/app/studyshare_app.dart';
import 'package:studyshare/core/auth/auth_session_providers.dart';

void main() {
  testWidgets('Có thể mở danh mục route từ tab Cá nhân', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Cá nhân').first);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Danh mục 26 màn hình (demo)'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('SCR-01'), findsWidgets);
    expect(find.textContaining('SCR-02'), findsWidgets);
  });
}

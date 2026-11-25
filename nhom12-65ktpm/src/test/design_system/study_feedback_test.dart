import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/design_system/widgets/study_confirm.dart';
import 'package:studyshare/design_system/widgets/study_feedback.dart';
import 'package:studyshare/l10n/app_localizations.dart';

void main() {
  testWidgets('Toast thay thế timer cũ, tự đóng sau 3,5s và đóng sớm được', (
    tester,
  ) async {
    late BuildContext page;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => StudyFeedbackHost(child: child!),
        home: Builder(
          builder: (context) {
            page = context;
            return const Scaffold(body: Text('Page'));
          },
        ),
      ),
    );
    final feedback = StudyFeedbackHost.of(page)!;
    feedback.show('First');
    await tester.pump(const Duration(seconds: 2));
    feedback.show('Second');
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1499));
    expect(find.text('Second'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const ValueKey('study-toast')), findsNothing);
    feedback.show('Third');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('toast-close')));
    await tester.pump();
    expect(find.text('Third'), findsNothing);
  });

  testWidgets('Confirm không thực hiện hành động khi Hủy', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showStudyConfirm(
                  context,
                  title: 'Xác nhận',
                  message: 'Lưu dữ liệu?',
                  confirmLabel: 'Lưu',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/app/studyshare_app.dart';

void main() {
  testWidgets('Five-tab navigation renders', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StudyShareApp()));
    await tester.pump();
    expect(find.text('Trang chủ'), findsWidgets);
    expect(find.text('Khám phá'), findsOneWidget);
    expect(find.text('Đăng tin'), findsOneWidget);
    expect(find.text('Giao dịch'), findsOneWidget);
    expect(find.text('Cá nhân'), findsOneWidget);
  });
}

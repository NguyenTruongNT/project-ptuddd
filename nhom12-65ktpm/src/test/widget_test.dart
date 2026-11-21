import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/app/studyshare_app.dart';

void main() {
  testWidgets('StudyShare foundation opens', (tester) async {
    await tester.pumpWidget(const StudyShareApp());
    expect(find.text('StudyShare'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/design_system/widgets/study_empty.dart';
import 'package:studyshare/design_system/widgets/study_error.dart';
import 'package:studyshare/design_system/widgets/study_loading.dart';

void main() {
  testWidgets('Loading có vòng chờ', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: StudyLoading(),
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Empty hiển thị lời nhắn', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: StudyEmpty(message: 'Không có sách'),
    )));
    expect(find.text('Không có sách'), findsOneWidget);
  });

  testWidgets('Error cho phép bấm Thử lại', (tester) async {
    var retryCount = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: StudyError(onRetry: () => retryCount++),
    )));
    await tester.tap(find.text('Thử lại'));
    expect(retryCount, 1);
  });
}

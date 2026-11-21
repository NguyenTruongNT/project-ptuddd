import 'package:flutter/material.dart';

import '../design_system/theme/studyshare_theme.dart';

class StudyShareApp extends StatelessWidget {
  const StudyShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StudyShare',
      theme: StudyShareTheme.build(Brightness.light),
      darkTheme: StudyShareTheme.build(Brightness.dark),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_rounded, size: 64),
              SizedBox(height: 16),
              Text('StudyShare', style: TextStyle(fontSize: 28)),
              SizedBox(height: 8),
              Text('Flutter foundation – giao diện khởi tạo'),
            ],
          ),
        ),
      ),
    );
  }
}

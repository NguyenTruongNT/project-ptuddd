import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/theme/studyshare_theme.dart';
import 'app_router.dart';

class StudyShareApp extends ConsumerWidget {
  const StudyShareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'StudyShare',
      theme: StudyShareTheme.build(Brightness.light),
      darkTheme: StudyShareTheme.build(Brightness.dark),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

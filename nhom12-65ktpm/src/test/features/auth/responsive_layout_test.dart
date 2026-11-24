import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/auth/auth_repository.dart';
import 'package:studyshare/core/auth/auth_session_providers.dart';
import 'package:studyshare/design_system/theme/studyshare_theme.dart';
import 'package:studyshare/design_system/widgets/study_feedback.dart';
import 'package:studyshare/features/auth/presentation/auth_form_page.dart';
import 'package:studyshare/features/profile_settings/profile_page.dart';
import 'package:studyshare/features/profile_settings/settings_page.dart';
import 'package:studyshare/l10n/app_localizations.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  for (final scenario in [
    (360.0, 800.0, 'vi', Brightness.light, 1.0),
    (440.0, 956.0, 'vi', Brightness.light, 1.0),
    (360.0, 800.0, 'en', Brightness.dark, 2.0),
    (1440.0, 1000.0, 'en', Brightness.light, 1.0),
  ]) {
    testWidgets(
      'Bố cục ${scenario.$1} ${scenario.$3} ${scenario.$4} chữ ${scenario.$5}',
      (tester) async {
        tester.view.physicalSize = Size(scenario.$1, scenario.$2);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = FakeAuthRepository();
        addTearDown(auth.close);
        auth.snapshot = const AuthSnapshot.signedIn(
          AuthIdentity(
            id: 'qa',
            displayName: 'Nguyễn Văn Trường',
            email: 'truong@example.com',
          ),
        );
        for (final page in <Widget>[
          const AuthFormPage(flow: AuthFlow.signIn),
          const AuthFormPage(flow: AuthFlow.signUp),
          const AuthFormPage(flow: AuthFlow.forgotPassword),
          const ProfilePage(),
          const SettingsPage(),
        ]) {
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                authRepositoryProvider.overrideWithValue(auth),
                profileRepositoryProvider.overrideWithValue(
                  FakeProfileRepository(),
                ),
              ],
              child: MaterialApp(
                theme: StudyShareTheme.build(scenario.$4),
                locale: Locale(scenario.$3),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scenario.$5)),
                  child: StudyFeedbackHost(child: child!),
                ),
                home: page,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: page.runtimeType.toString(),
          );
          if (page is ProfilePage) {
            await tester.ensureVisible(
              find.byKey(const ValueKey('profile-edit')),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('profile-edit')));
            await tester.pumpAndSettle();
            tester.view.viewInsets = const FakeViewPadding(bottom: 280);
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'Profile dialog + keyboard',
            );
            tester.view.resetViewInsets();
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

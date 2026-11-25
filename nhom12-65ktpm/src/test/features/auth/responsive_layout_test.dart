import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyshare/core/auth/auth_repository.dart';
import 'package:studyshare/core/auth/auth_session_providers.dart';
import 'package:studyshare/design_system/theme/studyshare_theme.dart';
import 'package:studyshare/design_system/widgets/study_feedback.dart';
import 'package:studyshare/features/auth/presentation/auth_form_page.dart';
import 'package:studyshare/features/auth/presentation/auth_mobile_body.dart';
import 'package:studyshare/features/profile_settings/profile_page.dart';
import 'package:studyshare/features/profile_settings/settings_page.dart';
import 'package:studyshare/l10n/app_localizations.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  for (final scenario in [
    (320.0, 568.0, 'vi', Brightness.light, 2.0),
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
        addTearDown(tester.view.resetViewInsets);
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
          if (page is AuthFormPage) {
            final mobileLogo = find.image(
              const AssetImage('assets/branding/logo_dark_original.png'),
            );
            final mobileHeader = find
                .ancestor(of: mobileLogo, matching: find.byType(Stack))
                .first;
            var headerHeight = 0.0;
            if (scenario.$1 < 900) {
              expect(find.byType(AuthMobileBody), findsOneWidget);
              expect(mobileLogo, findsOneWidget);
              expect(tester.widget<Image>(mobileLogo).fit, BoxFit.contain);
              headerHeight = tester.getSize(mobileHeader).height;
            }
            expect(
              tester.getSize(find.byKey(const ValueKey('auth-card'))).width,
              lessThanOrEqualTo(460),
            );
            if (page.flow == AuthFlow.signIn &&
                scenario.$1 < 900 &&
                scenario.$5 == 1) {
              expect(
                tester
                    .getBottomRight(find.byKey(const ValueKey('auth-submit')))
                    .dy,
                lessThan(scenario.$2),
                reason: 'CTA available without scrolling on mobile',
              );
            }
            if ((page.flow == AuthFlow.signIn ||
                    page.flow == AuthFlow.signUp) &&
                scenario.$1 < 900) {
              tester.view.viewInsets = const FakeViewPadding(bottom: 280);
              await tester.pumpAndSettle();
              expect(mobileLogo, findsOneWidget);
              expect(
                tester.getSize(mobileHeader).height,
                scenario.$2 >= 700 && scenario.$5 == 1
                    ? lessThan(headerHeight)
                    : lessThanOrEqualTo(headerHeight),
                reason: 'Logo header compacts when the keyboard opens',
              );
              await tester.ensureVisible(
                find.byKey(const ValueKey('auth-submit'), skipOffstage: false),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              tester.view.resetViewInsets();
              await tester.pumpAndSettle();
            }
            for (final provider in ['google', 'github']) {
              final button = find.byKey(ValueKey('auth-oauth-$provider'));
              if (page.flow == AuthFlow.signIn ||
                  page.flow == AuthFlow.signUp) {
                await tester.ensureVisible(button);
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
              } else {
                expect(button, findsNothing);
              }
            }
          }
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

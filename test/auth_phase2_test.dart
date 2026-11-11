import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:scrapwise/app/router.dart';
import 'package:scrapwise/core/theme/app_theme.dart';
import 'package:scrapwise/features/auth/screens/change_mobile_screen.dart';
import 'package:scrapwise/features/auth/screens/login_screen.dart';
import 'package:scrapwise/features/auth/screens/register_screen.dart';
import 'package:scrapwise/features/auth/screens/trader_application_screen.dart';
import 'package:scrapwise/features/onboarding/screens/landing_screen.dart';
import 'package:scrapwise/l10n/app_localizations.dart';

Widget _wrap(Widget screen) => MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: screen,
    );

Widget _wrapRouter(GoRouter router) => MaterialApp.router(
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );

void main() {
  testWidgets(
    'landing shows household entry points without public role links',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const LandingScreen()));

      expect(find.byIcon(Icons.recycling_rounded), findsOneWidget);
      expect(find.text('Welcome to'), findsOneWidget);
      expect(find.text('ScrapWise'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);

      expect(
        find.textContaining('Only Household users'),
        findsOneWidget,
      );

      expect(
        find.text('Have a collector invitation?'),
        findsNothing,
      );

      expect(
        find.text('Apply as a trader'),
        findsNothing,
      );

      expect(
        tester.getSize(find.byType(ElevatedButton)).width,
        lessThanOrEqualTo(480),
      );
    },
  );

  testWidgets(
    'universal login has no public collector or trader links',
    (tester) async {
      await tester.pumpWidget(_wrap(const LoginScreen()));

      expect(find.text('Mobile Number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      expect(
        find.text('Have a collector invitation?'),
        findsNothing,
      );

      expect(
        find.text('Apply as a trader'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'household registration asks for required details only',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const RegisterScreen()));

      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Mobile Number'), findsOneWidget);
      expect(find.text('Locality'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);

      expect(find.text('Full pickup address'), findsNothing);
      expect(find.text('Estimated scrap weight'), findsNothing);
    },
  );

  testWidgets(
    'household registration validates its required fields',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(const RegisterScreen()));

      await tester.tap(find.text('Create Account').last);
      await tester.pump();

      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(find.text('Please enter your mobile number'), findsOneWidget);
      expect(find.text('Please enter your locality'), findsOneWidget);
    },
  );

  testWidgets(
    'login exposes a loading state without changing login behavior',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const LoginScreen(isLoading: true)),
      );

      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
      );

      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'login links to the password recovery screen',
    (tester) async {
      final router = createAppRouter(initialLocation: '/login');
      addTearDown(router.dispose);

      await tester.pumpWidget(_wrapRouter(router));

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(
        find.text('Reset your password'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'password recovery OTP remains unavailable without integration',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final router = createAppRouter(
        initialLocation: '/forgot-password',
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(_wrapRouter(router));

      // Enter a valid mobile number.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mobile Number'),
        '9876543210',
      );

      // Navigate to password recovery OTP screen.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(
        find.text('Reset your password'),
        findsOneWidget,
      );

      // Recovery OTP is not integrated yet.
      expect(
        find.text(
          'This verification workflow is not integrated yet.',
        ),
        findsOneWidget,
      );

      // Enter a six-digit OTP.
      await tester.enterText(
        find.byType(TextFormField).last,
        '123456',
      );

      await tester.tap(find.text('Verify code'));
      await tester.pump();

      // Unsupported recovery verification must fail closed.
      expect(
        find.text(
          'This verification workflow is not connected yet.',
        ),
        findsOneWidget,
      );

      // The app must not claim verification succeeded.
      expect(
        find.text('Mobile number verified successfully.'),
        findsNothing,
      );

      expect(
        find.text('Login successful'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'trader application does not grant access or claim submission',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(const TraderApplicationScreen()),
      );

      expect(
        find.textContaining('not granted automatically'),
        findsOneWidget,
      );

      await tester.tap(find.text('Submit application'));
      await tester.pump();

      expect(
        find.text('Please enter your business name'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'mobile change screen is a scaffold and verification is unavailable',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(const ChangeMobileScreen()),
      );

      expect(
        find.text('Change mobile number'),
        findsOneWidget,
      );

      expect(
        find.textContaining('signed-in users'),
        findsOneWidget,
      );
    },
  );
}

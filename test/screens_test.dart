import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapwise/core/theme/app_theme.dart';
import 'package:scrapwise/features/onboarding/screens/landing_screen.dart';
import 'package:scrapwise/features/onboarding/screens/language_selection_screen.dart';
import 'package:scrapwise/features/onboarding/screens/splash_screen.dart';
import 'package:scrapwise/features/auth/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _testScreen(Widget screen) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      home: screen,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SplashScreen', () {
    testWidgets('renders app branding and tagline', (tester) async {
      await tester.pumpWidget(_testScreen(const SplashScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('ScrapWise'), findsOneWidget);
      expect(find.text('Smart Scrap. Cleaner Future.'), findsOneWidget);

      // Drain timer so test completes cleanly
      await tester.pump(const Duration(milliseconds: 3000));
    });
  });

  group('LandingScreen', () {
    testWidgets('renders branding, Sign In and Create Account buttons',
        (tester) async {
      await tester.pumpWidget(_testScreen(const LandingScreen()));
      await tester.pump();

      expect(find.text('ScrapWise'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });
  });

  group('LanguageSelectionScreen', () {
    testWidgets('displays supported languages', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_testScreen(const LanguageSelectionScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Select Your Language'), findsOneWidget);
      expect(find.text('English'), findsWidgets);
      expect(find.text('हिन्दी'), findsOneWidget);
      expect(find.text('ಕನ್ನಡ'), findsOneWidget);
      expect(find.text('తెలుగు'), findsOneWidget);
      expect(find.text('اردو'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });
  });

  group('LoginScreen', () {
    testWidgets('renders universal login fields', (tester) async {
      await tester.pumpWidget(_testScreen(const LoginScreen()));
      await tester.pump();

      expect(find.text('Sign in to your account'), findsOneWidget);
      expect(find.text('Mobile Number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('shows validation errors when fields are empty', (tester) async {
      await tester.pumpWidget(_testScreen(const LoginScreen()));
      await tester.pump();

      // Tap Sign In button without entering data
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Please enter your mobile number'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('shows pending dialog on valid input submit', (tester) async {
      await tester.pumpWidget(_testScreen(const LoginScreen()));
      await tester.pump();

      // Enter mobile and password
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Mobile Number'), '9876543210');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'secret123');
      await tester.pump();

      // Tap Sign In button
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      // Verify pending auth dialog appears
      expect(find.text('Authentication Pending'), findsOneWidget);
      expect(
          find.textContaining('Backend authentication integration is in progress'),
          findsOneWidget);
    });
  });
}

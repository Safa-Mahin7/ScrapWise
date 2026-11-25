import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:scrapwise/app/router.dart';
import 'package:scrapwise/core/theme/app_theme.dart';
import 'package:scrapwise/features/auth/screens/change_mobile_screen.dart';
import 'package:scrapwise/features/auth/screens/forgot_password_screen.dart';
import 'package:scrapwise/features/auth/screens/login_screen.dart';
import 'package:scrapwise/features/auth/screens/otp_verification_screen.dart';
import 'package:scrapwise/features/auth/screens/register_screen.dart';
import 'package:scrapwise/features/auth/screens/trader_application_screen.dart';
import 'package:scrapwise/features/auth/services/auth_service.dart';
import 'package:scrapwise/features/auth/services/session_controller.dart';
import 'package:scrapwise/features/onboarding/screens/landing_screen.dart';
import 'package:scrapwise/l10n/app_localizations.dart';

class _RecoveryAuthService extends AuthService {
  String? requestedMobile;
  String? resetMobile;
  String? resetPasswordValue;
  DioException? requestError;

  @override
  Future<void> requestPasswordReset({required String mobile}) async {
    if (requestError != null) throw requestError!;
    requestedMobile = mobile;
  }

  @override
  Future<String> verifyPasswordRecoveryOtp({
    required String mobile,
    required String code,
  }) async =>
      'mock-reset-grant';

  @override
  Future<void> resetPassword({
    required String mobile,
    required String resetToken,
    required String newPassword,
  }) async {
    resetMobile = mobile;
    resetPasswordValue = newPassword;
  }

  @override
  Future<void> clearLocalSession() async {}
}

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
    'registration OTP resend stays disabled during the cooldown',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const OtpVerificationScreen(
            purpose: OtpPurpose.phoneVerification,
            phoneNumber: '9876543210',
          ),
        ),
      );

      expect(find.text('Resend in 60s'), findsOneWidget);
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );

      await tester.pump(const Duration(seconds: 59));
      expect(find.text('Resend in 1s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Resend code'), findsOneWidget);
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'password recovery verifies OTP and submits a reset grant',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final authService = _RecoveryAuthService();
      final session = SessionController(authService: authService);
      addTearDown(session.dispose);
      final router = createAppRouter(
        initialLocation: '/forgot-password',
        authService: authService,
        sessionController: session,
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(_wrapRouter(router));

      // Enter a valid mobile number.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mobile Number'),
        '9876543210',
      );

      // The recovery endpoint returns a generic response before OTP entry.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(authService.requestedMobile, '9876543210');

      expect(
        find.text('Reset your password'),
        findsOneWidget,
      );

      // A test-controlled OTP response returns a single-use reset grant.
      await tester.enterText(
        find.byType(TextFormField).last,
        '123456',
      );

      await tester.tap(find.text('Verify code'));
      await tester.pumpAndSettle();
      expect(find.text('Create a new password'), findsNWidgets(2));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Password'),
        'FreshPassword123!',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm New Password'),
        'FreshPassword123!',
      );
      await tester.tap(find.text('Create a new password').last);
      await tester.pumpAndSettle();

      expect(authService.resetMobile, '9876543210');
      expect(authService.resetPasswordValue, 'FreshPassword123!');
      expect(find.text('Password changed. Sign in with your new password.'),
          findsOneWidget);
    },
  );

  testWidgets('password recovery reports provider rejection without navigating',
      (tester) async {
    final service = _RecoveryAuthService()
      ..requestError = DioException(
        requestOptions: RequestOptions(path: '/api/auth/password/forgot'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/password/forgot'),
          statusCode: 503,
        ),
        type: DioExceptionType.badResponse,
      );
    await tester.pumpWidget(_wrap(
      ForgotPasswordScreen(authService: service),
    ));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mobile Number'),
      '9876543210',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
        find.text('The SMS service is temporarily unavailable. '
            'No verification code was sent.'),
        findsOneWidget);
    expect(find.byType(OtpVerificationScreen), findsNothing);
  });

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
        find.text('Continue with Google'),
        findsOneWidget,
      );
    },
  );
}

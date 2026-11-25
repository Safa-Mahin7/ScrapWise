import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:scrapwise/app/router.dart';
import 'package:scrapwise/core/constants/app_constants.dart';
import 'package:scrapwise/core/theme/app_theme.dart';
import 'package:scrapwise/features/auth/services/auth_service.dart';
import 'package:scrapwise/features/auth/services/session_controller.dart';
import 'package:scrapwise/features/auth/screens/otp_verification_screen.dart';
import 'package:scrapwise/features/auth/screens/change_mobile_screen.dart';
import 'package:scrapwise/features/household/screens/tabs/profile_tab.dart';
import 'package:scrapwise/l10n/app_localizations.dart';

class _UnauthenticatedAuthService extends AuthService {
  @override
  Future<Map<String, dynamic>?> restoreSession() async => null;
}

class _MobileChangeAuthService extends AuthService {
  Map<String, String?>? request;

  @override
  Future<Map<String, dynamic>?> restoreSession() async => {
        'user_id': 'test-household',
        'full_name': 'Test Household',
        'mobile': '+919876543210',
        'role': 'household',
        'status': 'active',
        'phone_verified': true,
      };

  @override
  Future<void> requestMobileChange({
    required String newMobile,
    String? currentPassword,
    String? googleIdToken,
  }) async {
    request = {
      'new_mobile': newMobile,
      'current_password': currentPassword,
      'google_id_token': googleIdToken,
    };
  }

  @override
  Future<void> clearLocalSession() async {}
}

void main() {
  testWidgets('Household Profile navigates to the change-mobile route',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/profile-test',
      routes: [
        GoRoute(
          path: '/profile-test',
          builder: (context, state) => Scaffold(
            body: ProfileTab(
              user: const {
                'full_name': 'Test Household',
                'mobile': '+919876543210',
                'phone_verified': true,
              },
              onSignOut: () {},
              signingOut: false,
            ),
          ),
        ),
        GoRoute(
          path: AppConstants.routeChangeMobile,
          builder: (context, state) =>
              const Scaffold(body: Text('Change mobile route')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('Change Mobile Number'));
    await tester.pumpAndSettle();
    expect(find.text('Change mobile route'), findsOneWidget);
  });

  testWidgets('unauthenticated users cannot open account mobile settings',
      (tester) async {
    final session = SessionController(
      authService: _UnauthenticatedAuthService(),
    );
    addTearDown(session.dispose);
    await session.restoreSession();

    final router = createAppRouter(
      initialLocation: AppConstants.routeChangeMobile,
      sessionController: session,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in to your account'), findsOneWidget);
    expect(find.text('Change mobile number'), findsNothing);
  });

  testWidgets('mobile change requires reauthentication before OTP navigation',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _MobileChangeAuthService();
    final session = SessionController(authService: service);
    addTearDown(session.dispose);
    await session.restoreSession();

    final router = createAppRouter(
      initialLocation: AppConstants.routeChangeMobile,
      authService: service,
      sessionController: session,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );

    expect(find.byType(ChangeMobileScreen), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New mobile number'),
      '9555555555',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'CurrentPass123!',
    );
    await tester.ensureVisible(find.text('Send verification code'));
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();

    expect(service.request, {
      'new_mobile': '9555555555',
      'current_password': 'CurrentPass123!',
      'google_id_token': null,
    });
    expect(find.byType(OtpVerificationScreen), findsOneWidget);
    expect(find.text('Verification code'), findsOneWidget);
    await session.expireLocalSession();
    await tester.pumpAndSettle();
  });
}

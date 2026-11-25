import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:scrapwise/app/router.dart';
import 'package:scrapwise/core/constants/app_constants.dart';
import 'package:scrapwise/core/theme/app_theme.dart';
import 'package:scrapwise/features/auth/services/auth_service.dart';
import 'package:scrapwise/features/auth/services/google_identity_provider.dart';
import 'package:scrapwise/features/auth/services/session_controller.dart';
import 'package:scrapwise/l10n/app_localizations.dart';

class FakeGoogleIdentityProvider implements GoogleIdentityProvider {
  FakeGoogleIdentityProvider({this.idToken = 'mocked-google-id-token'});

  final String? idToken;
  final StreamController<String> _tokens = StreamController<String>.broadcast();
  final StreamController<Object> _errors = StreamController<Object>.broadcast();

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> authenticate() async => idToken;

  @override
  Stream<String> get idTokens => _tokens.stream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Widget renderWebButton() => const Text('Google web button');
}

class FakeAuthService extends AuthService {
  FakeAuthService({
    this.googleUser = const {
      'user_id': 'google-user',
      'role': 'household',
      'mobile': '+919876543210',
    },
    this.passwordUser = const {
      'user_id': 'password-user',
      'role': 'trader',
      'mobile': '+919888888888',
    },
  });

  final Map<String, dynamic> googleUser;
  final Map<String, dynamic> passwordUser;
  Map<String, dynamic> _currentUser = {};

  String? registeredIdToken;
  String? registeredMobile;
  String? registeredName;
  String? registeredLocality;
  String? loggedInGoogleToken;
  String? linkedGoogleToken;
  String? linkedPassword;

  @override
  Future<void> registerGoogleHousehold({
    required String idToken,
    required String mobile,
    required String fullName,
    required String localityId,
  }) async {
    registeredIdToken = idToken;
    registeredMobile = mobile;
    registeredName = fullName;
    registeredLocality = localityId;
  }

  @override
  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
  }) async {
    loggedInGoogleToken = idToken;
    _currentUser = googleUser;
    return googleUser;
  }

  @override
  Future<Map<String, dynamic>> login({
    required String mobile,
    required String password,
  }) async {
    _currentUser = passwordUser;
    return passwordUser;
  }

  @override
  Future<void> linkGoogleIdentity({
    required String idToken,
    required String password,
  }) async {
    linkedGoogleToken = idToken;
    linkedPassword = password;
  }

  @override
  Future<Map<String, dynamic>> currentUser() async => _currentUser;

  @override
  Future<void> clearLocalSession() async {}
}

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
  testWidgets('Google registration collects a phone before OTP activation',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final service = FakeAuthService();
    final provider = FakeGoogleIdentityProvider();
    final router = createAppRouter(
      initialLocation: '/register',
      authService: service,
      googleIdentityProvider: provider,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _wrapRouter(
        router,
      ),
    );
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(
        find.text(
            'A verified mobile number is required to activate your Household account.'),
        findsOneWidget);
    expect(find.text('Password'), findsNothing);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Google Household',
    );
    await tester.enterText(find.byType(TextFormField).at(1), '9876543210');
    await tester.enterText(find.byType(TextFormField).at(2), 'Cowl Bazar');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(service.registeredIdToken, 'mocked-google-id-token');
    expect(service.registeredMobile, '9876543210');
    expect(service.registeredName, 'Google Household');
    expect(service.registeredLocality, 'Cowl Bazar');
    expect(router.routerDelegate.currentConfiguration.uri.path,
        '/otp/registration');
  });

  testWidgets('Google login routes using the backend role', (tester) async {
    final service = FakeAuthService(
      googleUser: const {
        'user_id': 'google-collector',
        'role': 'collector',
        'mobile': '+919876543210',
      },
    );
    final provider = FakeGoogleIdentityProvider();
    final session = SessionController(authService: service);
    final router = createAppRouter(
      initialLocation: AppConstants.routeLogin,
      sessionController: session,
      googleIdentityProvider: provider,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _wrapRouter(
        router,
      ),
    );
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(service.loggedInGoogleToken, 'mocked-google-id-token');
    expect(session.user?['role'], 'collector');
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppConstants.routeCollectorDashboard,
    );
  });

  testWidgets('cancelled Google login creates no session', (tester) async {
    final service = FakeAuthService();
    final provider = FakeGoogleIdentityProvider(idToken: null);
    final session = SessionController(authService: service);
    final router = createAppRouter(
      initialLocation: AppConstants.routeLogin,
      sessionController: session,
      googleIdentityProvider: provider,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_wrapRouter(router));
    await tester.tap(
      find.text('Continue with Google'),
    );
    await tester.pumpAndSettle();

    expect(service.loggedInGoogleToken, isNull);
    expect(session.isAuthenticated, isFalse);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
    expect(
        find.text('Google sign-in could not be completed. Please try again.'),
        findsNothing);
  });

  testWidgets('Google linking requires password reauthentication',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final service = FakeAuthService();
    final provider = FakeGoogleIdentityProvider();
    final session = SessionController(authService: service);
    await session.signIn(mobile: '9888888888', password: 'TraderPass123!');
    final router = createAppRouter(
      initialLocation: AppConstants.routeLinkGoogle,
      sessionController: session,
      googleIdentityProvider: provider,
    );
    addTearDown(session.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(_wrapRouter(router));
    await tester.enterText(find.byType(TextFormField).at(0), '9888888888');
    await tester.enterText(find.byType(TextFormField).at(1), 'TraderPass123!');
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(service.linkedGoogleToken, 'mocked-google-id-token');
    expect(service.linkedPassword, 'TraderPass123!');
    expect(session.user?['role'], 'trader');
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppConstants.routeTraderDashboard,
    );
  });
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:scrapwise/core/network/api_client.dart';
import 'package:scrapwise/core/theme/app_theme.dart';
import 'package:scrapwise/features/auth/screens/login_screen.dart';
import 'package:scrapwise/features/onboarding/screens/landing_screen.dart';
import 'package:scrapwise/features/onboarding/screens/language_selection_screen.dart';
import 'package:scrapwise/features/onboarding/screens/splash_screen.dart';
import 'package:scrapwise/l10n/app_localizations.dart';

import 'package:scrapwise/features/auth/services/auth_service.dart';
import 'package:scrapwise/features/auth/services/session_controller.dart';
import 'package:scrapwise/features/auth/services/session_store.dart';

Widget _testScreen(Widget screen) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: screen,
    ),
  );
}

class _MemorySessionStore extends SessionStore {
  @override
  Future<void> save(String token) async {}

  @override
  Future<String?> read() async => null;

  @override
  Future<void> clear() async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // --------------------------------------------------
  // SPLASH SCREEN TESTS
  // --------------------------------------------------
  group('SplashScreen', () {
    testWidgets('renders app branding and tagline', (tester) async {
      await tester.pumpWidget(
        _testScreen(const SplashScreen()),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('ScrapWise'), findsOneWidget);
      expect(
        find.text('Smart Scrap. Cleaner Future.'),
        findsOneWidget,
      );

      // Complete the splash screen timer.
      await tester.pump(const Duration(milliseconds: 3000));
    });
  });

  // --------------------------------------------------
  // LANDING SCREEN TESTS
  // --------------------------------------------------
  group('LandingScreen', () {
    testWidgets(
      'renders branding, Sign In and Create Account buttons',
      (tester) async {
        await tester.pumpWidget(
          _testScreen(const LandingScreen()),
        );

        await tester.pump();

        expect(find.text('ScrapWise'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.text('Create Account'), findsOneWidget);
      },
    );
  });

  // --------------------------------------------------
  // LANGUAGE SELECTION SCREEN TESTS
  // --------------------------------------------------
  group('LanguageSelectionScreen', () {
    testWidgets('displays supported languages', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _testScreen(const LanguageSelectionScreen()),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Select Your Language'),
        findsOneWidget,
      );

      expect(find.text('English'), findsWidgets);
      expect(find.text('हिन्दी'), findsOneWidget);
      expect(find.text('ಕನ್ನಡ'), findsOneWidget);
      expect(find.text('తెలుగు'), findsOneWidget);
      expect(find.text('اردو'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });
  });

  // --------------------------------------------------
  // LOGIN SCREEN TESTS
  // --------------------------------------------------
  group('LoginScreen', () {
    // Test 1: Check login screen UI.
    testWidgets('renders universal login fields', (tester) async {
      await tester.pumpWidget(
        _testScreen(const LoginScreen()),
      );

      await tester.pump();

      expect(
        find.text('Sign in to your account'),
        findsOneWidget,
      );

      expect(find.text('Mobile Number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    // Test 2: Check empty-field validation.
    testWidgets(
      'shows validation errors when fields are empty',
      (tester) async {
        await tester.pumpWidget(
          _testScreen(const LoginScreen()),
        );

        await tester.pump();

        await tester.tap(find.text('Sign In'));
        await tester.pump();

        expect(
          find.text('Please enter your mobile number'),
          findsOneWidget,
        );

        expect(
          find.text('Please enter your password'),
          findsOneWidget,
        );
      },
    );

    // Test 3: Verify API login error handling.
    testWidgets(
      'login handles invalid credentials from API',
      (tester) async {
        final dio = ApiClient.instance.dio;

        final testSession = SessionController(
          authService: AuthService(
            dio: dio,
            sessionStore: _MemorySessionStore(),
          ),
        );

        addTearDown(testSession.dispose);

        final requests = <Map<String, dynamic>>[];

        // Mock the authentication endpoint.
        // The test must not contact the real backend.
        final mockInterceptor = InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/api/auth/login') {
              requests.add(
                Map<String, dynamic>.from(options.data as Map),
              );

              // Simulate HTTP 401: Invalid credentials.
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 401,
                    data: {
                      'detail': 'Invalid mobile number or password',
                    },
                  ),
                  type: DioExceptionType.badResponse,
                ),
              );

              return;
            }

            // Reject any unexpected API requests.
            handler.reject(
              DioException(
                requestOptions: options,
                message: 'Unexpected API request during test',
              ),
            );
          },
        );

        // Add the mock before existing interceptors.
        dio.interceptors.insert(0, mockInterceptor);

        // Clean up after the test finishes.
        addTearDown(() {
          dio.interceptors.remove(mockInterceptor);
          dio.options.headers.remove('Authorization');
        });

        await tester.pumpWidget(
          _testScreen(
            LoginScreen(sessionController: testSession),
          ),
        );

        await tester.pump();

        // Enter a valid mobile number.
        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'Mobile Number',
          ),
          '9876543210',
        );

        // Enter a password.
        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'Password',
          ),
          'secret123',
        );

        // Submit the login form.
        await tester.tap(find.text('Sign In'));
        await tester.pumpAndSettle();

        // Verify exactly one login request was made.
        expect(requests, hasLength(1));

        // Verify the submitted request fields.
        expect(
          requests.single['mobile'],
          '9876543210',
        );

        expect(
          requests.single['password'],
          'secret123',
        );

        // Verify the application handles HTTP 401.
        expect(
          find.text(
            'Authentication failed or your session is invalid.',
          ),
          findsOneWidget,
        );

        // An unsuccessful login must not show success.
        expect(
          find.text('Login successful'),
          findsNothing,
        );

        // The outdated pending popup must not appear.
        expect(
          find.text('Authentication Pending'),
          findsNothing,
        );
      },
    );
  });
}

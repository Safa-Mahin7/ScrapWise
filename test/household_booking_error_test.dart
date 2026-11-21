// test/household_booking_error_test.dart
//
// Tests for ScrapWise Phase 3B — Pickup booking error handling.
//
// Verifies:
//   1. HouseholdApiService.createPickupRequest — HTTP 404 → ServiceUnavailableException
//      with the exact required user-facing message.
//   2. HouseholdApiService.createPickupRequest — HTTP 503 → ServiceUnavailableException.
//   3. HouseholdApiService.createPickupRequest — connection error → ServiceUnavailableException
//      (no raw DioException text propagated to callers).
//   4. BookPickupSheet widget — when the API throws ServiceUnavailableException simulating
//      a 404 response, the error banner shows the correct message, the success view is NOT
//      rendered, and the form data (materials, locality, address) are preserved on step 2.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapwise/core/theme/app_theme.dart';
import 'package:scrapwise/features/auth/services/auth_service.dart';
import 'package:scrapwise/features/auth/services/session_controller.dart';
import 'package:scrapwise/features/household/models/locality_model.dart';
import 'package:scrapwise/features/household/models/pickup_booking_model.dart';
import 'package:scrapwise/features/household/screens/booking/book_pickup_sheet.dart';
import 'package:scrapwise/features/household/services/household_api_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _exact404Message =
    'Pickup booking is not available yet. The collection service is still being connected.';

/// Fake AuthService that returns a valid household session so tests can reach
/// the submit step without requiring a real backend.
class _FakeAuthService extends AuthService {
  @override
  Future<Map<String, dynamic>?> restoreSession() async => {
        'user_id': 'user-h-error-test',
        'full_name': 'Error Test Household',
        'mobile': '+919000000000',
        'role': 'household',
        'status': 'active',
        'phone_verified': true,
      };

  @override
  Future<void> logout() async {}
}

/// HouseholdApiService subclass that:
///   - returns the static locality list immediately (no HTTP call).
///   - throws [ServiceUnavailableException] from createPickupRequest,
///     simulating the HTTP-404 path in the real service.
class _Unavailable404ApiService extends HouseholdApiService {
  @override
  Future<List<LocalityModel>> fetchLocalities() async =>
      LocalityModel.verifiedBallariLocalities;

  @override
  Future<PickupBookingResponse> createPickupRequest(
    PickupBookingRequest request,
  ) async {
    throw ServiceUnavailableException(_exact404Message);
  }

  @override
  Future<List<PickupBookingResponse>> fetchPersonalPickups() async => const [];
}

/// Builds a Dio instance whose interceptor rejects every request with a
/// [DioExceptionType.connectionError], simulating a network outage.
Dio _dioWithConnectionError() {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: 'Failed host lookup',
          ),
        );
      },
    ),
  );
  return dio;
}

/// Minimal [PickupBookingRequest] used by unit tests — only the fields that
/// [createPickupRequest] requires.
PickupBookingRequest _minimalRequest() => PickupBookingRequest(
      householdId: 'user-h-error-test',
      localityId: 'cowl_bazar',
      latitude: 15.136,
      longitude: 76.898,
      preferredDate: DateTime(2026, 11, 20),
      preferredTimeSlot: 'morning',
      materials: ['newspaper'],
      address: '1 Test Street',
    );

// ---------------------------------------------------------------------------
// Unit tests — HouseholdApiService error mapping
// ---------------------------------------------------------------------------

void main() {
  group('HouseholdApiService — createPickupRequest error mapping', () {
    test(
        'HTTP 404 → ServiceUnavailableException with exact user-facing message',
        () async {
      // Dio will return HTTP 404; the service wraps it into
      // ServiceUnavailableException with the fixed message.
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 404,
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );

      final service = HouseholdApiService(dio: dio);

      expect(
        () => service.createPickupRequest(_minimalRequest()),
        throwsA(
          isA<ServiceUnavailableException>().having(
            (e) => e.message,
            'message',
            _exact404Message,
          ),
        ),
      );
    });

    test(
        'HTTP 503 → ServiceUnavailableException (temporary unavailable message)',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 503,
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );

      final service = HouseholdApiService(dio: dio);

      expect(
        () => service.createPickupRequest(_minimalRequest()),
        throwsA(
          isA<ServiceUnavailableException>().having(
            (e) => e.message,
            'message',
            contains('temporarily unavailable'),
          ),
        ),
      );
    });

    test(
        'Connection error → ServiceUnavailableException (no raw DioException text)',
        () async {
      final service = HouseholdApiService(dio: _dioWithConnectionError());

      Object? thrown;
      try {
        await service.createPickupRequest(_minimalRequest());
      } catch (e) {
        thrown = e;
      }

      // Must be ServiceUnavailableException, NOT a raw DioException.
      expect(thrown, isA<ServiceUnavailableException>(),
          reason: 'Raw DioException must not propagate to callers');

      // The message must not contain raw technical Dio text.
      final ex = thrown as ServiceUnavailableException;
      expect(ex.message, isNot(contains('DioException')),
          reason: 'User-facing message must not expose DioException class name');
      expect(ex.message, isNot(contains('Failed host lookup')),
          reason: 'User-facing message must not expose low-level network text');
    });

    test(
        'HTTP 401 → ServiceUnavailableException with session-expired message',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 401,
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );

      final service = HouseholdApiService(dio: dio);

      expect(
        () => service.createPickupRequest(_minimalRequest()),
        throwsA(
          isA<ServiceUnavailableException>().having(
            (e) => e.message,
            'message',
            contains('session'),
          ),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Widget tests — BookPickupSheet error display and form-data preservation
  // -------------------------------------------------------------------------

  group('BookPickupSheet — 404 error display and form-data preservation', () {
    late SessionController session;

    setUp(() async {
      session = SessionController(authService: _FakeAuthService());
      await session.restoreSession();
    });

    tearDown(() => session.dispose());

    Widget buildSheet({HouseholdApiService? apiService}) => ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: BookPickupSheet(
                sessionController: session,
                apiService: apiService ?? _Unavailable404ApiService(),
              ),
            ),
          ),
        );

    testWidgets(
        'submitting on step 3 with 404 service shows exact error message '
        'and does NOT render the success view', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      // ── Step 0: Materials ────────────────────────────────────────────────
      // Select "Newspaper" to satisfy the minimum-one-material validation.
      await tester.tap(find.text('Newspaper'));
      await tester.pump();

      // Advance to step 1.
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // ── Step 1: Location ─────────────────────────────────────────────────
      expect(find.text('Locality & Pickup Location'), findsOneWidget);

      // Enter a pickup address.
      await tester.enterText(
        find.byType(TextFormField).first,
        '42 Test Street, Ballari',
      );
      await tester.pump();

      // Confirm GPS location via the "Confirm Accurate Location" button.
      await tester.tap(find.text('Confirm Accurate Location'));
      await tester.pump();

      // Advance to step 2 (Schedule & Review).
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // ── Step 2: Schedule & Review ─────────────────────────────────────────
      expect(find.text('Schedule & Slot'), findsOneWidget);
      expect(find.text('Review Booking Summary'), findsOneWidget);

      // Tap "Confirm & Submit" to trigger the API call.
      await tester.tap(find.text('Confirm & Submit'));
      await tester.pump(); // let _isSubmitting = true render
      await tester.pumpAndSettle(); // let the future complete

      // ── Assertions ────────────────────────────────────────────────────────

      // 1. The exact 404 user-facing message must appear.
      expect(
        find.text(_exact404Message),
        findsOneWidget,
        reason: 'The exact 404 error message must be visible in the error banner',
      );

      // 2. No success view rendered — it contains "Pickup Request Submitted!"
      expect(
        find.text('Pickup Request Submitted!'),
        findsNothing,
        reason: 'Success view must not be shown when submission failed',
      );

      // 3. No DioException text visible anywhere in the widget tree.
      expect(
        find.textContaining('DioException'),
        findsNothing,
        reason: 'Raw DioException must never be shown to household users',
      );

      // 4. The form is still on step 2 (review): the review summary is visible.
      expect(
        find.text('Review Booking Summary'),
        findsOneWidget,
        reason: 'Sheet must remain on step 3 after a failed submission',
      );

      // 5. The "Confirm & Submit" button is still present (re-submit possible
      //    once real backend is integrated — the fix is temporary, not permanent).
      expect(find.text('Confirm & Submit'), findsOneWidget);
    });

    testWidgets(
        'selected material is preserved after a 404 submission error',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      // ── Step 0 ───────────────────────────────────────────────────────────
      expect(find.text('Select materials available for collection'), findsOneWidget);
      await tester.tap(find.text('Newspaper'));
      await tester.pump();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // ── Step 1 ───────────────────────────────────────────────────────────
      expect(find.text('Locality & Pickup Location'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        '7 Heritage Lane',
      );
      await tester.pump();
      await tester.tap(find.text('Confirm Accurate Location'));
      await tester.pump();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // ── Step 2: submit and get 404 ────────────────────────────────────────
      expect(find.text('Review Booking Summary'), findsOneWidget);
      await tester.tap(find.text('Confirm & Submit'));
      await tester.pump();
      await tester.pumpAndSettle();

      // The review summary row for Materials must still show the selection.
      expect(
        find.textContaining('Newspaper'),
        findsWidgets,
        reason: 'Selected materials must still be shown in the review summary '
            'after a failed submission',
      );
      expect(find.text('Cowl Bazar'), findsOneWidget);
      expect(find.text('7 Heritage Lane'), findsOneWidget);
      expect(find.textContaining('(morning)'), findsOneWidget);

      // Error banner still present — form data survived the error.
      expect(find.text(_exact404Message), findsOneWidget);
    });

    testWidgets(
        'successful API response shows success view and not an error banner',
        (tester) async {
      // This test uses a mock API that returns a successful response,
      // verifying the positive path works (real booking not disabled).
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final successDio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
      successDio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/pickups') {
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'request_id': 'req-success-001',
                'household_id': 'user-h-error-test',
                'locality_id': 'cowl_bazar',
                'latitude': 15.136,
                'longitude': 76.898,
                'preferred_date': '2026-11-20',
                'preferred_time_slot': 'morning',
                'materials': ['newspaper'],
                'status': 'pending',
              },
            ));
            return;
          }
          // Localities endpoint: return empty → falls back to static list.
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {'localities': []},
          ));
        },
      ));

      await tester.pumpWidget(
        buildSheet(apiService: HouseholdApiService(dio: successDio)),
      );
      await tester.pumpAndSettle();

      // Step 0
      expect(find.text('Select materials available for collection'), findsOneWidget);
      await tester.tap(find.text('Newspaper'));
      await tester.pump();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 1
      expect(find.text('Locality & Pickup Location'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '1 Success Road');
      await tester.pump();
      await tester.tap(find.text('Confirm Accurate Location'));
      await tester.pump();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2 — submit
      expect(find.text('Review Booking Summary'), findsOneWidget);
      await tester.tap(find.text('Confirm & Submit'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Success view must render.
      expect(find.text('Pickup Request Submitted!'), findsOneWidget,
          reason: 'Real API success must still show the success confirmation');
      expect(find.text('Request ID: req-success-001'), findsOneWidget);

      // No error banner visible.
      expect(find.text(_exact404Message), findsNothing);
    });
  });
}

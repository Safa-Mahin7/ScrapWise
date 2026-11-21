import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapwise/core/theme/app_theme.dart';
import 'package:scrapwise/features/auth/services/auth_service.dart';
import 'package:scrapwise/features/auth/services/session_controller.dart';
import 'package:scrapwise/features/household/models/pickup_booking_model.dart';
import 'package:scrapwise/features/household/models/scrap_material.dart';
import 'package:scrapwise/features/household/screens/booking/book_pickup_sheet.dart';
import 'package:scrapwise/features/household/screens/tabs/ewaste_tab.dart';
import 'package:scrapwise/features/household/services/household_api_service.dart';

class _FakeAuthService extends AuthService {
  @override
  Future<Map<String, dynamic>?> restoreSession() async => {
        'user_id': 'user-h123',
        'full_name': 'Test Household User',
        'mobile': '+919876543210',
        'role': 'household',
        'status': 'active',
        'phone_verified': true,
      };
}

void main() {
  group('PickupBookingRequest Model & API Serialization', () {
    test('serializes materials as a list of strings, never requesting weight', () {
      final request = PickupBookingRequest(
        householdId: 'user-h123',
        localityId: 'cowl_bazar',
        latitude: 15.13649,
        longitude: 76.89829,
        preferredDate: DateTime(2026, 11, 20),
        preferredTimeSlot: 'morning',
        materials: ['newspaper', 'PET_plastic'],
        address: '123 Main Street',
        notes: 'Near temple',
      );

      final json = request.toJson();

      expect(json['materials'], ['newspaper', 'PET_plastic']);
      expect(json['materials'], isNot(contains('requested_materials')));
      expect(json.containsKey('estimated_weight'), isFalse);
      expect(json.containsKey('actual_weight'), isFalse);
      expect(json['preferred_date'], '2026-11-20');
      expect(json['preferred_time_slot'], 'morning');
      expect(json['household_id'], 'user-h123');
      expect(json['locality_id'], 'cowl_bazar');
      expect(json['latitude'], 15.13649);
      expect(json['longitude'], 76.89829);
      expect(json['notes'], 'Near temple');
    });

    test('PickupBookingResponse deserializes accurately from backend payload', () {
      final json = {
        'request_id': 'req-987',
        'household_id': 'user-h123',
        'locality_id': 'cowl_bazar',
        'latitude': 15.13649,
        'longitude': 76.89829,
        'preferred_date': '2026-11-20',
        'preferred_time_slot': 'morning',
        'materials': ['newspaper', 'iron'],
        'status': 'pending',
        'created_at': '2026-11-18T10:00:00Z',
      };

      final response = PickupBookingResponse.fromJson(json);

      expect(response.requestId, 'req-987');
      expect(response.status, 'pending');
      expect(response.materials, ['newspaper', 'iron']);
      expect(response.preferredTimeSlot, 'morning');
    });
  });

  group('Standard Scrap Materials', () {
    test('contains standard identifiers matching backend DBSCAN & catalog', () {
      final ids = ScrapMaterial.standardMaterials.map((m) => m.id).toList();

      expect(ids, contains('newspaper'));
      expect(ids, contains('old_books'));
      expect(ids, contains('cardboard'));
      expect(ids, contains('PET_plastic'));
      expect(ids, contains('mixed_plastic'));
      expect(ids, contains('iron'));
      expect(ids, contains('steel'));
      expect(ids, contains('aluminium'));
      expect(ids, contains('copper'));
      expect(ids, contains('glass'));
      expect(ids, contains('clothes'));
      expect(ids, contains('other'));
    });
  });

  group('BookPickupSheet Widget Tests', () {
    late SessionController session;

    setUp(() async {
      session = SessionController(authService: _FakeAuthService());
      await session.restoreSession();
    });

    tearDown(() => session.dispose());

    testWidgets('requires at least one material selection before proceeding to location',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: BookPickupSheet(
                sessionController: session,
                apiService: HouseholdApiService(
                  dio: Dio(BaseOptions(baseUrl: 'http://localhost:8000'))..interceptors.add(
                    InterceptorsWrapper(
                      onRequest: (options, handler) {
                        handler.resolve(Response(
                          requestOptions: options,
                          statusCode: 200,
                          data: {'localities': []},
                        ));
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Attempt to advance without selecting material
      await tester.tap(find.text('Next Step'));
      await tester.pump();

      expect(find.text('Please select at least one material.'), findsOneWidget);

      // Select newspaper
      await tester.tap(find.text('Newspaper'));
      await tester.pump();

      // Advance to step 2 (Location)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.text('Locality & Pickup Location'), findsOneWidget);
      expect(find.text('Doorstep GPS Verification'), findsOneWidget);
    });
  });

  group('EWasteTab Widget Tests', () {
    testWidgets('explains truthful service status and keeps submit disabled',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: EWasteTab(onOpenGuide: () {}),
          ),
        ),
      );

      expect(find.text('E-Waste Intelligence'), findsOneWidget);
      expect(find.text('AI Service Under Integration'), findsOneWidget);
      expect(
        find.textContaining('ScrapWise does not display fabricated AI scores'),
        findsOneWidget,
      );

      // Button should be disabled
      final submitButtonFinder = find.byType(FilledButton);
      final submitButton = tester.widget<FilledButton>(submitButtonFinder);
      expect(submitButton.onPressed, isNull);
    });
  });

  group('HouseholdApiService Unit Tests', () {
    test('createPickupRequest uses Dio and sends correct payload structure', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/pickups') {
            final data = options.data as Map<String, dynamic>;
            expect(data['materials'], ['newspaper']);
            expect(data['household_id'], 'H123');
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 201,
              data: {
                'request_id': 'req-mock-1',
                'household_id': 'H123',
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
          handler.next(options);
        },
      ));

      final service = HouseholdApiService(dio: dio);
      final result = await service.createPickupRequest(
        PickupBookingRequest(
          householdId: 'H123',
          localityId: 'cowl_bazar',
          latitude: 15.136,
          longitude: 76.898,
          preferredDate: DateTime(2026, 11, 20),
          preferredTimeSlot: 'morning',
          materials: ['newspaper'],
        ),
      );

      expect(result.requestId, 'req-mock-1');
      expect(result.status, 'pending');
    });
  });
}

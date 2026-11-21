import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapwise/core/theme/app_theme.dart';
import 'package:scrapwise/features/auth/services/auth_service.dart';
import 'package:scrapwise/features/auth/services/session_controller.dart';
import 'package:scrapwise/features/household/models/locality_model.dart';
import 'package:scrapwise/features/household/models/pickup_booking_model.dart';
import 'package:scrapwise/features/household/screens/household_dashboard_screen.dart';
import 'package:scrapwise/features/household/services/household_api_service.dart';

class _TestAuthService extends AuthService {
  @override
  Future<Map<String, dynamic>?> restoreSession() async => {
        'user_id': 'demo-household-1',
        'full_name': 'Demo Household',
        'mobile': '+919876543210',
        'role': 'household',
        'status': 'active',
        'phone_verified': true,
      };

  @override
  Future<void> logout() async {}
}

class _TestHouseholdApiService extends HouseholdApiService {
  @override
  Future<List<LocalityModel>> fetchLocalities() async =>
      LocalityModel.verifiedBallariLocalities;

  @override
  Future<List<PickupBookingResponse>> fetchPersonalPickups() async => const [];
}

void main() {
  late SessionController session;
  late HouseholdApiService apiService;

  setUp(() async {
    session = SessionController(authService: _TestAuthService());
    apiService = _TestHouseholdApiService();
    await session.restoreSession();
  });

  tearDown(() => session.dispose());

  Widget app() => ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: HouseholdDashboardScreen(
            sessionController: session,
            apiService: apiService,
          ),
        ),
      );

  testWidgets('household home renders four shortcuts and opens booking form',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app());

    // 1. Personalized Greeting
    expect(find.text('Hello, Demo'), findsOneWidget);

    // 2. Four Prominent Feature Shortcuts
    expect(find.text('Scrap Collection'), findsOneWidget);
    expect(find.text('E-Waste Intelligence'), findsOneWidget);
    expect(find.text('Local Scrap Prices'), findsOneWidget);
    expect(find.text('Safe Recovery Guide'), findsOneWidget);

    // 3. Primary Booking Action
    expect(find.text('Request Pickup'), findsOneWidget);
    await tester.tap(find.text('Request Pickup'));
    await tester.pumpAndSettle();

    // 4. Verify booking form opens with material choices and strictly no weight entry
    expect(find.text('Request a scrap pickup'), findsOneWidget);
    expect(find.text('Select materials available for collection'), findsOneWidget);
    expect(find.textContaining('No weight entry required'), findsWidgets);
    expect(find.text('Estimated scrap weight'), findsNothing);
    expect(find.text('Actual scrap weight'), findsNothing);
  });

  testWidgets('household navigation tabs and profile display truthful state',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app());

    // Tab 1: My Pickups
    await tester.tap(find.text('My Pickups'));
    await tester.pumpAndSettle();
    expect(find.text('Personal pickup history is not connected yet'),
        findsOneWidget);
    expect(find.textContaining('Security Notice'), findsOneWidget);

    // Tab 2: E-Waste
    await tester.tap(find.text('E-Waste'));
    await tester.pumpAndSettle();
    expect(find.text('E-Waste Intelligence'), findsOneWidget);
    expect(find.textContaining('AI Service Under Integration'), findsOneWidget);

    // Tab 3: Profile
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Demo Household'), findsOneWidget);
    expect(find.text('+919876543210'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);

    // Sign out test
    await tester.tap(find.text('Sign Out'));
    await tester.pump();
    expect(session.status, SessionStatus.unauthenticated);
  });

  testWidgets('price board and safe recovery guide open with truthful disclaimers',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app());

    // Open Price Board
    await tester.tap(find.text('Local Scrap Prices'));
    await tester.pumpAndSettle();
    expect(find.text('Local Scrap Price Board'), findsOneWidget);
    expect(find.textContaining('All posted prices are indicative references'),
        findsOneWidget);
    expect(find.text('No Verified Price Feeds Available'), findsOneWidget);

    // Close sheet
    await tester.tap(find.text('Check for Updates'));
    await tester.pump();
    Navigator.of(tester.element(find.text('Local Scrap Price Board'))).pop();
    await tester.pumpAndSettle();

    // Open Safe Recovery Guide
    await tester.tap(find.text('Safe Recovery Guide'));
    await tester.pumpAndSettle();
    expect(find.text('Scrap Segregation at Source'), findsOneWidget);
    expect(find.text('Safe Handling of Electronic Waste'), findsOneWidget);
    expect(find.text('Responsible Recycling'), findsOneWidget);
  });
}

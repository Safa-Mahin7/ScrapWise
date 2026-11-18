import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapwise/core/theme/app_theme.dart';
import 'package:scrapwise/features/auth/services/auth_service.dart';
import 'package:scrapwise/features/auth/services/session_controller.dart';
import 'package:scrapwise/features/household/screens/household_dashboard_screen.dart';

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

void main() {
  late SessionController session;

  setUp(() async {
    session = SessionController(authService: _TestAuthService());
    await session.restoreSession();
  });

  tearDown(() => session.dispose());

  Widget app() => MaterialApp(
        theme: AppTheme.light,
        home: HouseholdDashboardScreen(sessionController: session),
      );

  testWidgets('household home and pickup preview do not submit data',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app());

    expect(find.text('Hello, Demo'), findsOneWidget);
    expect(find.text('Request Pickup'), findsOneWidget);

    await tester.tap(find.text('Request Pickup'));
    await tester.pumpAndSettle();
    expect(find.text('Request a scrap pickup'), findsOneWidget);
    expect(find.textContaining('Booking is not available yet'), findsOneWidget);
    expect(find.text('No weight entry required'), findsOneWidget);
  });

  testWidgets('household activity and profile display truthful state',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app());

    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Personal pickup history is not connected yet'),
        findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Demo Household'), findsOneWidget);
    expect(find.text('+919876543210'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);

    await tester.tap(find.text('Sign Out'));
    await tester.pump();
    expect(session.status, SessionStatus.unauthenticated);
  });
}

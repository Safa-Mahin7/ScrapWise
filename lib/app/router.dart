import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_constants.dart';
import '../features/onboarding/screens/splash_screen.dart';
import '../features/onboarding/screens/language_selection_screen.dart';
import '../features/onboarding/screens/landing_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/link_google_screen.dart';
import '../features/auth/screens/change_mobile_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/otp_verification_screen.dart';
import '../features/auth/screens/new_password_screen.dart';
import '../features/auth/screens/collector_invitation_screen.dart';
import '../features/auth/screens/trader_application_screen.dart';
import '../features/auth/screens/trader_application_status_screen.dart';
import '../features/auth/screens/role_dashboard_screen.dart';
import '../features/household/screens/household_dashboard_screen.dart';
import '../features/auth/services/auth_service.dart';
import '../features/auth/services/google_identity_provider.dart';
import '../features/auth/services/session_controller.dart';

/// Route guards depend on server-verified session state, not a role choice.
final GoRouter appRouter = createAppRouter();

GoRouter createAppRouter({
  String? initialLocation,
  SessionController? sessionController,
  AuthService? authService,
  GoogleIdentityProvider? googleIdentityProvider,
}) {
  final session = sessionController ?? SessionController.instance;
  return GoRouter(
    initialLocation: initialLocation ?? AppConstants.routeSplash,
    debugLogDiagnostics: false,
    refreshListenable: session,
    redirect: (context, state) {
      final path = state.uri.path;
      final isDashboard = path.startsWith('/dashboard/');
      final isMobileChangeOtp =
          state.pathParameters['purpose'] == 'phone-change';
      final protected = isDashboard ||
          path == AppConstants.routeChangeMobile ||
          path == AppConstants.routeLinkGoogle ||
          isMobileChangeOtp;

      if (protected) {
        if (session.status == SessionStatus.unknown ||
            session.status == SessionStatus.unavailable) {
          return AppConstants.routeSplash;
        }
        if (!session.isAuthenticated) return AppConstants.routeLogin;
        if (isDashboard && path != session.dashboardPath) {
          return session.dashboardPath;
        }
      }

      if (session.isAuthenticated &&
          (path == AppConstants.routeSplash ||
              path == AppConstants.routeLanding ||
              path == AppConstants.routeLogin ||
              path == AppConstants.routeRegister)) {
        return session.dashboardPath;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppConstants.routeSplash,
        name: 'splash',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.routeLanguage,
        name: 'language',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const LanguageSelectionScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.routeLanding,
        name: 'landing',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const LandingScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.routeLogin,
        name: 'login',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: LoginScreen(
            sessionController: session,
            googleIdentityProvider: googleIdentityProvider,
          ),
        ),
      ),
      GoRoute(
        path: AppConstants.routeRegister,
        name: 'register',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: RegisterScreen(
            authService: authService,
            googleIdentityProvider: googleIdentityProvider,
          ),
        ),
      ),
      GoRoute(
        path: AppConstants.routeLinkGoogle,
        name: 'link-google',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: LinkGoogleScreen(
            sessionController: session,
            googleIdentityProvider: googleIdentityProvider,
          ),
        ),
      ),
      GoRoute(
        path: AppConstants.routeChangeMobile,
        name: 'change-mobile',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: ChangeMobileScreen(
            authService: authService,
            sessionController: session,
            googleIdentityProvider: googleIdentityProvider,
          ),
        ),
      ),
      GoRoute(
        path: AppConstants.routeForgotPassword,
        name: 'forgot-password',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: ForgotPasswordScreen(authService: authService),
        ),
      ),
      GoRoute(
        path: AppConstants.routeOtpVerification,
        name: 'otp-verification',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: OtpVerificationScreen(
            purpose: OtpPurposeLabel.fromRoute(state.pathParameters['purpose']),
            phoneNumber: state.extra is String ? state.extra as String : null,
            authService: authService,
            sessionController: session,
          ),
        ),
      ),
      GoRoute(
        path: AppConstants.routeNewPassword,
        name: 'new-password',
        pageBuilder: (context, state) {
          final extra = state.extra;
          final resetData = extra is Map ? extra : const <String, String>{};
          return _buildPage(
            state: state,
            child: NewPasswordScreen(
              mobile: resetData['mobile'] as String?,
              resetToken: resetData['reset_token'] as String?,
              authService: authService,
              sessionController: session,
            ),
          );
        },
      ),
      GoRoute(
        path: AppConstants.routeCollectorInvitation,
        name: 'collector-invitation',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const CollectorInvitationScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.routeTraderApplication,
        name: 'trader-application',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const TraderApplicationScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.routeTraderApplicationStatus,
        name: 'trader-application-status',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const TraderApplicationStatusScreen(),
        ),
      ),
      GoRoute(
        path: AppConstants.routeHouseholdDashboard,
        name: 'household-dashboard',
        builder: (context, state) => const HouseholdDashboardScreen(),
      ),
      GoRoute(
        path: AppConstants.routeCollectorDashboard,
        name: 'collector-dashboard',
        builder: (context, state) =>
            const RoleDashboardScreen(role: 'collector'),
      ),
      GoRoute(
        path: AppConstants.routeTraderDashboard,
        name: 'trader-dashboard',
        builder: (context, state) => const RoleDashboardScreen(role: 'trader'),
      ),
      GoRoute(
        path: AppConstants.routeAdminDashboard,
        name: 'admin-dashboard',
        builder: (context, state) => const RoleDashboardScreen(role: 'admin'),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
}

CustomTransitionPage<void> _buildPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
        child: child,
      );
    },
  );
}

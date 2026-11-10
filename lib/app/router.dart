import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_constants.dart';
import '../features/onboarding/screens/splash_screen.dart';
import '../features/onboarding/screens/language_selection_screen.dart';
import '../features/onboarding/screens/landing_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';

/// Application router.
/// Protected role-based dashboard routes will be added in later phases
/// once backend authentication is integrated.
final GoRouter appRouter = GoRouter(
  initialLocation: AppConstants.routeSplash,
  debugLogDiagnostics: false,
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
        child: const LoginScreen(),
      ),
    ),
    GoRoute(
      path: AppConstants.routeRegister,
      name: 'register',
      pageBuilder: (context, state) => _buildPage(
        state: state,
        child: const RegisterScreen(),
      ),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri}'),
    ),
  ),
);

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

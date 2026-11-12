import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/services/session_controller.dart';

/// ScrapWise splash screen.
/// Displays branding for 2.5 s, then navigates to language selection
/// (if no language was previously saved) or directly to the landing screen.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _sessionError = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate({bool showSplash = true}) async {
    if (_restoring) return;
    _restoring = true;
    if (_sessionError && mounted) setState(() => _sessionError = false);
    try {
      if (showSplash) {
        await Future.delayed(const Duration(milliseconds: 2500));
      }
      if (!mounted) return;

      // Verify a saved bearer token with FastAPI before trusting its role.
      await SessionController.instance.restoreSession();
      if (!mounted) return;

      final session = SessionController.instance;
      if (session.isAuthenticated && session.dashboardPath != null) {
        GoRouter.maybeOf(context)?.go(session.dashboardPath!);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final savedLocale = prefs.getString(AppConstants.prefLocale);
      GoRouter.maybeOf(context)?.go(
        savedLocale == null
            ? AppConstants.routeLanguage
            : AppConstants.routeLanding,
      );
    } catch (_) {
      if (mounted) setState(() => _sessionError = true);
    } finally {
      _restoring = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.splashGradient,
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo / icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.recycling_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // App name
                    Text(
                      AppConstants.appName,
                      style: AppTextStyles.displayMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Tagline
                    Text(
                      'Smart Scrap. Cleaner Future.',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Loading dots
                    SizedBox(
                      width: 48,
                      height: 4,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    if (_sessionError) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Could not verify a saved session. Check your '
                        'connection and retry.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                      TextButton(
                        onPressed: () => _navigate(showSplash: false),
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

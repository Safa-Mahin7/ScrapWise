import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../../../core/constants/app_constants.dart';
import 'auth_service.dart';

enum SessionStatus { unknown, unauthenticated, authenticated, unavailable }

/// App-wide auth state. A stored token is trusted only after /api/auth/me.
class SessionController extends ChangeNotifier with WidgetsBindingObserver {
  SessionController({AuthService? authService})
      : _authService = authService ?? AuthService.shared {
    WidgetsBinding.instance.addObserver(this);
    _monitor = _authService.monitorSession(
      onExpired: () {
        if (isAuthenticated) _update(SessionStatus.unauthenticated);
      },
      onRenewed: (user) {
        if (isAuthenticated) _update(SessionStatus.authenticated, user);
      },
    );
  }

  static final SessionController instance = SessionController();

  final AuthService _authService;
  SessionStatus _status = SessionStatus.unknown;
  Map<String, dynamic>? _user;
  Timer? _renewalTimer;
  DateTime? _renewAt;
  late final Interceptor _monitor;
  Future<void>? _restoring;
  int _transition = 0;

  SessionStatus get status => _status;
  bool get isAuthenticated => _status == SessionStatus.authenticated;
  Map<String, dynamic>? get user => _user;

  static String? dashboardForRole(Object? role) {
    return switch (role) {
      'household' => AppConstants.routeHouseholdDashboard,
      'collector' => AppConstants.routeCollectorDashboard,
      'trader' => AppConstants.routeTraderDashboard,
      'admin' => AppConstants.routeAdminDashboard,
      _ => null,
    };
  }

  String? get dashboardPath => dashboardForRole(_user?['role']);

  static bool _validUser(Map<String, dynamic> user) {
    return user['user_id'] is String &&
        (user['user_id'] as String).isNotEmpty &&
        dashboardForRole(user['role']) != null;
  }

  void _update(SessionStatus status, [Map<String, dynamic>? user]) {
    _status = status;
    _user = user;
    _scheduleRenewal();
    notifyListeners();
  }

  void _scheduleRenewal({Duration? delay}) {
    _renewalTimer?.cancel();
    if (_status != SessionStatus.authenticated) {
      _renewAt = null;
      return;
    }
    final renewalDelay = delay ?? _authService.sessionRenewalDelay;
    if (renewalDelay == null) {
      _renewAt = null;
      return;
    }
    _renewAt = DateTime.now().add(renewalDelay);
    _renewalTimer = Timer(renewalDelay, () => unawaited(_renewSession()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _status == SessionStatus.authenticated &&
        _renewAt != null &&
        !DateTime.now().isBefore(_renewAt!)) {
      unawaited(_renewSession());
    }
  }

  Future<void> _renewSession() async {
    if (!isAuthenticated) return;
    final transition = _transition;
    _renewalTimer?.cancel();
    try {
      await _authService.refreshSession();
    } on DioException {
      if (transition == _transition &&
          isAuthenticated &&
          _authService.sessionRenewalDelay != null) {
        _scheduleRenewal(delay: const Duration(minutes: 1));
      }
    } on StateError {
      // Invalid or superseded sessions are handled by the service.
    }
  }

  /// Restore once on launch, or retry after temporary connection errors.
  Future<void> restoreSession() {
    if (isAuthenticated || _status == SessionStatus.unauthenticated) {
      return Future<void>.value();
    }
    return _restoring ??= _restore(_transition).whenComplete(() {
      _restoring = null;
    });
  }

  Future<void> _restore(int transition) async {
    try {
      final user = await _authService.restoreSession();
      if (transition != _transition) return;
      if (user != null && _validUser(user)) {
        _update(SessionStatus.authenticated, user);
      } else {
        if (user != null) await _authService.clearLocalSession();
        if (transition == _transition) _update(SessionStatus.unauthenticated);
      }
    } catch (_) {
      if (transition != _transition) return;
      _update(SessionStatus.unavailable);
      rethrow;
    }
  }

  /// Log in and verify account identity before granting app navigation.
  Future<Map<String, dynamic>> signIn({
    required String mobile,
    required String password,
  }) async {
    return _establishSession(
      () => _authService.login(mobile: mobile, password: password),
    );
  }

  Future<Map<String, dynamic>> signInWithGoogle({
    required String idToken,
  }) async {
    return _establishSession(
      () => _authService.loginWithGoogle(idToken: idToken),
    );
  }

  Future<void> linkGoogleIdentity({
    required String idToken,
    required String password,
  }) {
    return _authService.linkGoogleIdentity(
      idToken: idToken,
      password: password,
    );
  }

  Future<Map<String, dynamic>> _establishSession(
    Future<Map<String, dynamic>> Function() authenticate,
  ) async {
    final transition = ++_transition;
    _update(SessionStatus.unauthenticated);
    var credentialsSaved = false;
    try {
      final loginUser = await authenticate();
      if (transition != _transition) throw StateError('Session changed');
      credentialsSaved = true;
      final verifiedUser = await _authService.currentUser();
      if (transition != _transition) throw StateError('Session changed');
      if (!_validUser(verifiedUser) ||
          verifiedUser['user_id'] != loginUser['user_id'] ||
          verifiedUser['role'] != loginUser['role']) {
        throw StateError('Authenticated user details mismatch');
      }
      _update(SessionStatus.authenticated, verifiedUser);
      return verifiedUser;
    } catch (error) {
      if (transition == _transition) {
        final code = error is DioException ? error.response?.statusCode : null;
        if (credentialsSaved &&
            error is DioException &&
            (code == null || code >= 500)) {
          _update(SessionStatus.unavailable);
        } else {
          _update(SessionStatus.unauthenticated);
          try {
            await _authService.logout();
          } catch (_) {
            // Preserve the original authentication error.
          }
        }
      }
      rethrow;
    }
  }

  Future<void> expireLocalSession() {
    _transition++;
    final cleanup = _authService.clearLocalSession();
    _update(SessionStatus.unauthenticated);
    return cleanup;
  }

  /// Attempt server revocation; always sign out locally.
  Future<void> signOut() {
    _transition++;
    final logout = _authService.logout();
    _update(SessionStatus.unauthenticated);
    return logout;
  }

  @override
  void dispose() {
    _transition++;
    _renewalTimer?.cancel();
    _authService.stopMonitoring(_monitor);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

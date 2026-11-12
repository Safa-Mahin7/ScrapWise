import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import 'auth_service.dart';

enum SessionStatus { unknown, unauthenticated, authenticated, unavailable }

/// App-wide auth state. A stored token is trusted only after /api/auth/me.
class SessionController extends ChangeNotifier {
  SessionController({AuthService? authService})
      : _authService = authService ?? AuthService();

  static final SessionController instance = SessionController();

  final AuthService _authService;
  SessionStatus _status = SessionStatus.unknown;
  Map<String, dynamic>? _user;

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
    notifyListeners();
  }

  /// Restore once on launch, or retry after temporary connection errors.
  Future<void> restoreSession() async {
    if (_status == SessionStatus.authenticated ||
        _status == SessionStatus.unauthenticated) {
      return;
    }
    try {
      final restoredUser = await _authService.restoreSession();
      if (restoredUser == null) {
        _update(SessionStatus.unauthenticated);
      } else if (_validUser(restoredUser)) {
        _update(SessionStatus.authenticated, restoredUser);
      } else {
        await _authService.clearLocalSession();
        _update(SessionStatus.unauthenticated);
      }
    } catch (_) {
      // A network/storage failure must not silently erase a valid token.
      _update(SessionStatus.unavailable);
      rethrow;
    }
  }

  /// Log in and verify account identity before granting app navigation.
  Future<Map<String, dynamic>> signIn({
    required String mobile,
    required String password,
  }) async {
    try {
      final loginUser = await _authService.login(
        mobile: mobile,
        password: password,
      );
      final verifiedUser = await _authService.currentUser();
      if (!_validUser(verifiedUser) ||
          verifiedUser['user_id'] != loginUser['user_id'] ||
          verifiedUser['role'] != loginUser['role']) {
        throw StateError('Authenticated user details mismatch');
      }
      _update(SessionStatus.authenticated, verifiedUser);
      return verifiedUser;
    } catch (_) {
      // A successful /login without a verified /me is not an app session.
      await _authService.clearLocalSession();
      _update(SessionStatus.unauthenticated);
      rethrow;
    }
  }

  /// Attempt server revocation; always sign out locally.
  Future<void> signOut() async {
    try {
      await _authService.logout();
    } finally {
      _update(SessionStatus.unauthenticated);
    }
  }
}

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionCredentials {
  const SessionCredentials(this.accessToken,
      {this.refreshToken,
      this.accessExpiresAt,
      this.refreshOutcomeUncertain = false,
      this.userId,
      this.requiresAccountVerification = false});

  final String accessToken;
  final String? refreshToken;
  final DateTime? accessExpiresAt;
  final bool refreshOutcomeUncertain;
  final String? userId;
  final bool requiresAccountVerification;

  bool get shouldRenew =>
      refreshToken != null &&
      (accessExpiresAt
              ?.isBefore(DateTime.now().add(const Duration(seconds: 15))) ??
          false);
}

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'scrapwise_access_token';
  static const _refreshKey = 'scrapwise_refresh_token';
  static const _expiryKey = 'scrapwise_access_expires_at';
  static final _tokenPattern = RegExp(r'^[A-Za-z0-9_-]+$');

  final FlutterSecureStorage _storage;

  static bool _validToken(Object? value) =>
      value is String && _tokenPattern.hasMatch(value);

  Future<void> saveSession(SessionCredentials credentials) async {
    await _storage.write(
      key: _accessKey,
      value: jsonEncode({
        'access': credentials.accessToken,
        'refresh': credentials.refreshToken,
        'expires': credentials.accessExpiresAt?.toUtc().toIso8601String(),
        if (credentials.refreshOutcomeUncertain) 'refresh_uncertain': true,
        if (credentials.userId case final id?) 'user_id': id,
        if (credentials.requiresAccountVerification)
          'verify_split_account': true,
      }),
    );
  }

  Future<SessionCredentials?> readSession() async {
    final value = await _storage.read(key: _accessKey);
    if (value == null) return null;
    if (value.startsWith('{')) {
      try {
        final data = jsonDecode(value);
        if (data is! Map<String, dynamic>) return null;
        final uncertain = data['refresh_uncertain'];
        final verifyAccount = data['verify_split_account'];
        final userId = data['user_id'];
        if ((uncertain != null && uncertain is! bool) ||
            (verifyAccount != null && verifyAccount is! bool) ||
            (userId != null && (userId is! String || userId.isEmpty))) {
          return null;
        }
        return _parse(data['access'], data['refresh'], data['expires'],
            uncertain: uncertain == true,
            userId: userId as String?,
            verifyAccount: verifyAccount == true);
      } on FormatException {
        return null;
      }
    }
    final refresh = await _storage.read(key: _refreshKey);
    final expires = await _storage.read(key: _expiryKey);
    final credentials =
        _parse(value, refresh, expires, verifyAccount: refresh != null);
    if (credentials != null) {
      await saveSession(credentials);
      await _clearSplitKeys();
    }
    return credentials;
  }

  static SessionCredentials? _parse(
      Object? access, Object? refresh, Object? expires,
      {bool uncertain = false, String? userId, bool verifyAccount = false}) {
    if (!_validToken(access)) return null;
    if (refresh == null && expires == null && !uncertain && !verifyAccount) {
      return SessionCredentials(access as String, userId: userId);
    }
    final expiry = expires is String ? DateTime.tryParse(expires) : null;
    if (!_validToken(refresh) || expiry == null) return null;
    return SessionCredentials(access as String,
        refreshToken: refresh as String,
        accessExpiresAt: expiry.toUtc(),
        refreshOutcomeUncertain: uncertain,
        userId: userId,
        requiresAccountVerification: verifyAccount);
  }

  Future<void> _clearSplitKeys() async {
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _expiryKey);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _clearSplitKeys();
  }
}

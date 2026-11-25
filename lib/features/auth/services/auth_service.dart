import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'session_store.dart';

class AuthService {
  AuthService({
    Dio? dio,
    SessionStore? sessionStore,
  })  : _dio = dio ?? ApiClient.instance.dio,
        _sessionStore = sessionStore ?? SessionStore();

  static final AuthService shared = AuthService();

  final Dio _dio;
  final SessionStore _sessionStore;
  SessionCredentials? _credentials;
  Future<Map<String, dynamic>>? _refreshing;
  Future<void> _storageTail = Future<void>.value();
  int _generation = 0;
  void Function()? _onExpired;
  void Function(Map<String, dynamic>)? _onRenewed;

  Duration? get sessionRenewalDelay {
    final expiresAt = _credentials?.accessExpiresAt;
    if (expiresAt == null ||
        _credentials?.refreshToken == null ||
        _credentials!.refreshOutcomeUncertain) {
      return null;
    }
    final delay =
        expiresAt.difference(DateTime.now()) - const Duration(minutes: 5);
    // Small lifetimes in tests or deployments must not cause a refresh loop.
    return delay.isNegative ? const Duration(seconds: 15) : delay;
  }

  // Only the session controller manages the shared API client. Screen-local
  // services for registration and OTP do not install their own interceptors.
  Interceptor monitorSession({
    required void Function() onExpired,
    required void Function(Map<String, dynamic>) onRenewed,
  }) {
    _onExpired = onExpired;
    _onRenewed = onRenewed;
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) async {
        final requestGeneration = options.extra['scrapwiseSessionGeneration'];
        if (requestGeneration != null && requestGeneration != _generation) {
          handler.reject(_superseded(options));
          return;
        }
        if (!_isManagedRequest(options) || _credentials == null) {
          handler.next(options);
          return;
        }
        final generation = _generation;
        try {
          final pending = _refreshing;
          if (pending != null) {
            await pending;
          } else if (options.extra['scrapwiseSessionRetried'] != true &&
              _credentials!.shouldRenew) {
            await refreshSession();
          }
          _checkGeneration(generation);
          options.headers['Authorization'] = _bearer(_credentials!);
          options.extra['scrapwiseSessionGeneration'] = generation;
          handler.next(options);
        } catch (_) {
          handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            message: 'Session renewal could not complete',
          ));
        }
      },
      onError: (error, handler) async {
        final request = error.requestOptions;
        final credentials = _credentials;
        final requestGeneration = request.extra['scrapwiseSessionGeneration'];
        if (requestGeneration != null && requestGeneration != _generation) {
          handler.next(_superseded(request));
          return;
        }
        if (error.response?.statusCode != 401 ||
            requestGeneration == null ||
            credentials == null) {
          handler.next(error);
          return;
        }
        final generation = _generation;
        final isCurrentToken =
            request.headers['Authorization'] == _bearer(credentials);
        final retried = request.extra['scrapwiseSessionRetried'] == true;
        try {
          if (retried || credentials.refreshToken == null) {
            if (isCurrentToken) await _expire();
          } else {
            if (isCurrentToken) await refreshSession();
            _checkGeneration(generation);
            if (request.method == 'GET' || request.method == 'HEAD') {
              final response = await _dio.fetch<dynamic>(request.copyWith(
                headers: {
                  ...request.headers,
                  'Authorization': _bearer(_credentials!)
                },
                extra: {...request.extra, 'scrapwiseSessionRetried': true},
              ));
              handler.resolve(response);
              return;
            }
          }
        } on DioException catch (error) {
          handler.next(error);
          return;
        } catch (_) {
          handler
              .next(generation == _generation ? error : _superseded(request));
          return;
        }
        handler.next(error);
      },
    );
    _dio.interceptors.insert(0, interceptor);
    return interceptor;
  }

  static DioException _superseded(RequestOptions request) => DioException(
        requestOptions: request,
        type: DioExceptionType.cancel,
        message: 'Session changed',
      );

  void stopMonitoring(Interceptor interceptor) {
    _dio.interceptors.remove(interceptor);
    _onExpired = null;
    _onRenewed = null;
  }

  bool _isManagedRequest(RequestOptions options) {
    final base = Uri.tryParse(_dio.options.baseUrl);
    final uri = options.uri;
    return base != null &&
        base.hasAuthority &&
        uri.scheme == base.scheme &&
        uri.host == base.host &&
        uri.port == base.port &&
        uri.path.startsWith('/api/') &&
        !const {
          '/api/auth/login',
          '/api/auth/google/login',
          '/api/auth/google/register',
          '/api/auth/refresh',
          '/api/auth/logout',
          '/api/auth/me',
          '/api/auth/register/household',
          '/api/auth/trader/apply',
          '/api/auth/otp/resend',
          '/api/auth/otp/verify',
          '/api/auth/password/forgot',
          '/api/auth/password/reset',
          '/api/auth/collector/activate/request-otp',
          '/api/auth/collector/activate',
        }.contains(uri.path);
  }

  static String _bearer(SessionCredentials credentials) =>
      'Bearer ${credentials.accessToken}';

  void _checkGeneration(int generation) {
    if (generation != _generation) throw StateError('Session changed');
  }

  Future<void> _writeStorage(Future<void> Function() operation) {
    final write = _storageTail.then((_) => operation());
    _storageTail =
        write.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return write;
  }

  // Household registration
  Future<void> registerHousehold({
    required String mobile,
    required String fullName,
    required String localityId,
    required String password,
  }) async {
    await _dio.post(
      '/api/auth/register/household',
      data: {
        'mobile': mobile,
        'full_name': fullName,
        'locality_id': localityId,
        'password': password,
      },
    );
  }

  Future<void> registerGoogleHousehold({
    required String idToken,
    required String mobile,
    required String fullName,
    required String localityId,
  }) async {
    await _dio.post(
      '/api/auth/google/register',
      data: {
        'id_token': idToken,
        'mobile': mobile,
        'full_name': fullName,
        'locality_id': localityId,
      },
    );
  }

  // Registration OTP verification
  Future<void> verifyOtp({
    required String mobile,
    required String purpose,
    required String code,
  }) async {
    await _dio.post(
      '/api/auth/otp/verify',
      data: {
        'mobile': mobile,
        'purpose': purpose,
        'code': code,
      },
    );
  }

  Future<String> verifyPasswordRecoveryOtp({
    required String mobile,
    required String code,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/otp/verify',
      data: {
        'mobile': mobile,
        'purpose': 'password_reset',
        'code': code,
      },
    );
    final resetToken = response.data?['reset_token'];
    if (resetToken is! String || resetToken.isEmpty) {
      throw StateError('Password recovery response contains no reset grant');
    }
    return resetToken;
  }

  Future<void> requestPasswordReset({required String mobile}) async {
    await _dio.post(
      '/api/auth/password/forgot',
      data: {'mobile': mobile},
    );
  }

  Future<void> resetPassword({
    required String mobile,
    required String resetToken,
    required String newPassword,
  }) async {
    final generation = _generation;
    await _dio.post(
      '/api/auth/password/reset',
      data: {
        'mobile': mobile,
        'reset_token': resetToken,
        'new_password': newPassword,
      },
    );
    _checkGeneration(generation);
    await clearLocalSession();
  }

  Future<void> requestMobileChange({
    required String newMobile,
    String? currentPassword,
    String? googleIdToken,
  }) async {
    await _dio.post(
      '/api/auth/mobile/change/request',
      data: {
        'new_mobile': newMobile,
        if (currentPassword != null) 'current_password': currentPassword,
        if (googleIdToken != null) 'google_id_token': googleIdToken,
      },
    );
  }

  Future<void> resendMobileChange() async {
    await _dio.post('/api/auth/mobile/change/resend');
  }

  Future<void> confirmMobileChange({
    required String newMobile,
    required String code,
  }) async {
    final generation = _generation;
    await _dio.post(
      '/api/auth/mobile/change/confirm',
      data: {'new_mobile': newMobile, 'code': code},
    );
    _checkGeneration(generation);
    await clearLocalSession();
  }

  // Resend registration OTP
  Future<void> resendOtp({
    required String mobile,
  }) async {
    await _dio.post(
      '/api/auth/otp/resend',
      data: {
        'mobile': mobile,
      },
    );
  }

  Future<Map<String, dynamic>> login({
    required String mobile,
    required String password,
  }) =>
      _login('/api/auth/login', {'mobile': mobile, 'password': password});

  Future<Map<String, dynamic>> loginWithGoogle({required String idToken}) =>
      _login('/api/auth/google/login', {'id_token': idToken});

  Future<Map<String, dynamic>> _login(
      String path, Map<String, dynamic> data) async {
    final previous = _credentials;
    final cleanup = clearLocalSession();
    final generation = _generation;
    if (previous != null) unawaited(_bestEffortRevoke(previous));
    await cleanup;
    _checkGeneration(generation);
    final requestedAt = DateTime.now();
    final response = await _dio.post<Map<String, dynamic>>(path, data: data);
    return _saveResponse(response.data, generation, requestedAt);
  }

  Future<void> linkGoogleIdentity({
    required String idToken,
    required String password,
  }) async {
    await _dio.post(
      '/api/auth/google/link',
      data: {
        'id_token': idToken,
        'password': password,
      },
    );
  }

  Future<Map<String, dynamic>> _saveResponse(
    Map<String, dynamic>? data,
    int generation,
    DateTime requestedAt, {
    String? expectedUserId,
  }) async {
    final access = data?['access_token'];
    final refresh = data?['refresh_token'];
    final seconds = data?['expires_in'];
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty ||
        seconds is! int ||
        seconds <= 0) {
      throw StateError('Invalid session response');
    }
    final user = data?['user'];
    final userId = user is Map ? user['user_id'] : null;
    final credentials = SessionCredentials(
      access,
      refreshToken: refresh,
      accessExpiresAt: requestedAt.add(Duration(seconds: seconds)),
      userId: userId is String ? userId : null,
    );
    try {
      if (user is! Map<String, dynamic> ||
          userId is! String ||
          userId.isEmpty ||
          (expectedUserId != null && userId != expectedUserId) ||
          !const {'household', 'collector', 'trader', 'admin'}
              .contains(user['role'])) {
        throw StateError('Invalid session user');
      }
      await _writeStorage(() async {
        _checkGeneration(generation);
        await _sessionStore.saveSession(credentials);
        _checkGeneration(generation);
        _credentials = credentials;
      });
      _checkGeneration(generation);
      return user;
    } catch (_) {
      await _bestEffortRevoke(credentials);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> currentUser() async {
    final credentials = _credentials;
    if (credentials == null) throw StateError('No active session');
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/auth/me',
      options: Options(headers: {'Authorization': _bearer(credentials)}),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>?> restoreSession() async {
    final generation = _generation;
    await _storageTail;
    SessionCredentials? credentials;
    await _writeStorage(() async {
      _checkGeneration(generation);
      credentials = _credentials ?? await _sessionStore.readSession();
      _checkGeneration(generation);
      _credentials = credentials;
      if (credentials == null) await _sessionStore.clear();
    });
    final restored = credentials;
    if (restored == null) return null;
    if (restored.shouldRenew && !restored.requiresAccountVerification) {
      return _restoreByRenewing();
    }
    try {
      final user = await currentUser();
      _checkGeneration(generation);
      final userId = user['user_id'];
      if (userId is! String ||
          userId.isEmpty ||
          (restored.userId != null && restored.userId != userId)) {
        await _expire();
        return null;
      }
      if (restored.requiresAccountVerification) {
        // Old split writes had no atomicity guarantee. Establish which account
        // owns the access token before allowing any refresh of that pair.
        final verified = SessionCredentials(
          restored.accessToken,
          refreshToken: restored.refreshToken,
          accessExpiresAt: restored.accessExpiresAt,
          userId: userId,
        );
        await _writeStorage(() async {
          _checkGeneration(generation);
          await _sessionStore.saveSession(verified);
          _checkGeneration(generation);
          _credentials = verified;
        });
      }
      return user;
    } on DioException catch (error) {
      _checkGeneration(generation);
      if (error.response?.statusCode != 401 &&
          error.response?.statusCode != 403) {
        rethrow;
      }
      if (restored.refreshToken != null &&
          !restored.requiresAccountVerification) {
        return _restoreByRenewing();
      }
      await _expire();
      return null;
    } catch (_) {
      if (_credentials == null) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _restoreByRenewing() async {
    if (_credentials?.refreshOutcomeUncertain == true) return null;
    try {
      return await refreshSession();
    } catch (_) {
      if (_credentials == null) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> refreshSession() {
    final credentials = _credentials;
    if (credentials?.refreshToken == null) {
      return Future.error(StateError('No refresh credential'));
    }
    if (credentials!.refreshOutcomeUncertain ||
        credentials.requiresAccountVerification) {
      return Future.error(StateError('Sign in again to renew this session'));
    }
    return _refreshing ??= _rotate(credentials, _generation);
  }

  Future<Map<String, dynamic>> _rotate(
    SessionCredentials credentials,
    int generation,
  ) async {
    try {
      final requestedAt = DateTime.now();
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refresh_token': credentials.refreshToken},
      );
      final user = await _saveResponse(
        response.data,
        generation,
        requestedAt,
        expectedUserId: credentials.userId,
      );
      _checkGeneration(generation);
      _onRenewed?.call(user);
      return user;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (_generation == generation && (status == 401 || status == 403)) {
        await _expire();
      } else if (_generation == generation &&
          (error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout)) {
        // The server may already have rotated the token. Keep the record but
        // prevent reuse of this credential, including after an app restart.
        final uncertain = SessionCredentials(
          credentials.accessToken,
          refreshToken: credentials.refreshToken,
          accessExpiresAt: credentials.accessExpiresAt,
          refreshOutcomeUncertain: true,
          userId: credentials.userId,
        );
        _credentials = uncertain;
        await _writeStorage(() async {
          if (generation == _generation) {
            await _sessionStore.saveSession(uncertain);
          }
        });
      }
      rethrow;
    } catch (_) {
      if (_generation == generation) await _expire();
      rethrow;
    } finally {
      if (_generation == generation) _refreshing = null;
    }
  }

  Future<void> clearLocalSession() {
    _generation++;
    _refreshing = null;
    _credentials = null;
    return _writeStorage(_sessionStore.clear);
  }

  Future<void> _expire() async {
    final cleanup = clearLocalSession();
    _onExpired?.call();
    try {
      await cleanup;
    } catch (_) {
      // No credentials remain active in memory.
    }
  }

  Future<void> _revoke(SessionCredentials credentials) async {
    await _dio.post(
      '/api/auth/logout',
      options: Options(headers: {'Authorization': _bearer(credentials)}),
      data: credentials.refreshToken == null
          ? null
          : {'refresh_token': credentials.refreshToken},
    );
  }

  Future<void> _bestEffortRevoke(SessionCredentials credentials) async {
    try {
      await _revoke(credentials);
    } catch (_) {
      // Local logout still takes effect when the server cannot be reached.
    }
  }

  Future<void> logout() async {
    final credentials = _credentials;
    final cleanup = clearLocalSession();
    // Start revocation even if secure storage is unavailable.
    await Future.wait([
      cleanup,
      if (credentials != null) _revoke(credentials),
    ]);
  }
}

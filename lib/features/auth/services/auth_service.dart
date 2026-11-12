import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'session_store.dart';

class AuthService {
  AuthService({
    Dio? dio,
    SessionStore? sessionStore,
  })  : _dio = dio ?? ApiClient.instance.dio,
        _sessionStore = sessionStore ?? SessionStore();

  final Dio _dio;
  final SessionStore _sessionStore;

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

  // Authenticate and save session token
  Future<Map<String, dynamic>> login({
    required String mobile,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {
        'mobile': mobile,
        'password': password,
      },
    );

    final data = response.data;
    final token = data?['access_token'];
    final user = data?['user'];

    if (token is! String || token.isEmpty) {
      throw StateError(
        'Login response contains no access token',
      );
    }

    if (user is! Map) {
      throw StateError(
        'Login response contains no valid user',
      );
    }

    // Save the token before marking this client authenticated.
    await _sessionStore.save(token);

    _dio.options.headers['Authorization'] = 'Bearer $token';

    return Map<String, dynamic>.from(user);
  }

  // Validate the active session with FastAPI
  Future<Map<String, dynamic>> currentUser() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/auth/me',
    );

    return response.data ?? <String, dynamic>{};
  }

  // Restore a previously saved session.
  // The server must validate the token before we trust it.
  Future<Map<String, dynamic>?> restoreSession() async {
    final token = await _sessionStore.read();

    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
      return null;
    }

    _dio.options.headers['Authorization'] = 'Bearer $token';

    try {
      return await currentUser();
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;

      // Invalid, expired, or inactive session.
      if (statusCode == 401 || statusCode == 403) {
        await clearLocalSession();
        return null;
      }

      // A network outage is not proof that the token expired.
      // Preserve it and let the caller handle the connection error.
      rethrow;
    }
  }

  // Clear the locally saved session
  Future<void> clearLocalSession() async {
    _dio.options.headers.remove('Authorization');
    await _sessionStore.clear();
  }

  // Revoke the server session and remove local credentials
  Future<void> logout() async {
    try {
      if (_dio.options.headers.containsKey('Authorization')) {
        await _dio.post('/api/auth/logout');
      }
    } finally {
      await clearLocalSession();
    }
  }
}

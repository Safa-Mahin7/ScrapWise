import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class AuthService {
  final Dio _dio = ApiClient.instance.dio;

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

  // Verify OTP
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

  // Login
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

    if (token is! String || token.isEmpty) {
      throw StateError('Login response contains no access token');
    }

    _dio.options.headers['Authorization'] = 'Bearer $token';

    return Map<String, dynamic>.from(data!['user'] as Map);
  }

  // Get current authenticated user
  Future<Map<String, dynamic>> currentUser() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/auth/me',
    );

    return response.data ?? <String, dynamic>{};
  }

  // Logout
  Future<void> logout() async {
    try {
      await _dio.post('/api/auth/logout');
    } finally {
      _dio.options.headers.remove('Authorization');
    }
  }
}

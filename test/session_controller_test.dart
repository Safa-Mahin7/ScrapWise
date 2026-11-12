import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapwise/features/auth/services/auth_service.dart';
import 'package:scrapwise/features/auth/services/session_controller.dart';
import 'package:scrapwise/features/auth/services/session_store.dart';

class MemorySessionStore extends SessionStore {
  String? token;

  @override
  Future<void> save(String value) async {
    token = value;
  }

  @override
  Future<String?> read() async => token;

  @override
  Future<void> clear() async {
    token = null;
  }
}

Dio fakeDio({required int meStatus}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8001'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (options.path == '/api/auth/me') {
        if (meStatus == 200) {
          handler.resolve(Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'user_id': 'test-user',
              'role': 'household',
              'full_name': 'Demo User',
            },
          ));
        } else {
          handler.reject(DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: meStatus),
            type: DioExceptionType.badResponse,
          ));
        }
        return;
      }
      if (options.path == '/api/auth/logout') {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'message': 'Signed out'},
        ));
        return;
      }
      handler.reject(DioException(
        requestOptions: options,
        message: 'Unexpected API request in session test',
      ));
    },
  ));
  return dio;
}

void main() {
  test('restores valid saved token only after /me verification', () async {
    final store = MemorySessionStore()..token = 'saved-token';
    final dio = fakeDio(meStatus: 200);
    final controller = SessionController(
      authService: AuthService(dio: dio, sessionStore: store),
    );

    await controller.restoreSession();
    expect(controller.isAuthenticated, isTrue);
    expect(controller.dashboardPath, '/dashboard/household');
    expect(dio.options.headers['Authorization'], 'Bearer saved-token');
  });

  test('invalid saved token is cleared and does not authenticate', () async {
    final store = MemorySessionStore()..token = 'expired-token';
    final dio = fakeDio(meStatus: 401);
    final controller = SessionController(
      authService: AuthService(dio: dio, sessionStore: store),
    );

    await controller.restoreSession();
    expect(controller.status, SessionStatus.unauthenticated);
    expect(controller.isAuthenticated, isFalse);
    expect(store.token, isNull);
    expect(dio.options.headers.containsKey('Authorization'), isFalse);
  });

  test('logout revokes and removes the local token', () async {
    final store = MemorySessionStore()..token = 'saved-token';
    final dio = fakeDio(meStatus: 200);
    final controller = SessionController(
      authService: AuthService(dio: dio, sessionStore: store),
    );

    await controller.restoreSession();
    await controller.signOut();
    expect(controller.isAuthenticated, isFalse);
    expect(store.token, isNull);
    expect(dio.options.headers.containsKey('Authorization'), isFalse);
  });
}

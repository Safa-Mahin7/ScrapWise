import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapwise/app/router.dart';
import 'package:scrapwise/features/auth/services/auth_service.dart';
import 'package:scrapwise/features/auth/services/session_controller.dart';
import 'package:scrapwise/features/auth/services/session_store.dart';

class MemorySessionStore extends SessionStore {
  SessionCredentials? credentials;
  bool failAfterWrite = false;

  @override
  Future<void> saveSession(SessionCredentials value) async {
    credentials = value;
    if (failAfterWrite) throw StateError('Test storage write failed');
  }

  @override
  Future<SessionCredentials?> readSession() async => credentials;

  @override
  Future<void> clear() async {
    credentials = null;
  }
}

Dio fakeDio({
  required int meStatus,
  Map<String, dynamic> user = household,
  Future<Map<String, dynamic>> Function()? rotate,
  void Function(RequestOptions)? record,
  Map<String, dynamic>? loginResponse,
  int protectedStatus = 200,
  DioExceptionType? refreshError,
  int? refreshStatus,
  int Function(RequestOptions)? statusForRequest,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8001'));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      record?.call(options);
      if (const {'/api/auth/login', '/api/auth/google/login'}
              .contains(options.path) &&
          loginResponse != null) {
        handler.resolve(Response<Map<String, dynamic>>(
          requestOptions: options,
          data: loginResponse,
        ));
        return;
      }
      if (options.path == '/api/auth/refresh' && refreshError != null) {
        handler.reject(DioException(
          requestOptions: options,
          type: refreshError,
          response: refreshStatus == null
              ? null
              : Response(requestOptions: options, statusCode: refreshStatus),
        ));
        return;
      }
      if (options.path == '/api/auth/refresh' && rotate != null) {
        handler.resolve(Response<Map<String, dynamic>>(
          requestOptions: options,
          data: await rotate(),
        ));
        return;
      }
      if (options.path == '/api/auth/me') {
        if (meStatus == 200) {
          handler.resolve(Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: user,
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
      if (options.uri.path == '/api/pickups/my') {
        final status = statusForRequest?.call(options) ?? protectedStatus;
        final response = Response(requestOptions: options, statusCode: status);
        if (status == 200) {
          handler.resolve(response);
        } else {
          handler.reject(
              DioException.badResponse(
                statusCode: status,
                requestOptions: options,
                response: response,
              ),
              true);
        }
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

const household = {'user_id': 'test-user', 'role': 'household'};

Map<String, dynamic> credentialsResponse({
  Map<String, dynamic> user = household,
  int expiresIn = 3600,
}) =>
    {
      'access_token': 'test-renewed-access',
      'refresh_token': 'test-rotated-refresh',
      'expires_in': expiresIn,
      'user': user,
    };

Future<void> savePair(MemorySessionStore store, {required bool expired}) {
  return store.saveSession(SessionCredentials(
    'test-initial-access',
    refreshToken: 'test-initial-refresh',
    accessExpiresAt: DateTime.now().add(Duration(hours: expired ? -1 : 1)),
  ));
}

void main() {
  test('restores valid saved token only after /me verification', () async {
    final store = MemorySessionStore()
      ..credentials = const SessionCredentials('saved-token');
    final requests = <RequestOptions>[];
    final dio = fakeDio(meStatus: 200, record: requests.add);
    final controller = SessionController(
      authService: AuthService(dio: dio, sessionStore: store),
    );

    await controller.restoreSession();
    expect(controller.isAuthenticated, isTrue);
    expect(controller.dashboardPath, '/dashboard/household');
    expect(requests.single.headers['Authorization'], 'Bearer saved-token');
  });

  test('invalid saved token is cleared and does not authenticate', () async {
    final store = MemorySessionStore()
      ..credentials = const SessionCredentials('expired-token');
    final dio = fakeDio(meStatus: 401);
    final controller = SessionController(
      authService: AuthService(dio: dio, sessionStore: store),
    );

    await controller.restoreSession();
    expect(controller.status, SessionStatus.unauthenticated);
    expect(controller.isAuthenticated, isFalse);
    expect(store.credentials, isNull);
    expect(dio.options.headers.containsKey('Authorization'), isFalse);
  });

  test('logout revokes and removes the local token', () async {
    final store = MemorySessionStore()
      ..credentials = const SessionCredentials('saved-token');
    final dio = fakeDio(meStatus: 200);
    final controller = SessionController(
      authService: AuthService(dio: dio, sessionStore: store),
    );

    await controller.restoreSession();
    await controller.signOut();
    expect(controller.isAuthenticated, isFalse);
    expect(store.credentials, isNull);
    expect(dio.options.headers.containsKey('Authorization'), isFalse);
  });

  for (final role in ['household', 'collector', 'trader', 'admin']) {
    test('restart refresh routes the server-selected $role role', () async {
      final store = MemorySessionStore();
      await savePair(store, expired: true);
      final requests = <RequestOptions>[];
      final user = {'user_id': 'test-user', 'role': role};
      final dio = fakeDio(
        meStatus: 200,
        user: user,
        rotate: () async => credentialsResponse(user: user),
        record: requests.add,
      );
      final controller = SessionController(
        authService: AuthService(dio: dio, sessionStore: store),
      );
      addTearDown(controller.dispose);
      await Future.wait(
          [controller.restoreSession(), controller.restoreSession()]);
      expect(requests.single.path, '/api/auth/refresh');
      expect(controller.dashboardPath, '/dashboard/$role');
      expect((await store.readSession())?.refreshToken, 'test-rotated-refresh');
      await dio.get('/api/pickups/my');
      expect(
          requests.last.headers['Authorization'], 'Bearer test-renewed-access');
    });
  }

  testWidgets('router redirects a mismatched dashboard after restart renewal',
      (tester) async {
    final controller = (await tester.runAsync(() async {
      final store = MemorySessionStore();
      const admin = {'user_id': 'test-user', 'role': 'admin'};
      final dio = fakeDio(
        meStatus: 200,
        rotate: () async => credentialsResponse(user: admin),
      );
      final session = SessionController(
        authService: AuthService(dio: dio, sessionStore: store),
      );
      await savePair(store, expired: true);
      await session.restoreSession().timeout(const Duration(seconds: 5));
      return session;
    }))!;
    final router = createAppRouter(
      initialLocation: '/dashboard/trader',
      sessionController: controller,
    );
    addTearDown(() {
      router.dispose();
      controller.dispose();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Admin Dashboard'), findsOneWidget);
    expect(find.text('Trader Dashboard'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('simultaneous protected requests share one renewal and use its bearer',
      () async {
    final store = MemorySessionStore();
    final started = Completer<void>();
    final rotation = Completer<Map<String, dynamic>>();
    final requests = <RequestOptions>[];
    final dio = fakeDio(
      meStatus: 200,
      loginResponse: {
        ...credentialsResponse(expiresIn: 1),
        'refresh_token': 'test-initial-refresh',
      },
      rotate: () {
        if (!started.isCompleted) started.complete();
        return rotation.future;
      },
      record: requests.add,
    );
    final controller = SessionController(
      authService: AuthService(dio: dio, sessionStore: store),
    );
    addTearDown(controller.dispose);
    await controller.signIn(
        mobile: 'synthetic-mobile', password: 'synthetic-password');
    final protected = Future.wait([
      dio.get('/api/pickups/my'),
      dio.get('/api/pickups/my'),
    ]);
    await started.future;
    rotation.complete(credentialsResponse());
    await protected;
    expect(requests.where((r) => r.path == '/api/auth/refresh'), hasLength(1));
    expect(
      requests
          .where((r) => r.path == '/api/pickups/my')
          .map((r) => r.headers['Authorization']),
      everyElement('Bearer test-renewed-access'),
    );
  });

  test('logout during renewal revokes the family and drops the late response',
      () async {
    final store = MemorySessionStore();
    await savePair(store, expired: true);
    final started = Completer<void>();
    final rotation = Completer<Map<String, dynamic>>();
    final requests = <RequestOptions>[];
    final dio = fakeDio(
      meStatus: 200,
      rotate: () {
        started.complete();
        return rotation.future;
      },
      record: requests.add,
    );
    final controller = SessionController(
      authService: AuthService(dio: dio, sessionStore: store),
    );
    addTearDown(controller.dispose);
    final restore = controller.restoreSession();
    await started.future;
    await controller.signOut();
    rotation.complete(credentialsResponse());
    await restore;
    expect(controller.status, SessionStatus.unauthenticated);
    expect(await store.readSession(), isNull);
    expect(
      requests.firstWhere((r) => r.path == '/api/auth/logout').data,
      {'refresh_token': 'test-initial-refresh'},
    );
  });

  test('a storage failure after writing a rotated pair revokes and clears it',
      () async {
    final store = MemorySessionStore();
    await savePair(store, expired: true);
    store.failAfterWrite = true;
    final requests = <RequestOptions>[];
    final dio = fakeDio(
      meStatus: 200,
      rotate: () async => credentialsResponse(),
      record: requests.add,
    );
    final controller = SessionController(
      authService: AuthService(dio: dio, sessionStore: store),
    );
    addTearDown(controller.dispose);
    await controller.restoreSession();
    expect(controller.status, SessionStatus.unauthenticated);
    expect(await store.readSession(), isNull);
    expect(
      requests
          .where((r) => r.path == '/api/auth/logout')
          .map((r) => r.data['refresh_token']),
      contains('test-rotated-refresh'),
    );
  });

  test('a rejected legacy bearer clears the session without retry', () async {
    final store = MemorySessionStore()
      ..credentials = const SessionCredentials('saved-token');
    final requests = <RequestOptions>[];
    final dio =
        fakeDio(meStatus: 200, protectedStatus: 401, record: requests.add);
    final controller = SessionController(
      authService: AuthService(dio: dio, sessionStore: store),
    );
    addTearDown(controller.dispose);
    await controller.restoreSession();
    await expectLater(dio.get('/api/pickups/my'), throwsA(isA<DioException>()));
    expect(controller.status, SessionStatus.unauthenticated);
    expect(await store.readSession(), isNull);
    expect(requests.map((r) => r.path), ['/api/auth/me', '/api/pickups/my']);
  });

  test('Google login establishes the same verified credential pair', () async {
    final store = MemorySessionStore();
    final requests = <RequestOptions>[];
    final dio = fakeDio(
        meStatus: 200,
        loginResponse: credentialsResponse(),
        record: requests.add);
    final controller = SessionController(
      authService: AuthService(dio: dio, sessionStore: store),
    );
    addTearDown(controller.dispose);

    await controller.signInWithGoogle(idToken: 'synthetic-id');
    expect(controller.dashboardPath, '/dashboard/household');
    expect(store.credentials?.refreshToken, 'test-rotated-refresh');
    expect(requests.first.path, '/api/auth/google/login');
    expect(
        requests.last.headers['Authorization'], 'Bearer test-renewed-access');
  });

  test('timer and concurrent requests join the same refresh', () async {
    final store = MemorySessionStore();
    final requests = <RequestOptions>[];
    final started = Completer<void>();
    final rotation = Completer<Map<String, dynamic>>();
    final dio = fakeDio(
      meStatus: 200,
      loginResponse: credentialsResponse(expiresIn: 310),
      record: requests.add,
      rotate: () {
        started.complete();
        return rotation.future;
      },
    );
    final service = AuthService(dio: dio, sessionStore: store);
    final controller = SessionController(authService: service);
    addTearDown(controller.dispose);
    await controller.signInWithGoogle(idToken: 'synthetic-id');
    // The scheduled refresh begins before the two requests.
    await started.future.timeout(const Duration(seconds: 12));
    final pending = Future.wait([
      dio.get('/api/pickups/my'),
      dio.get('/api/pickups/my'),
    ]);
    rotation.complete({
      ...credentialsResponse(user: {'user_id': 'test-user', 'role': 'trader'}),
      'access_token': 'after-renewal',
    });
    await pending;
    expect(requests.where((r) => r.path == '/api/auth/refresh'), hasLength(1));
    expect(requests.last.headers['Authorization'], 'Bearer after-renewal');
    expect(controller.dashboardPath, '/dashboard/trader');
  });

  test('offline refresh preserves the pair but confirmed revocation clears it',
      () async {
    for (final revoked in [false, true]) {
      final store = MemorySessionStore();
      await savePair(store, expired: true);
      final dio = fakeDio(
        meStatus: 200,
        refreshError: revoked
            ? DioExceptionType.badResponse
            : DioExceptionType.connectionError,
        refreshStatus: revoked ? 401 : null,
      );
      final controller = SessionController(
        authService: AuthService(dio: dio, sessionStore: store),
      );
      addTearDown(controller.dispose);
      if (revoked) {
        await controller.restoreSession();
        expect(controller.status, SessionStatus.unauthenticated);
        expect(store.credentials, isNull);
      } else {
        await expectLater(
            controller.restoreSession(), throwsA(isA<DioException>()));
        expect(controller.status, SessionStatus.unavailable);
        expect(store.credentials?.refreshToken, 'test-initial-refresh');
      }
    }
  });

  test('old rotation cannot overwrite a newly signed-in account', () async {
    final store = MemorySessionStore();
    final started = Completer<void>();
    final rotation = Completer<Map<String, dynamic>>();
    final newUser = {'user_id': 'new-user', 'role': 'trader'};
    final dio = fakeDio(
      meStatus: 200,
      user: newUser,
      loginResponse: credentialsResponse(user: newUser),
      rotate: () {
        started.complete();
        return rotation.future;
      },
    );
    await savePair(store, expired: true);
    final controller = SessionController(
      authService: AuthService(dio: dio, sessionStore: store),
    );
    addTearDown(controller.dispose);
    final restoring = controller.restoreSession();
    await started.future;
    await controller.signInWithGoogle(idToken: 'synthetic-id');
    rotation.complete({
      ...credentialsResponse(),
      'access_token': 'discarded-access',
      'refresh_token': 'discarded-refresh',
    });
    await restoring;
    expect(controller.user?['user_id'], 'new-user');
    expect(store.credentials?.refreshToken, 'test-rotated-refresh');
  });

  test('401 retries a read once with a new bearer and never retries a write',
      () async {
    for (final method in ['GET', 'POST']) {
      final store = MemorySessionStore();
      await savePair(store, expired: false);
      final requests = <RequestOptions>[];
      final dio = fakeDio(
        meStatus: 200,
        record: requests.add,
        rotate: () async => credentialsResponse(),
        statusForRequest: (r) =>
            r.headers['Authorization'] == 'Bearer test-renewed-access'
                ? 200
                : 401,
      );
      final controller = SessionController(
        authService: AuthService(dio: dio, sessionStore: store),
      );
      addTearDown(controller.dispose);
      await controller.restoreSession();
      final request =
          dio.request('/api/pickups/my', options: Options(method: method));
      if (method == 'GET') {
        await request;
      } else {
        await expectLater(request, throwsA(isA<DioException>()));
      }
      expect(
          requests.where((r) => r.path == '/api/auth/refresh'), hasLength(1));
      expect(requests.where((r) => r.path == '/api/pickups/my'),
          hasLength(method == 'GET' ? 2 : 1));
    }
  });

  test('an ambiguous refresh timeout is persisted and the token is not reused',
      () async {
    final store = MemorySessionStore();
    await savePair(store, expired: true);
    final requests = <RequestOptions>[];
    final dio = fakeDio(
      meStatus: 200,
      record: requests.add,
      refreshError: DioExceptionType.receiveTimeout,
    );
    final first = SessionController(
      authService: AuthService(dio: dio, sessionStore: store),
    );
    await expectLater(first.restoreSession(), throwsA(isA<DioException>()));
    expect(store.credentials?.refreshOutcomeUncertain, isTrue);
    first.dispose();

    final restarted = SessionController(
      authService: AuthService(dio: dio, sessionStore: store),
    );
    addTearDown(restarted.dispose);
    await restarted.restoreSession();
    expect(restarted.status, SessionStatus.unauthenticated);
    expect(store.credentials?.refreshToken, 'test-initial-refresh');
    expect(requests.where((r) => r.path == '/api/auth/refresh'), hasLength(1));
  });

  test('a temporary profile failure keeps newly issued credentials', () async {
    final store = MemorySessionStore();
    final requests = <RequestOptions>[];
    final dio = fakeDio(
      meStatus: 503,
      loginResponse: credentialsResponse(),
      record: requests.add,
    );
    final controller = SessionController(
      authService: AuthService(dio: dio, sessionStore: store),
    );
    addTearDown(controller.dispose);

    await expectLater(
      controller.signIn(
          mobile: 'synthetic-mobile', password: 'synthetic-password'),
      throwsA(isA<DioException>()),
    );
    expect(controller.status, SessionStatus.unavailable);
    expect(store.credentials?.refreshToken, 'test-rotated-refresh');
    expect(requests.map((r) => r.path), ['/api/auth/login', '/api/auth/me']);
  });

  test('split credentials require an account check before refresh', () async {
    final store = MemorySessionStore()
      ..credentials = SessionCredentials(
        'legacy-access',
        refreshToken: 'legacy-refresh',
        accessExpiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        requiresAccountVerification: true,
      );
    final requests = <RequestOptions>[];
    final dio = fakeDio(meStatus: 401, record: requests.add);
    final controller = SessionController(
      authService: AuthService(dio: dio, sessionStore: store),
    );
    addTearDown(controller.dispose);

    await controller.restoreSession();
    expect(controller.status, SessionStatus.unauthenticated);
    expect(store.credentials, isNull);
    expect(requests.map((r) => r.path), ['/api/auth/me']);
  });

  test('a migrated split pair cannot renew into another account', () async {
    final store = MemorySessionStore()
      ..credentials = SessionCredentials(
        'legacy-access',
        refreshToken: 'legacy-refresh',
        accessExpiresAt: DateTime.now().add(const Duration(hours: 1)),
        requiresAccountVerification: true,
      );
    final dio = fakeDio(
      meStatus: 200,
      rotate: () async => credentialsResponse(
        user: {'user_id': 'other-user', 'role': 'trader'},
      ),
    );
    final service = AuthService(dio: dio, sessionStore: store);
    final controller = SessionController(authService: service);
    addTearDown(controller.dispose);

    await controller.restoreSession();
    expect(store.credentials?.userId, 'test-user');
    await expectLater(service.refreshSession(), throwsStateError);
    expect(controller.status, SessionStatus.unauthenticated);
    expect(store.credentials, isNull);
  });

  test('the shared monitor does not attach a bearer to a different origin',
      () async {
    final store = MemorySessionStore();
    await savePair(store, expired: false);
    final requests = <RequestOptions>[];
    final dio = fakeDio(meStatus: 200, record: requests.add);
    final controller = SessionController(
      authService: AuthService(dio: dio, sessionStore: store),
    );
    addTearDown(controller.dispose);

    await controller.restoreSession();
    await dio.get('https://different.invalid/api/pickups/my');
    expect(requests.last.headers['Authorization'], isNull);
  });
}

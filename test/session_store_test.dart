import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrapwise/features/auth/services/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const accessKey = 'scrapwise_access_token';
  const refreshKey = 'scrapwise_refresh_token';
  const expiryKey = 'scrapwise_access_expires_at';
  const storage = FlutterSecureStorage();
  final expiry = DateTime.utc(2030);

  test('upgrades an access-only record without inventing a refresh token',
      () async {
    FlutterSecureStorage.setMockInitialValues({accessKey: 'legacy-access'});
    final value = await SessionStore(storage: storage).readSession();
    expect(value?.accessToken, 'legacy-access');
    expect(value?.refreshToken, isNull);
    final stored = jsonDecode((await storage.read(key: accessKey))!);
    expect(stored['access'], 'legacy-access');
  });

  test('migrates identity split keys and rotates the whole record', () async {
    FlutterSecureStorage.setMockInitialValues({
      accessKey: 'old-access',
      refreshKey: 'old-refresh',
      expiryKey: expiry.toIso8601String(),
    });
    final store = SessionStore(storage: storage);
    expect((await store.readSession())?.refreshToken, 'old-refresh');
    expect(await storage.read(key: refreshKey), isNull);
    expect(await storage.read(key: expiryKey), isNull);
    await store.saveSession(SessionCredentials('next-access',
        refreshToken: 'next-refresh', accessExpiresAt: expiry));
    expect(await storage.readAll(), {
      accessKey: jsonEncode({
        'access': 'next-access',
        'refresh': 'next-refresh',
        'expires': expiry.toIso8601String(),
      }),
    });
  });

  test('reads hardening pairs and rejects partial or malformed data', () async {
    final store = SessionStore(storage: storage);
    FlutterSecureStorage.setMockInitialValues({
      accessKey: jsonEncode({
        'access': 'pair-access',
        'refresh': 'pair-refresh',
        'expires': expiry.toIso8601String(),
      }),
    });
    expect((await store.readSession())?.accessExpiresAt, expiry);
    for (final values in [
      {accessKey: 'orphan-access', refreshKey: 'orphan-refresh'},
      {accessKey: '{invalid', refreshKey: 'ignored-refresh'},
      {accessKey: '{"access":"bad access","refresh":null,"expires":null}'},
      {
        accessKey:
            '{"access":"pair-access","refresh":"pair-refresh","expires":42}'
      },
    ]) {
      FlutterSecureStorage.setMockInitialValues(values);
      expect(await store.readSession(), isNull);
    }
  });
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _tokenKey = 'scrapwise_access_token';

  final FlutterSecureStorage _storage;

  Future<void> save(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> read() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
  }
}

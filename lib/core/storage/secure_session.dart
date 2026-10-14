import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'session_store.dart';
export 'session_store.dart';

/// Uses the existing versioned backend session format, not a second auth store.
class SecureSessionStorage extends SecureSessionStore {
  const SecureSessionStorage({super.storage});
}

class SecurePkceStorage {
  const SecurePkceStorage(
      {FlutterSecureStorage storage = const FlutterSecureStorage()})
      : _storage = storage;
  final FlutterSecureStorage _storage;
  String _key(String key) {
    if (key.isEmpty || key.length > 200) {
      throw ArgumentError('Invalid PKCE storage key.');
    }
    return 'movetraq.pkce.$key';
  }

  Future<String?> getItem({required String key}) =>
      _storage.read(key: _key(key));
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: _key(key), value: value);
  Future<void> removeItem({required String key}) =>
      _storage.delete(key: _key(key));
}

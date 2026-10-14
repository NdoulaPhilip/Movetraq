import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/models/production_session.dart';

abstract interface class SessionStore {
  Future<ProductionSession?> read();
  Future<void> write(ProductionSession session);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  const SecureSessionStore(
      {FlutterSecureStorage storage = const FlutterSecureStorage()})
      : _storage = storage;
  final FlutterSecureStorage _storage;
  static const _key = 'movetraq.production.session.v1';
  @override
  Future<ProductionSession?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    try {
      return ProductionSession.fromJson(
          Map<String, dynamic>.from(jsonDecode(value) as Map));
    } on FormatException {
      await clear();
      return null;
    } on TypeError {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(ProductionSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

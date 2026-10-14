import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ReadCache {
  ReadCache(
      {FlutterSecureStorage storage = const FlutterSecureStorage(),
      DateTime Function()? clock})
      : _storage = storage,
        _clock = clock ?? DateTime.now;
  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;
  final _queues = <String, Future<void>>{};
  static const prefix = 'movetraq.cache.v2.';
  static const maximumBytes = 200000;
  static const lifetime = Duration(days: 1);
  // Financial balances, payment state, delivery eligibility and auth are never served offline.
  bool supports(String path) =>
      const ['/users/me/preferences', '/users/me/addresses'].contains(path);
  String _userPrefix(String user) {
    if (user.isEmpty || user.length > 128) {
      throw ArgumentError('A cache owner is required.');
    }
    return '$prefix${base64Url.encode(utf8.encode(user))}.';
  }

  String key(String user, String path) =>
      '${_userPrefix(user)}${base64Url.encode(utf8.encode(path))}';
  Future<T> _locked<T>(String user, Future<T> Function() action) {
    final result =
        (_queues[user] ?? Future<void>.value()).then((_) => action());
    _queues[user] =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> write(String user, String path, Map<String, dynamic> data) =>
      _locked(user, () async {
        if (!supports(path)) return;
        final encoded = jsonEncode(
            {'saved_at': _clock().toUtc().toIso8601String(), 'data': data});
        if (utf8.encode(encoded).length > maximumBytes) return;
        await _storage.write(key: key(user, path), value: encoded);
      });
  Future<Map<String, dynamic>?> read(String user, String path) =>
      _locked(user, () async {
        if (!supports(path)) return null;
        final storageKey = key(user, path);
        final encoded = await _storage.read(key: storageKey);
        if (encoded == null) return null;
        try {
          if (utf8.encode(encoded).length > maximumBytes) {
            throw const FormatException();
          }
          final record = jsonDecode(encoded) as Map<String, dynamic>;
          final saved = DateTime.parse(record['saved_at'] as String);
          final age = _clock().toUtc().difference(saved);
          if (age.isNegative || age > lifetime) throw const FormatException();
          return Map<String, dynamic>.from(record['data'] as Map);
        } on FormatException {
          await _storage.delete(key: storageKey);
          return null;
        } on TypeError {
          await _storage.delete(key: storageKey);
          return null;
        }
      });
  Future<void> clearUser(String user) => _locked(user, () async {
        final ownerPrefix = _userPrefix(user);
        final all = await _storage.readAll();
        for (final storageKey
            in all.keys.where((key) => key.startsWith(ownerPrefix)).toList()) {
          await _storage.delete(key: storageKey);
        }
      });
}

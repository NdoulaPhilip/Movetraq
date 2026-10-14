import 'package:flutter/foundation.dart';
import '../../features/auth/repositories/production_auth_repository.dart';
import '../storage/cache.dart';
import 'production_api.dart';
export 'production_api.dart' show ProductionApiError;

class ApiClient {
  ApiClient(this.auth, {ReadCache? cache}) : cache = cache ?? ReadCache();
  final ProductionAuthRepository auth;
  final ReadCache cache;
  final offline = ValueNotifier(false);
  bool _disposed = false;
  bool _cacheReadable = true;
  Future<Map<String, dynamic>> request(String path,
      {String method = 'GET', Map<String, dynamic>? data, String? key}) async {
    if (_disposed) throw StateError('API client is disposed.');
    ProductionApi.validatePath(path);
    final verb = method.toUpperCase();
    if (!const ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'].contains(verb)) {
      throw ArgumentError('Unsupported request method.');
    }
    final user = auth.userId;
    if (user == null) {
      throw const ProductionApiError('SESSION_REQUIRED', 'Please sign in.');
    }
    try {
      final result = await auth.authenticatedRequest(verb, path,
          body: data, idempotencyKey: key);
      _checkOwner(user);
      offline.value = false;
      if (verb == 'GET' && cache.supports(path)) {
        try {
          await cache.write(user, path, result);
        } catch (_) {/* Server reads remain valid if local caching fails. */}
      } else if (verb != 'GET') {
        try {
          await cache.clearUser(user);
        } catch (_) {
          _cacheReadable = false;
        }
      }
      _checkOwner(user);
      return result;
    } on ProductionApiError catch (error) {
      _checkOwner(user);
      if (error.code == 'NETWORK_UNAVAILABLE') {
        offline.value = true;
        if (verb == 'GET' && _cacheReadable) {
          Map<String, dynamic>? cached;
          try {
            cached = await cache.read(user, path);
          } catch (_) {
            cached = null;
          }
          _checkOwner(user);
          if (cached != null) return cached;
        }
      }
      rethrow;
    }
  }

  void _checkOwner(String user) {
    if (_disposed || auth.userId != user) {
      throw const ProductionApiError(
          'SESSION_CHANGED', 'Your account changed. Please try again.');
    }
  }

  Future<void> signOut() async {
    final user = auth.userId;
    try {
      await auth.signOut();
    } finally {
      if (user != null) await cache.clearUser(user);
    }
  }

  void dispose() {
    if (!_disposed) {
      _disposed = true;
      offline.dispose();
    }
  }
}

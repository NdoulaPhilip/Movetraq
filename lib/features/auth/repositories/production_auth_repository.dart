import 'dart:async';
import '../../../core/networking/production_api.dart';
import '../../../core/storage/session_store.dart';
import '../models/production_session.dart';

class ProductionAuthRepository {
  ProductionAuthRepository(
      {required ProductionApi api,
      required SessionStore store,
      DateTime Function()? clock})
      : _api = api,
        _store = store,
        _clock = clock ?? DateTime.now;
  final ProductionApi _api;
  final SessionStore _store;
  final DateTime Function() _clock;
  ProductionSession? _session;
  String? _userId;
  String? get userId => _userId;
  Future<void> _queue = Future.value();

  // Serialize credential rotation and logout so late responses cannot restore a
  // revoked session or overwrite a newer refresh token in secure storage.
  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<ProductionAccount> _establish(Map<String, dynamic> result) async {
    final session = ProductionSession.fromJson(
        Map<String, dynamic>.from(result['session'] as Map));
    final account = ProductionAccount.fromJson(
        Map<String, dynamic>.from(result['user'] as Map));
    await _store.write(session);
    _session = session;
    _userId = account.id;
    return account;
  }

  Future<ProductionAccount> signIn(String emailOrPhone, String password) =>
      _locked(() async => _establish(await _api.request('POST', '/auth/signin',
          body: {'emailOrPhone': emailOrPhone.trim(), 'password': password})));

  /// Null means signup succeeded but email confirmation is required, not login.
  Future<ProductionAccount?> signUp(
          {required String name,
          required String email,
          required String password,
          String? phone}) =>
      _locked(() async {
        final result = await _api.request('POST', '/auth/signup', body: {
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim()
        });
        if (result['requiresEmailConfirmation'] == true) {
          _session = null;
          _userId = null;
          await _store.clear();
          return null;
        }
        return _establish(result);
      });

  Future<ProductionAccount> verify(String email, String code,
          {bool recovery = false}) =>
      _locked(() async =>
          _establish(await _api.request('POST', '/auth/verify', body: {
            'email': email.trim(),
            'token': code.trim(),
            'type': recovery ? 'recovery' : 'signup'
          })));

  Future<void> recover(String email) async {
    await _api.request('POST', '/auth/recover', body: {'email': email.trim()});
  }

  Future<void> _refresh() async {
    final session = _session;
    if (session == null) {
      throw const ProductionApiError('SESSION_REQUIRED', 'Please sign in.');
    }
    try {
      await _establish(await _api.request('POST', '/auth/refresh',
          body: {'refreshToken': session.refreshToken}));
    } on ProductionApiError catch (error) {
      if (error.status == 401 || error.code == 'INVALID_SESSION') {
        _session = null;
        _userId = null;
        await _store.clear();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _authorized(String method, String path,
      {Map<String, dynamic>? body, String? idempotencyKey}) async {
    if (_session == null) {
      throw const ProductionApiError('SESSION_REQUIRED', 'Please sign in.');
    }
    if (_session!.expiresAt <= _clock().millisecondsSinceEpoch ~/ 1000 + 30) {
      await _refresh();
    }
    try {
      return await _api.request(method, path,
          body: body,
          token: _session!.accessToken,
          idempotencyKey: idempotencyKey);
    } on ProductionApiError catch (error) {
      if (error.status != 401) rethrow;
      await _refresh();
      try {
        return await _api.request(method, path,
            body: body,
            token: _session!.accessToken,
            idempotencyKey: idempotencyKey);
      } on ProductionApiError catch (retryError) {
        if (retryError.status == 401) {
          _session = null;
          _userId = null;
          await _store.clear();
        }
        rethrow;
      }
    }
  }

  Future<ProductionAccount?> restore() => _locked(() async {
        _session = await _store.read();
        _userId = null;
        if (_session == null) return null;
        try {
          final response = await _authorized('GET', '/users/me');
          final account = ProductionAccount.fromJson(
              Map<String, dynamic>.from(response['user'] as Map));
          _userId = account.id;
          return account;
        } on ProductionApiError catch (error) {
          if (error.status == 401 || error.code == 'INVALID_SESSION') {
            return null;
          }
          // Temporary network errors retain secure credentials for a later retry.
          rethrow;
        }
      });

  Future<void> changePassword(String password) => _locked(() async {
        await _authorized('POST', '/auth/password',
            body: {'password': password});
      });

  Future<Map<String, dynamic>> authenticatedRequest(String method, String path,
          {Map<String, dynamic>? body, String? idempotencyKey}) =>
      _locked(() => _authorized(method, path,
          body: body, idempotencyKey: idempotencyKey));

  Future<void> signOut() => _locked(() async {
        final session = _session;
        _session = null;
        _userId = null;
        await _store.clear();
        if (session == null) return;
        await _api.request('POST', '/auth/logout', token: session.accessToken);
      });
}

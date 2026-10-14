import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

enum PushStatus {
  disabled,
  notConfigured,
  permissionDenied,
  apnsPending,
  active,
  failed
}

abstract interface class PushTransport {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<String?> token();
  Stream<String> get tokenChanges;
  Future<void> deleteToken();
}

@pragma('vm:entry-point')
Future<void> onBackgroundPush(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class FirebasePushTransport implements PushTransport {
  @override
  Future<void> initialize() async {
    if (kIsWeb ||
        ![TargetPlatform.android, TargetPlatform.iOS]
            .contains(defaultTargetPlatform)) {
      throw UnsupportedError('Push is configured for Android and iOS only.');
    }
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(onBackgroundPush);
  }

  @override
  Future<bool> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    final permitted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (permitted) await FirebaseMessaging.instance.setAutoInitEnabled(true);
    return permitted;
  }

  @override
  Future<String?> token() async {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await FirebaseMessaging.instance.getAPNSToken() == null) {
      return null;
    }
    return FirebaseMessaging.instance.getToken();
  }

  @override
  Stream<String> get tokenChanges => FirebaseMessaging.instance.onTokenRefresh;
  @override
  Future<void> deleteToken() async {
    await FirebaseMessaging.instance.setAutoInitEnabled(false);
    await FirebaseMessaging.instance.deleteToken();
  }
}

typedef PushRegistration = Future<void> Function(String userId, String token);

class PushService extends ChangeNotifier {
  PushService(
      {required this.enabled,
      required this.userId,
      this.registerDevice,
      this.unregisterDevice,
      PushTransport? transport})
      : _transport = transport ?? FirebasePushTransport();
  final bool enabled;
  final String? Function() userId;
  final PushRegistration? registerDevice, unregisterDevice;
  final PushTransport _transport;
  PushStatus status = PushStatus.disabled;
  StreamSubscription<String>? _subscription;
  Future<PushStatus>? _starting;
  Future<void> _registrations = Future.value();
  String? _owner, _registeredToken;
  bool _disposed = false;
  int _generation = 0;
  void _status(PushStatus value) {
    if (!_disposed) {
      status = value;
      notifyListeners();
    }
  }

  Future<PushStatus> start() {
    if (_disposed) throw StateError('Push service is disposed.');
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<PushStatus> _start() async {
    if (!enabled) {
      _status(PushStatus.disabled);
      return status;
    }
    if (registerDevice == null ||
        unregisterDevice == null ||
        userId() == null) {
      _status(PushStatus.notConfigured);
      return status;
    }
    final owner = userId()!;
    final generation = ++_generation;
    await _subscription?.cancel();
    _subscription = null;
    _owner = owner;
    bool current() =>
        !_disposed && generation == _generation && userId() == owner;
    try {
      await _transport.initialize();
      if (!current()) return status;
      final permitted = await _transport.requestPermission();
      if (!current()) return status;
      if (!permitted) {
        _status(PushStatus.permissionDenied);
        return status;
      }
      if (!current()) return status;
      final token = await _transport.token();
      if (!current()) return status;
      if (token == null || token.isEmpty) {
        _status(PushStatus.apnsPending);
        return status;
      }
      _registeredToken = token;
      await registerDevice!(owner, token);
      if (!current()) return status;
      _registeredToken = token;
      _status(PushStatus.active);
      _subscription = _transport.tokenChanges.listen((value) {
        _registrations = _registrations.then((_) async {
          if (!current() || value.isEmpty) return;
          try {
            await registerDevice!(owner, value);
            if (current()) {
              _registeredToken = value;
              _status(PushStatus.active);
            }
          } catch (_) {
            if (current()) _status(PushStatus.failed);
          }
        });
      }, onError: (Object _) {
        if (current()) _status(PushStatus.failed);
      });
    } catch (_) {
      if (current()) _status(PushStatus.failed);
    }
    return status;
  }

  /// Call before auth logout; a device registration must be removed while authorized.
  Future<void> unregister() async {
    ++_generation;
    await _subscription?.cancel();
    _subscription = null;
    await _starting;
    await _registrations;
    final owner = _owner, token = _registeredToken;
    if (owner != null && token != null) {
      if (unregisterDevice == null || userId() != owner) {
        throw StateError('Sign in to remove this device registration.');
      }
      await unregisterDevice!(owner, token);
      await _transport.deleteToken();
    }
    _registeredToken = null;
    _owner = null;
    _status(PushStatus.disabled);
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _subscription?.cancel();
    super.dispose();
  }
}

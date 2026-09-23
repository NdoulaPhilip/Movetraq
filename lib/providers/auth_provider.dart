import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/local_data_service.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthProvider extends ChangeNotifier {
  final LocalDataService _data;

  AuthProvider(this._data) {
    _authSub = _data.authStateChanges.listen(_onAuthChanged);
    // No stored session in this local-only build, so start signed out.
    status = AuthStatus.signedOut;
  }

  AuthStatus status = AuthStatus.unknown;
  AppUser? profile;
  String? errorMessage;
  bool isBusy = false;

  StreamSubscription<AppUser?>? _authSub;
  StreamSubscription<AppUser?>? _profileSub;

  void _onAuthChanged(AppUser? user) {
    _profileSub?.cancel();
    if (user == null) {
      status = AuthStatus.signedOut;
      profile = null;
      notifyListeners();
      return;
    }
    status = AuthStatus.signedIn;
    _profileSub = _data.profileStream(user.uid).listen((p) {
      profile = p;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<bool> _guard(Future<void> Function() action) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      isBusy = false;
      notifyListeners();
      return true;
    } catch (e) {
      isBusy = false;
      errorMessage = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  String _friendlyError(Object e) {
    final message = e.toString().replaceFirst('StateError: ', '').replaceFirst('Exception: ', '');
    return message.isEmpty ? 'Something went wrong. Please try again.' : message;
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) {
    return _guard(() async {
      await _data.signUp(name: name, email: email, phone: phone, password: password);
    });
  }

  Future<bool> signIn({required String emailOrPhone, required String password}) {
    return _guard(() async {
      await _data.signIn(emailOrPhone: emailOrPhone, password: password);
    });
  }

  Future<bool> resetPassword({
    required String emailOrPhone,
    required String newPassword,
  }) {
    return _guard(() async {
      await _data.resetPassword(
        emailOrPhone: emailOrPhone,
        newPassword: newPassword,
      );
    });
  }

  Future<bool> toggleRole() {
    return _guard(() async {
      if (profile == null) return;
      final next = profile!.activeRole == UserRole.sender
          ? UserRole.deliverer
          : UserRole.sender;
      await _data.updateRole(profile!.uid, next);
    });
  }

  Future<bool> setDelivererOnline(bool online) {
    return _guard(() async {
      if (profile == null) return;
      await _data.setDelivererOnline(profile!.uid, online);
    });
  }

  Future<void> signOut() => _data.signOut();

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}

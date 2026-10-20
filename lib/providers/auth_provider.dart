import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/app_user.dart';
import '../services/local_data_service.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthProvider extends ChangeNotifier with WidgetsBindingObserver {
  final LocalDataService _data;

  AuthProvider(this._data) {
    WidgetsBinding.instance.addObserver(this);
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
  Timer? _approvalTimer;
  bool _checkingApproval = false;
  bool _disposed = false;
  String? approvalErrorMessage;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refreshApproval());
  }

  Future<void> refreshApproval() async {
    if (_checkingApproval || profile == null) return;
    final owner = profile!.uid;
    _checkingApproval = true;
    try {
      await _data.delivererAccess();
      if (!_disposed && profile?.uid == owner) {
        approvalErrorMessage = null;
        notifyListeners();
      }
    } catch (error) {
      if (!_disposed && profile?.uid == owner) {
        approvalErrorMessage = _friendlyError(error);
        profile = profile!.copyWith(
            canDeliver: false,
            verified: false,
            delivererVerificationStatus: 'unavailable',
            activeRole: UserRole.sender);
        notifyListeners();
      }
    } finally {
      _checkingApproval = false;
    }
  }

  void _onAuthChanged(AppUser? user) {
    if (user != null &&
        profile?.uid == user.uid &&
        status == AuthStatus.signedIn) {
      profile = user;
      notifyListeners();
      return;
    }
    _approvalTimer?.cancel();
    _profileSub?.cancel();
    if (user == null) {
      status = AuthStatus.signedOut;
      profile = null;
      approvalErrorMessage = null;
      notifyListeners();
      return;
    }
    status = AuthStatus.signedIn;
    profile = user;
    approvalErrorMessage = null;
    _approvalTimer =
        Timer.periodic(const Duration(seconds: 20), (_) => refreshApproval());
    _profileSub = _data.profileStream(user.uid).listen((p) {
      profile = p;
      notifyListeners();
    });
    notifyListeners();
    unawaited(refreshApproval());
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
    final message = e
        .toString()
        .replaceFirst('StateError: ', '')
        .replaceFirst('Exception: ', '');
    return message.isEmpty
        ? 'Something went wrong. Please try again.'
        : message;
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) {
    return _guard(() async {
      await _data.signUp(
          name: name, email: email, phone: phone, password: password);
    });
  }

  Future<bool> signIn(
      {required String emailOrPhone, required String password}) {
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
      if (next == UserRole.deliverer) {
        await _data.delivererAccess();
        if (_data.currentUser?.isApprovedDeliverer != true) {
          throw StateError(
              'Administrator approval is required for delivery work.');
        }
      }
      await _data.updateRole(profile!.uid, next);
    });
  }

  Future<bool> updateProfile({
    required String name,
    required String phone,
  }) {
    return _guard(() async {
      if (profile == null) return;
      await _data.updateProfile(
        uid: profile!.uid,
        name: name,
        phone: phone,
      );
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
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _profileSub?.cancel();
    _approvalTimer?.cancel();
    super.dispose();
  }
}

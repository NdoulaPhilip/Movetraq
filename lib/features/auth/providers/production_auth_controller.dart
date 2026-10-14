import 'package:flutter/foundation.dart';

import '../../../core/networking/production_api.dart';
import '../models/production_session.dart';
import '../repositories/production_auth_repository.dart';

enum ProductionAuthStatus {
  unknown,
  signedOut,
  signedIn,
  emailConfirmationRequired,
  recoveryCodeRequired,
  passwordChangeRequired,
}

/// UI state contains account data only; credentials stay in the repository.
class ProductionAuthController extends ChangeNotifier {
  ProductionAuthController(this._repository);

  final ProductionAuthRepository _repository;
  ProductionAuthStatus status = ProductionAuthStatus.unknown;
  ProductionAccount? account;
  String? pendingEmail;
  String? errorMessage;
  bool isBusy = false;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (isBusy || _disposed) return false;
    isBusy = true;
    errorMessage = null;
    _notify();
    try {
      await action();
      return true;
    } on ProductionApiError catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'Unable to complete this request. Please try again.';
      return false;
    } finally {
      isBusy = false;
      _notify();
    }
  }

  Future<bool> restore() => _run(() async {
        account = await _repository.restore();
        status = account == null
            ? ProductionAuthStatus.signedOut
            : ProductionAuthStatus.signedIn;
      });

  Future<bool> signIn(String email, String password) => _run(() async {
        account = await _repository.signIn(email, password);
        pendingEmail = null;
        status = ProductionAuthStatus.signedIn;
      });

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) =>
      _run(() async {
        account = await _repository.signUp(
            name: name, email: email, password: password, phone: phone);
        pendingEmail = account == null ? email.trim() : null;
        status = account == null
            ? ProductionAuthStatus.emailConfirmationRequired
            : ProductionAuthStatus.signedIn;
      });

  Future<bool> requestRecovery(String email) => _run(() async {
        await _repository.recover(email);
        pendingEmail = email.trim();
        status = ProductionAuthStatus.recoveryCodeRequired;
      });

  Future<bool> verifyCode(String code) => _run(() async {
        final email = pendingEmail;
        final recovery = status == ProductionAuthStatus.recoveryCodeRequired;
        if (email == null ||
            (!recovery &&
                status != ProductionAuthStatus.emailConfirmationRequired)) {
          throw const ProductionApiError(
              'VERIFICATION_REQUIRED', 'Request a verification code first.');
        }
        account = await _repository.verify(email, code, recovery: recovery);
        pendingEmail = null;
        status = recovery
            ? ProductionAuthStatus.passwordChangeRequired
            : ProductionAuthStatus.signedIn;
      });

  Future<bool> changeRecoveredPassword(String password) => _run(() async {
        if (status != ProductionAuthStatus.passwordChangeRequired) {
          throw const ProductionApiError(
              'RECOVERY_REQUIRED', 'Verify your recovery code first.');
        }
        await _repository.changePassword(password);
        status = ProductionAuthStatus.signedIn;
      });

  Future<bool> signOut() => _run(() async {
        // Local sign-out remains effective even if remote revocation fails.
        try {
          await _repository.signOut();
        } finally {
          account = null;
          pendingEmail = null;
          status = ProductionAuthStatus.signedOut;
        }
      });

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

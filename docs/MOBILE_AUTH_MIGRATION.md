# Mobile Production Authentication

This increment implements the new backend's authentication contracts separately
from the legacy mobile client. It does not change the production API URL or route
existing screens to an incompatible backend.

## Implemented

- `lib/core/networking/production_api.dart`: Dio transport with timeouts,
  consistent error envelopes, no request/credential logging, HTTPS enforcement
  for nonlocal endpoints and release builds, and disabled redirects. Callers
  cannot substitute absolute or protocol-relative request URLs.
- `lib/core/storage/session_store.dart`: platform secure storage containing one
  versioned session record, including rotating access/refresh tokens and expiry.
  Malformed records are removed. Storage errors are not silently ignored.
- `lib/features/auth/models/production_session.dart`: separate production
  account/session models preserving server roles and integer minor-unit money.
- `lib/features/auth/repositories/production_auth_repository.dart`: signup,
  password signin, signup/recovery OTP verification, recovery initiation,
  authenticated password change, session restoration, token rotation and logout.
  Confirmation-required signup does not invent a signed-in account. Restoration
  checks the real backend profile before returning an account.
- Auth operations serialize credential writes, refresh and logout. Failed auth
  does not poison the operation queue. A late signin/refresh cannot overwrite a
  completed logout. Unauthorized requests refresh once and retry once; a second
  401 clears the session. Network failures are not automatically replayed and
  retain saved credentials for explicit retry. Logout clears local credentials
  even if remote revocation subsequently fails, and propagates that failure.
- Android application backups are disabled as required for secure token storage.
- `lib/features/auth/providers/production_auth_controller.dart`: UI-facing
  authentication state for session restoration, signup confirmation, recovery
  code verification, password change and logout. Credentials never enter the
  controller. Duplicate submissions are rejected while busy; disposed
  controllers do not notify listeners after asynchronous responses. Failures
  are displayed as safe API messages without exposing internal exceptions.

## Verification

`flutter analyze --no-pub lib test` and `flutter test --no-pub`.

Tests use a test-only Dio adapter and secure-storage mock, not a fake production
provider. They verify contracts, token rotation, expiry, repeated 401, concurrent
restoration, logout races, confirmation-required signup, network errors, role
denial, exact monetary representation, recovery and cross-origin rejection.
Secure-storage round-trip, deletion and corrupt-record cleanup are also covered.
Controller tests additionally cover confirmation navigation states, recovery
guards, failed remote logout, duplicate submissions and disposal during signin.
Native Android/iOS secure-storage behavior still requires device verification.

## Remaining Integration

Existing `AuthProvider`, `LocalDataService` and `NodeApiClient` still serve the
legacy UI. Next connect the existing authentication screens and their verification
and recovery routes to the new production controller, then migrate profile, booking,
orders, wallet and delivery contracts. Do not pass new Supabase credentials to
the legacy server or toggle the extended gateway as a substitute for migration.
Riverpod/Bloc state management, GoRouter navigation, OAuth/deep links, realtime
subscriptions and the complete device delivery journey remain release work.
There is no iOS project in this checkout; adding the package is not iOS setup.

The hosted project now responds to read-only checks through the backend SDK,
and an admin role exists. Local API health, admin HTML and CORS checks succeeded.
The user reports all migrations applied. Actual admin signin, mobile signin,
hosted provider integrations and the full migration acceptance audit have not
been verified; the platform is not production-ready.

## Package References

- [Dio](https://pub.dev/packages/dio)
- [Flutter secure storage](https://pub.dev/packages/flutter_secure_storage)

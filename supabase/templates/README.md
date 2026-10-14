# Signup confirmation email

In Supabase Authentication → Email Templates → Confirm signup, set the subject to `Your MoveTraq confirmation code` and the body to `confirmation.html` from this folder.

The app verifies `{{ .Token }}` with the email address using `verifyOTP(type: signup)`. This avoids requiring an email browser on the same device as the app. OAuth and password recovery still use `movetraq://auth/callback`, which must remain on the redirect allowlist.

## Temporary preview without SMTP

The user has chosen to temporarily disable signup confirmation until email delivery is ready. In hosted Supabase, open Authentication → Sign In / Providers → Email, turn **Confirm email** off, and save. Keep email/password sign-in enabled. This setting must be changed on Supabase; uploading code does not change it.

The app uses the actual signup response: a session opens Home immediately, while no session opens the existing verification screen. There is no client-side authentication bypass or privileged credential embedded in the app. Existing unconfirmed accounts may still need confirmation by an administrator or a fresh test account.

Configure SMTP and turn **Confirm email** back on before public registration. The code/template remain available; no rebuild is required to restore verification. Password-reset emails still require email delivery even while signup confirmation is off.

After saving, resend from the app and test with a fresh email; emails already sent do not change. Never paste confirmation codes or links into logs.

Reference: https://supabase.com/docs/guides/auth/auth-email-templates

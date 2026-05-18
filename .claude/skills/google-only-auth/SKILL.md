---
name: google-only-auth
description: Auth is Google OAuth only. Refuse to add email/password / magic-link / OTP flows. Triggered when adding auth UI or flows.
---

# Google OAuth only

The user has confirmed this in their saved memory: one "Continue with
Google" button. Period.

## Forbidden

- Email + password sign-in
- Email magic links
- Phone / SMS OTP
- Supabase's `signInWithOtp`, `signInWithPassword`, etc.
- Sign-up / register pages with name + email + password

## The single sign-in path

```dart
await Supabase.instance.client.auth.signInWithOAuth(
  OAuthProvider.google,
  redirectTo: kIsWeb ? null : 'com.jardine.differentworld://login-callback',
);
```

Mobile uses the custom scheme; web relies on Supabase's `detectSessionInUri`
default to parse the OAuth code from the URL on app boot.

## Why

- Childcare staff demographic is mostly familiar with Google accounts
  (Gmail addresses are universal)
- Eliminates password reset support burden
- Eliminates email deliverability problems
- Defers identity verification to Google's better infrastructure

## The login screen

`lib/features/auth/login_screen.dart` has exactly one button. Adding
a second auth method without explicit user request is an instant revert.

## If they ask for Apple / Microsoft / etc later

That's a real product decision — add it as a separate provider button
in the same screen, share the redirect plumbing, keep email/password
out.

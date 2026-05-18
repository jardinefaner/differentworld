---
name: deep-link-test
description: Fire a test deep link at the Pixel via adb. Use to verify invite redemption / route handling without scanning a QR.
---

# /deep-link-test — adb-injected deep link

The custom scheme handler. Tests both onboarding flow and route handling.

```bash
adb -s adb-1A291FDF6002RQ-JYcM2v._adb-tls-connect._tcp shell am start \
  -W -a android.intent.action.VIEW \
  -d "differentworld://invite/TESTAB" \
  com.jardine.differentworld
```

## Replace `TESTAB` with

- A real pending invite code from `supabase.invites.code` (joins the
  signed-in user to that program)
- `TESTAB` (unknown code) to verify the "couldn't find that invite"
  fallback path

## What you should see

`I/flutter (NNNN): [deeplink] received: differentworld://invite/TESTAB`

Then the app behavior depends on auth + space state:
- **Signed out** — code stashes in `pendingInviteCodeProvider`,
  surfaces after sign-in
- **Signed in, no space** — auto-redeems via the JoinOrCreateScreen
  effect
- **Signed in, has space** — refuses with snackbar (per the
  `_SignedInHome` ref.listen)

## https form

```bash
adb -s adb-1A291FDF6002RQ-JYcM2v._adb-tls-connect._tcp shell am start \
  -W -a android.intent.action.VIEW \
  -d "https://differentworld.app/invite/TESTAB" \
  com.jardine.differentworld
```

The Android https intent-filter is `autoVerify="false"` because we
don't own the domain yet. On a real tap from outside the app, Android
shows an "Open with" chooser. From adb the explicit package name
forces the app to receive it.

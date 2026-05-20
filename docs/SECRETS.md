# Secrets in Different World

How API keys + sensitive config are handled now, and how they NEED
to be handled before external rollout.

## What's a "secret" here

| Value | Class | Where it lives today |
|---|---|---|
| Supabase URL | **Public config** | `.env` → compiled into app |
| Supabase publishable / anon key | **Public config** | `.env` → compiled into app |
| PowerSync URL | **Public config** | `.env` → compiled into app |
| User session JWT (per signed-in user) | **Secret, per-user** | `flutter_secure_storage` via supabase_flutter |
| Service-role key (Supabase admin) | **High-value secret** | **NEVER on device** — server-only |
| Deepgram master API key | **Billable shared secret** | `.env` → compiled into app ⚠️ |
| OpenAI master API key | **Billable shared secret** | `.env` → compiled into app ⚠️ |
| Sentry DSN | **Public config** | `.env` → compiled into app |

"Public config" is fine in the binary — Row-Level Security is what
protects data, not the URL or anon key. Same with Sentry DSN (publicly
identifies your project but doesn't grant data access).

**Public config**'s threat model: an attacker who extracts the binary
learns nothing useful — they could already learn the same from
inspecting network traffic.

**Billable shared secrets** are different. A leaked Deepgram or OpenAI
key lets an attacker burn your account's credit at will.

## Why `.env` (via flutter_dotenv) is "semi-secure" at best

The `.env` file is loaded at app startup and read via
`flutter_dotenv`. It's NOT compile-time — the file is embedded as an
**asset** (`pubspec.yaml`'s `flutter.assets`). Anyone who unzips the
APK / IPA and reads `assets/.env` sees the plaintext key.

Alternatives we considered and why they're NOT meaningfully more
secure:

- **`--dart-define` at build time**: bakes the key into compiled
  Dart constants. Still recoverable from the binary via a decompiler
  (Dart bytecode is straightforward to disassemble).
- **`flutter_secure_storage`**: encrypts the key in the OS Keychain /
  Keystore. BUT to get the key INTO secure storage, you have to
  either ship it with the app (back to square one) or download it
  on first launch (now the network endpoint that hands it out
  becomes the new attack target).
- **Native asset obfuscation**: raises the cost of extraction but
  doesn't prevent it. Determined attackers (and basic AGP-issued
  tooling) extract the value in minutes.

**The only meaningful improvement over `.env` is keys NEVER ON
DEVICE** — see "The Edge Function broker pattern" below.

## What we do to bound the risk RIGHT NOW

For each billable shared secret in `.env`:

1. **Create a project-scoped key** in the vendor's dashboard
   (Deepgram → Project → API keys; OpenAI → API keys → project key).
   Never use a personal / account-wide key.
2. **Set a hard spending cap** on the key. If it leaks, the loss
   is capped at the cap.
3. **Set rate limits** scoped to the key. A leaked key shouldn't be
   able to burn the cap in five minutes.
4. **Set IP allowlisting if the vendor supports it**. Deepgram does
   not for streaming WS; OpenAI does not for client calls. Skip.
5. **Rotate the key on any suspected exposure** — assume a network
   inspector / shoulder-surf / lost laptop was enough.

## The Edge Function broker pattern (the real fix)

Move the master key to a Supabase Edge Function and have the client
call the broker instead of the vendor API directly. The client
authenticates with the user's Supabase session JWT; the broker
authenticates with the vendor's master key. The master key never
leaves the server.

### Deepgram broker (streaming WebSocket)

Deepgram supports SHORT-LIVED TOKENS via `POST /v1/auth/grant`. The
plan:

```
1. Client (signed in) calls our Edge Function `/voice-token`.
2. Edge Function verifies the user's Supabase session JWT.
3. Edge Function POSTs to Deepgram /v1/auth/grant with the master
   key → receives a short-lived (≤30s) token scoped to a single
   connection.
4. Edge Function returns the short-lived token to the client.
5. Client opens the streaming WebSocket with `Authorization: Token
   <short-lived>` (the same shape, just with a temp value).
6. Token expires after the WS session — even if extracted from
   memory by a sophisticated attacker, it's worthless after 30s.
```

Worst-case exposure: 30 seconds of streaming time. Master key never
on device.

### OpenAI broker (REST)

Simpler — every call is request/response.

```
1. Client (signed in) POSTs to our Edge Function `/ai-chat` with
   the prompt + context.
2. Edge Function verifies user JWT + checks the user's role / caps
   (e.g. only directors can run AI features; only N requests/day
   per user).
3. Edge Function calls OpenAI with the master key.
4. Edge Function returns the response to the client.
```

Adds a per-user usage gate too — useful for keeping AI spend
predictable.

### When to build it

**Before any external rollout.** For personal-dev / pre-release builds
the `.env` approach is acceptable risk because:
- The build isn't distributed.
- The dev machine is trusted.
- The team is small enough to rotate keys quickly on any incident.

CLAUDE.md lists "Sentry / crash reporting" as deferred for the same
shipping window. The Edge Function broker work belongs in that same
pass.

## What you can do today

If you want to drop in your Deepgram + OpenAI keys for personal-dev:

```sh
# .env (gitignored)
DEEPGRAM_API_KEY=<your project-scoped key with spend cap set>
OPENAI_API_KEY=<your project key>
```

Hot-restart the running build (`R` in the `flutter run` terminal)
to pick up the new values — `flutter_dotenv` loads at app boot, so
hot-reload alone isn't enough.

Verify:
- The omnibox mic icon, when tapped, requests microphone permission
  + starts a Deepgram session (no "voice not configured" snackbar).
- `Env.hasOpenAi` returns true for any code that gates on AI features.

## Don't

- Don't commit `.env` (it's already in `.gitignore`).
- Don't paste keys into the chat / commit messages / shared docs.
- Don't use the same key for dev + prod — the rotation cost is
  too high.
- Don't add a new "secret" to `.env` without first deciding which
  tier it falls into (Table at the top of this file). If it's
  billable shared, document the broker plan in the same PR.
- Don't bake the OpenAI key into a Dart constant via `--dart-define`
  thinking it's safer than `.env`. It's not.

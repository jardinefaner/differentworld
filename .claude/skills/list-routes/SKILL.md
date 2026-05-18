---
name: list-routes
description: Print every go_router route in the app. Useful when wiring deep links, omnibox suggestions, or thinking about navigation.
---

# /list-routes — every registered route

The router lives in `lib/app/router.dart`. Current routes:

| Path | Builds | Notes |
|---|---|---|
| `/` | `_Home` (member-state machine) | Home; PageView of Omnibox + Today |
| `/login` | `LoginScreen` | Only top-level non-auth route |
| `/checklist` | `MorningChecklistScreen` | `?filter=unmarked` supported |
| `/groups/:id` | `GroupDetailScreen` | |
| `/groups/:id/attendance` | `AttendanceScreen` | |
| `/settings` | `SettingsScreen` | Index |
| `/settings/program` | `ProgramSettingsScreen` | Director-only |
| `/settings/team` | `TeamScreen` | |
| `/settings/team/:id` | `MemberDetailScreen` | Director can edit |

## When adding a new route

1. Register in `lib/app/router.dart` — see the `new-route` skill
2. Pass `backFallbackRoute:` to `EdgeScaffold` if reachable via deep link
3. Use `context.push('/path')` from callers — never `go` for drill-in
4. Add an omnibox suggestion if it's a top-level destination users
   should be able to jump to (`lib/features/omnibox/omnibox_screen.dart`)

## Deep-link routes

The custom-scheme handler at `lib/features/invites/deep_link_listener.dart`
parses `differentworld://invite/<code>` and stashes the code in
`pendingInviteCodeProvider`. It doesn't navigate via the router — the
JoinOrCreateScreen and `_SignedInHome` listeners consume the pending
code.

If you add another deep-link-receivable path (e.g. observation share
links later), follow the same stash-and-notify pattern rather than
trying to navigate from the listener directly.

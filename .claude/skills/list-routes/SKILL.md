---
name: list-routes
description: Print every go_router route in the app. Useful when wiring deep links, omnibox suggestions, or thinking about navigation.
---

# /list-routes — every registered route

The router lives in `lib/app/router.dart` (~130 routes). A hardcoded
table here rotted badly once (it sat at 9 routes for months), so this
skill now derives the list LIVE — run:

```sh
grep -nE "^\s*path: '" lib/app/router.dart
```

Indentation shows nesting (nested `path:` values are relative to their
parent — e.g. `attendance` under `groups/:id` is
`/groups/:id/attendance`). For full-path reconstruction plus each
route's discovery surfaces (drawer / omnibox / slash / settings),
cross-reference `docs/FEATURES.md` — the authoritative registry the
`feature-mapper` agent keeps fresh.

## Route areas (orientation only — derive specifics live)

- **Daily ops**: `/`, `/search`, `/checklist`, `/pickup`, `/captures*`,
  `/tasks*`, `/insights`, `/review*`
- **Groups & kids**: `/groups/**` (attendance, observations, students,
  progress-report), `/children/:sid` (family lens)
- **Observations & reports**: `/observations*`, `/incidents*`,
  `/exports/:id/send`, `/book/:sid`, `/growth/:sid`
- **Schedule & trips**: `/schedule*`, `/trips/:blockId`
- **Surveys**: `/surveys/**` (take is kid-mode locked)
- **Messages & family**: `/messages*` (guardian home = `/` auto-resolve)
- **Vehicles**: `/vehicles/**` (checkout/checkin also via QR deep link)
- **Settings & team**: `/settings/**`
- **Present & live**: `/present*`, `/cast`, `/live/*`, `/join`,
  `/board`, `/poster`, `/speak`, `/tools`
- **Brain breaks**: `/breaks`, `/activity/*` (photo is mobile-gated)
- **Worlds & program arc**: `/action-words/**`, `/program`,
  `/this-week`, `/arc`, `/journey`, `/staff`, `/ready`, `/forge`,
  `/lens`, `/print`, `/runbook`, `/verb-jobs`, `/thinking`, `/wall`,
  `/time-capsules`, `/spells`, `/story*`, `/missions/do`,
  `/subjects/:id/*`, `/activities*`
- **Alias redirects**: `/today`, `/home`, `/team`, `/students/:id`,
  `/subjects/:id`, `/settings/vehicles`

## When adding a new route

1. Register in `lib/app/router.dart` — see the `new-route` skill
2. Pass `backFallbackRoute:` to `EdgeScaffold` if reachable via deep link
3. Use `context.push('/path')` from callers — never `go` for drill-in
4. Wire ALL FOUR discovery surfaces (router / omnibox / drawer /
   settings) per CLAUDE.md §3a, then claim them in `docs/FEATURES.md`

## Deep-link routes

The custom-scheme handler at `lib/features/invites/deep_link_listener.dart`
parses `differentworld://invite/<code>` and stashes the code in
`pendingInviteCodeProvider`; `differentworld://v/<id>/<kind>` routes to
vehicle checkout/checkin via `pendingVehicleDeepLinkProvider`. Neither
navigates from the listener directly — consumers drain the pending
value (initState read + ref.listen; see the Wave 172 gotcha in
CLAUDE.md).

If you add another deep-link-receivable path (e.g. observation share
links later), follow the same stash-and-notify pattern rather than
trying to navigate from the listener directly.

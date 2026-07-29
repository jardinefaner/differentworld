# App splits — how one codebase becomes a suite

Strategy doc, settled 2026-07-27. The question it answers: *if Different
World separates into multiple apps, what are they, when do we split, and
how do we split without forking?* Nothing here is started; the triggers
below say when each cut earns itself.

The premise that makes any of this cheap: the codebase already separates
along **viewer lenses** (StaffViewer / GuardianViewer / kid mode) and
**surface isolation** (cast receiver = Realtime-only; games = zero-data).
Splitting is mostly *subtraction and extraction*, never a rewrite.

---

## The apps, in split order

### 1. Family — split FIRST (trigger: real external families enrolled)

The guardian lens as its own app. Already isolated in code: the
`GuardianViewer` lens, the `by_guardian` PowerSync stream, and the
family screens (Family Today, per-child story/detail, messages,
received reports, surfaced incidents, the text-size sheet).

- **Why split**: parents judge "school apps" in ten seconds — a tiny,
  parent-only app with its own icon, listing, and reviews wins trust a
  do-everything staff app can't. Industry standard (Procare, Lillio).
- **What it contains**: `lib/features/family/`, messages (guardian
  side), exports (received), the family photo views. Nothing else.
- **What it needs first**: push notifications (a family app with no
  arrival signal is a dead icon), Spanish for real reach.
- **Deep-link split**: guardian invites must open THIS app; staff
  invites the staff app. `InviteCode` carries the role — route by it.

### 2. Room Screen (TV/tablet receiver) — split SECOND (trigger: >1 room
casting regularly, or any second program)

`cast_receiver` + the present/board surfaces as an Android-TV / kiosk
appliance: enter a join code once, the screen belongs to the room.

- **Why split**: it's already architecturally quarantined — Supabase
  Realtime channels only, ephemeral state, kid-facing content law,
  immersive by design. Nearly stateless, cheapest possible SKU, and it
  makes "cast" tangible ("install the room screen on the TV once").
- **What it contains**: `cast_receiver`, the game stages
  (`GameDefinition` render side), slide/world present receivers.
  No auth beyond the code; no roster; no PowerSync.

### 3. Games ("the classroom remote", dream #18) — a GROWTH PLAY, not a
refactor (trigger: deliberately deciding to acquire users beyond our
own program)

The present hub + the game catalog + brain breaks + thinking tools +
the picture library. Works offline with zero roster and no account —
any teacher anywhere is playing five minutes after install.

- **Why split**: top-of-funnel wedge. A free calm-games-that-cast app
  introduces the brand; the full program app is the upgrade.
- **Caution**: this is a marketing decision wearing a technical hat.
  Don't split it "because we can" — split it the week we want reach.

### 4. Kid app / kiosk — LATER (trigger: the kid-journal exists)

The kid-mode surfaces (surveys, drawing, action words, kid jobs,
future kid journal) as a locked launcher for shared tablets. Today
it's too thin to stand alone; the journal is what gives it a spine.

### 5. Fleet — SPINNABLE, probably never split

Vehicles + QR check-in/out + guided inspection + headcount gates is a
complete, sellable van-safety tool — but severed from the roster it
loses the thing that makes it good. Keep inside the staff app; revisit
only if a buyer wants exactly this.

## What never splits

- **The staff core** (Today, attendance, capture, observations,
  schedule, pickup, photos wall) + the director layer (insights, team,
  settings) + the story/keepsake surfaces. The thesis IS the loop:
  two-second capture → the child's book. Splitting the wall/story from
  where capture happens severs the product's reason to exist.
- **Verticals are a different axis.** Construction/healthcare re-skins
  are separately-BRANDED apps from the same code via flavors + the
  `verticalLabelsProvider` switch — a branding split, not a feature
  split. Don't conflate the two.

---

## The mechanics — one repo, N entry points

No forks, no new repos. A melos-style workspace inside this repo:

```
packages/
  dw_core/        # engine: db, sync, auth, capabilities, viewer
  dw_ui/          # shared/widgets, theme, tokens, glass, primitives
  dw_features/    # feature folders (split further later if needed)
apps/
  staff/          # today's app — main.dart, full feature set
  family/         # main_family.dart — guardian lens only
  receiver/       # main_receiver.dart — cast surfaces only
  games/          # main_games.dart — present + games, no auth required
```

- **Bundle ids**: `com.jardine.differentworld` (staff),
  `.family`, `.room`, `.games`. Each app = its own icon/splash/listing.
- **Backend is shared**: one Supabase, one PowerSync. Family uses the
  `by_guardian` stream it already uses; receiver uses Realtime only;
  games uses nothing (bundled content).
- **Interim step that costs nothing today**: keep single-app, but add
  the extra `main_*.dart` entry points behind flavors when the first
  split triggers. Until then this doc is the only artifact.

## The recurring costs (why we don't split early)

N store listings, N review cycles, N signing configs, N "what version
is the family on" support questions, cross-app deep-link routing, and
every shared-widget change potentially rebuilding four SKUs. One app
until the Family trigger fires — then splits pay for themselves in
trust, not in engineering elegance.

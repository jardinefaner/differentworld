# Live Sessions — present big, control small

The design for [VISION.md](VISION.md) **#14** (present a game on the
desktop/projector, control it from the phone) and the transport under
**#5** (the anonymous meeting/agenda board). One primitive serves both.

> "if i start a math game... how can i present it through desktop and use
> the phone to coordinate / as a control... do we need sessions?"

**Yes — but a small, ephemeral one.** Not a heavy persisted thing.

---

## The load-bearing decision: Realtime, not PowerSync

We have two transports and they do different jobs. Putting session state
in the wrong one is the mistake to avoid.

| | **PowerSync** | **Supabase Realtime** |
|---|---|---|
| Carries | Durable, owned data (children, attendance, observations) | Ephemeral coordination (which slide is up, a live idea) |
| Lifetime | Forever, converges across devices | The length of the session, then gone |
| Guarantee | Eventually-consistent, offline-first | Best-effort, in-the-moment, online-only |
| Cost model | Per-row sync budget | Cheap fan-out messages |

A slide advance or a brainstorm sticky is **not child data** and must not
ride PowerSync. It's coordination — it belongs on **Supabase Realtime**
(`broadcast` for messages + `presence` for who's in the room), which the
Supabase client already gives us. **Realtime is a separate channel from
everything PowerSync does** — no migration, no sync rule, no local SQLite
table for the live flow.

> Corollary to the architecture invariant "local SQLite is the source of
> truth for the UI": that's true for *durable* UI. A live session's
> transient state (current slide) is owned by the **presenter device** in
> memory and mirrored to peers over Realtime — it never touches Drift.

---

## What a "session" is

A session is **a Realtime channel keyed by a short join code** — nothing
more is strictly required for the game case.

- **Channel name:** `session:<code>` (e.g. `session:RJ4K`).
- **Roles** (a device picks one when it joins):
  - **Presenter** — the big screen (desktop / projector / TV / a laptop
    in the room). Renders the full view. **Source of truth** for shared
    state.
  - **Controller** — a phone. Sends *intents* ("next", "reveal",
    "back"). The remote.
  - **Contributor** — a phone, for the board case. Sends *ideas*.
- **Join:** the presenter shows the code (and a QR — we already have QR
  infra from invites/vehicles). A phone enters the code or scans → joins
  the channel.
- **Presence:** Realtime presence tells the presenter how many phones are
  connected (a "3 joined" pill), and lets a controller know it's live.

### Host authority (keeps it from desyncing)

The **presenter holds canonical state** and re-broadcasts it. A
controller sends an *intent*, not state:

```
controller --( {type:'intent', action:'next'} )--> presenter
presenter applies → new canonical state
presenter --( {type:'state', slide:4, revealed:false} )--> all peers
```

So a late-joining phone, or a phone that missed a message, syncs from the
next `state` broadcast. No CRDT, no conflict resolution — one writer.

---

## Two flows on the same rails

### A. Game remote (This-or-That, Math Game, discussions…)

This-or-That **already** split Presentation vs Control on a single device
(`this_or_that_screen.dart` — `_presentation` + `_ControlBar`/`_ControlPanel`).
The two-device link is the next layer:

- The presenter renders `_presentation` from `state.index/revealed`.
- The phone renders the control panel; its buttons send intents instead
  of calling local `setState`.
- The presenter's reducer is the same logic that's already there.

So the refactor is: **lift the `_index/_revealed/_done` state behind a
`SessionController` that's either local (single device, today) or
realtime (two device).** The widgets don't change shape.

### B. Anonymous meeting / agenda board (#5)

- Presenter = the projected blackboard / the web view. Renders a wall of
  stickies.
- Every phone is a **contributor**: it broadcasts
  `{type:'idea', text:'field trip to the farm'}`.
- **Anonymity is by construction**: the broadcast payload **never carries
  the sender's identity** — no `member_id`, no name. The presenter can't
  attribute it because the data isn't there. (Presence counts heads;
  it does not tag ideas.)
- Optional clustering / "+1" reactions are just more message types.

---

## Persistence (only when the outcome should outlive the room)

The live flow is throwaway. But sometimes the *result* matters:

- **Game:** never persisted. A round of This-or-That leaves no record
  (it's a brain break). If we ever want "we discussed X today," that's an
  `entries` row written by the presenter at the end — not the live state.
- **Meeting board:** the agenda's surfaced ideas may be worth keeping.
  When the host taps "save these," the presenter writes the kept items to
  a **synced table** (candidate: `entries` with `kind = 'idea'`, or a
  small `board_notes` table) — going through Drift like any durable write.
  Anonymity persists: store the text + space_id, not an author.

Rule of thumb: **Realtime for the verb (discussing, voting, advancing);
PowerSync for the noun that survives (the saved decision).**

---

## Build slices

1. **`SessionController` seam (local).** Lift game state behind an
   interface; This-or-That drives through it unchanged. No Realtime yet.
   *Testable on one device.*
2. **Realtime transport.** A `RealtimeSessionService` (join/host a
   `session:<code>` channel, broadcast/receive `intent` + `state`,
   presence). Presenter + controller screens. First target: This-or-That
   "present on this screen / control from my phone." *Needs two devices to
   validate.*
3. **Join by QR** (reuse the QR scanner) + a presenter "lobby" showing the
   code + who's joined.
4. **Anonymous board** as a second app of the same service: contributor
   screen (a text field that fires `idea` messages) + presenter wall +
   optional "save these" → synced `idea` entries.

## One place to join — program-wide (2026-06-03)

**The friction:** today joining is *per game*. `LiveGameScreen<S>(def:)` is
generic, but `def` is fixed by the `/live/<game>` route — so a joiner must
navigate to the *matching* game's lobby before entering the code. The channel
(`session:<code>`) is already game-agnostic; only the rendering is route-
locked. A joiner shouldn't have to know it's Charades.

**The model (Kahoot/Jackbox, scoped to the program):** one "Join" surface;
the *session* tells the app which game to render. Two slices, on the existing
Realtime-ephemeral rails — no new durable table.

**Keystone (DONE):** `lib/features/games/game_registry.dart` — `gameById(id)`
resolves a game id → its `GameDefinition`. The session advertises an id; the
joiner resolves it here and renders the right `LiveGameScreen` without knowing
the game in advance.

### Slice A — generic join (the core)
- **Presenter advertises its game.** When a presenter opens a session it also
  joins a program lobby presence channel `program:<spaceId>:live` and tracks
  `{code, game: def.id, presenter}`. (Adding `game` to the per-session
  presence too enables a code-entry "peek" path for manual codes.)
- **`LiveGameScreen` auto-join.** An optional `autoJoin: (code, role)` so the
  screen skips its lobby and opens straight into control for a given code +
  resolved def. The joiner builds
  `LiveGameScreen(def: gameById(game)!, autoJoin: (code, control))`.
- **Graceful unknown:** `gameById` → null → "That session needs a newer app."

### Slice B — auto-discover + the Today banner (the chosen entry)
- **Lobby provider.** Watches `program:<spaceId>:live` presence → the active
  sessions `{code, game, presenter}` in the program (usually exactly one).
  Ephemeral; `.autoDispose`.
- **Today banner.** When the lobby is non-empty, Today shows a tap-to-join
  banner ("A session is live — tap to join"). One tap → resolve via `gameById`
  → `LiveGameScreen(autoJoin: control)`. Multiple → a tiny picker. This is the
  only entry the user asked for — joining surfaces itself; no menu-hunting.
- The join **QR/code becomes game-agnostic** too — one join QR, not one per
  game; the game comes from the lobby/session, not the link.

### Verification
Slices A + B are Realtime + two-party — they need **two devices** (or two
signed-in web tabs) to validate the present→advertise→discover→join handshake.
Build behind the async-guard (the live-session stream-lifecycle rules), then
exercise on-device. Don't ship the banner without the two-party check.

## Open questions (decide before slice 2)

- **Who presents?** Any signed-in staff device can host; the phone that
  starts the session picks "present here" vs "I'll control." For a
  desktop-present/phone-control combo, the desktop hosts and shows the
  code.
- **Auth on the channel:** Realtime RLS / channel authorization so only
  same-program devices can join a code (codes are guessable; gate by
  space membership on the channel's authorization hook).
- **Web presenter:** the projector view is a natural **web** target
  (the app is multi-platform); the phone stays native. Same channel.

## Privacy

- No child PII flows over Realtime — game payloads are prompts + indices;
  board payloads are staff-authored idea text. No names, no photos.
- Channel codes are short-lived (per session) and authorized by space
  membership.
- Anonymity is enforced at the payload boundary, not the UI — the sender
  id is never put on the wire.

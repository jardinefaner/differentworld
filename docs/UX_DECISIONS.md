# UX decisions — Different World

Append-only log of UX rules the app holds itself to. Not aspirations —
**load-bearing decisions** other code is expected to follow. New entries
go at the bottom with a date, so this doubles as a changelog of how the
interaction model has evolved.

The rules below are the contract; the rationale is there so future
contributors (human or otherwise) can tell whether their case is
genuinely an exception or just looks like one.

---

## 1. Capability toggles auto-save — no Save button

**Rule.** A `Switch` / `SwitchListTile` that flips a capability flag
writes immediately on `onChanged`. There is no draft state, no Save
button, no "Discard changes?" prompt. The widget's `value:` reads
straight from the live entity stream, so what you see is what's in the
database one frame later.

**Why.**
- "Toggle + save" had a real race: clearing optimistic draft state
  after the write returned could rebuild before the Drift watch had
  delivered the new row, briefly showing the pre-save value. Users
  read this as "the toggle reverted on me." We tried a
  pending-saved-JSON listener and the race was still observable.
- Two-step actions (toggle, then save) are misread as "I haven't
  committed yet" or "save failed" when the second step fails silently.
  One-step is unambiguous: if the toggle moves, the write fired.
- N writes for N toggles is cheap. PowerSync queues + uploads in a
  batch. The "I want to preview before committing" use case isn't real
  for binary flags — they're trivially reversible.

**How.**
- The `_CapSwitch`-style widget takes `(value, onChanged)` where
  `onChanged` calls a typed mutator (e.g. `actions.setCap(key, v)`).
- Mutators read the entity's latest row from the DB, merge the single
  key in, and write the whole capabilities blob. Race against
  concurrent writes to *other* cap keys is minimized by re-reading
  fresh inside the mutator (see [`PickupActions.setPickupPeople`] for
  the pattern).
- If the write fails, surface a SnackBar — do **not** roll back the
  visual state. The stream will reconcile within seconds.

**Exception.** Text fields, drop-downs, and any control where a partial
value is invalid (e.g. typing a date) still go through a form with a
Save button. The "no save" rule is specifically for binary capability
toggles. Compound forms (`SubjectEditScreen`, `GroupEditScreen`) keep
their Save button for name + notes + DOB; capability toggles on those
same screens auto-save independently.

---

## 2. Settings live on screens, not in bottom sheets

**Rule.** Anything that affects how the app behaves going forward —
per-classroom tracking flags, per-child medical info, member abilities —
lives on a routable screen with a back button. Bottom sheets are
allowed only for **transient quick actions**: pick a photo, pick an
attendance status, write an observation, share an invite link, edit one
pickup-person row, create one invite.

**Why.**
- Sheets implicitly say "do this and dismiss." Settings users come back
  to repeatedly should not be hidden behind a swipe-up overlay.
- Nested sheets (a sheet over a sheet) leave no breadcrumb and silently
  lose state when the user gets swipe-happy. Banned everywhere.
- A back button + a URL is more honest about "you are here" than a
  drag handle.

**How.**
- Edits to entities are routes (`/groups/:id/edit`,
  `/groups/:gid/students/:sid/edit`, `/settings/team/:id`, etc.).
- Sub-actions that would have been a second sheet expand inline within
  the parent screen instead (see the "Add guardian" panel inside
  `SubjectEditScreen._GuardiansSection`).
- Sheets that survive this rule (PhotoSourceSheet, StatusPickerSheet,
  ObservationFormSheet, `_PickupPersonSheet`, InviteShareSheet,
  InviteCreateSheet) are all transient quick-actions.

**Exception.** A bottom sheet may host an editing form **only** if all
three apply:
1. The form is short (≤6 fields, fits without scroll on a 360dp phone).
2. There is exactly one possible outcome (save-and-dismiss).
3. It is reached from a screen that gives clear context about what's
   being edited.

If any of those fail, it becomes a route.

---

## 3. DismissGuard everywhere unsaved state can be lost

**Rule.** Any screen or sheet that holds uncommitted edits wraps its
body in `DismissGuard` so back-press, swipe-down, and scrim-tap all
honor an "Are you sure?" prompt when `isDirty` is true.

**Why.** Phone gestures are dense. Users routinely brush the back gesture
mid-typing. Losing two minutes of typing in a notes field because of a
stray swipe is the kind of thing that destroys trust.

**How.** `lib/shared/widgets/dismiss_guard.dart`. Pass `isDirty` as a
function (not a bool) so the freshest state is read on each pop attempt.

---

## 4. Optimistic UI; reconcile via the stream

**Rule.** A user tap commits to local SQLite in one frame. The UI re-
reads from the stream and updates the next frame. Network round-trips
happen in the background; failures surface as banners, not as
state-rollbacks.

**Why.** This codebase is offline-first. Any UI pattern that depends on
"wait for the server to ack" is wrong on the train, in the parking lot,
during the morning rush.

**How.**
- Widgets bind to Drift streams via Riverpod. They never `await` a
  network result inside an `onPressed`.
- Mutators write to Drift in a transaction and return immediately.
  PowerSync uploads later.
- Failed uploads retry; persistent failure (RLS reject) surfaces a
  banner but the local write stays put for the user's record.

---

## 5. Two entry points must lead to the same UI

**Rule.** If a user can reach "edit this child" from a roster tap *and*
from a search result *and* from a deep link, all three land on the same
route with the same chrome.

**Why.** Discoverability is killed when "tap a child here" and "tap a
child there" produce different surfaces. Users build a mental model
around "what tap does what" — every divergence makes that model wrong.

**How.** Every edit destination is a real route. Call sites use
`context.push(...)`. The `static show(BuildContext)` pattern is allowed
for the transient sheets in §2 but never for an edit destination.

---

## 6. Today is a capability-aware launchpad

**Rule.** The Today screen surfaces one-tap action tiles for every
capability the signed-in viewer has, so daily-use work isn't
"buried somewhere in the app." A teacher with `canObserve` sees a
"New observation" tile right on home. A driver with `canDrive` sees
"Vehicles." A director sees "Team." Nothing the viewer *can't* do
appears — the row is filtered live by the Viewer's caps.

**Why.** This is an offline-first, mobile-first, role-driven app —
each shift starts on Today. Forcing teachers to navigate
classroom → tab → screen for the action they take every hour costs
them time and discoverability. Capabilities already define what each
person can do; reuse that as the layout signal so the screen
self-adapts to the role without per-role custom UIs.

**How.**
- `lib/features/today/widgets/quick_actions.dart` builds the row.
- Each tile is gated on a `viewer.canXxx` getter.
- Tiles route to the canonical destination (`/settings/vehicles`,
  ObservationFormSheet, etc.) — they're shortcuts, not duplicated
  flows. One source of truth per action.
- When the action needs context the launchpad doesn't have
  (e.g. observation needs a `groupId`), the tile uses smart defaults
  (single visible classroom → straight in; multiple → transient
  picker sheet). Never block the launchpad on choice.
- The whole row hides when the viewer has zero matching caps so a
  read-only family lens doesn't render an empty band.

**Adding a new tile.** Add a `viewer.canXxx` getter if missing, add
one `if (viewer.canXxx) _Tile(...)` to the list in `QuickActions`,
and ensure the destination is reachable as a route. Don't bypass
the route for inline navigation — the launchpad must not become a
divergent action surface.

**Exception.** Tiles are not the right surface for stateful work
("you have a vehicle out → check it in"). Those become **status
banners** above the tile row instead, so they're noticed even when
the user isn't already scanning the launchpad. The Vehicles tile
will graduate to a state-aware "Check in [Name]" pill in a follow-
up commit once that pattern is needed in more than one place.

---

## 7. Search is the index of everything the app does

**Rule.** Every new feature MUST register at least one entry in
`lib/features/omnibox/omnibox_results.dart` at the time it ships.
Pages get one entry per page. Actions get one entry per action.
Capability-gated destinations gate their entry on the matching
`viewer.canXxx` getter so users don't see options they can't act on.

**Why.** "I don't know where the thing is" is a real complaint.
A teacher who can't remember whether vehicle check-in lives under
Settings, Today, or a classroom should be able to pull down the
search bar, type "check in," and find it. If the omnibox doesn't
index it, it doesn't exist as far as discovery is concerned.

**How.**
- Add a `_Suggestion(label, icon, keywords, onSelect)` entry inside
  the `_computeSuggestions` list.
- Pages → `kindLabel: 'Page'`. Actions → `kindLabel: 'Action'`.
- `keywords` covers what the user might type — synonyms, the
  feature's domain terms, the action verb. Keep them lowercase.
- For destinations a user can reach but not act on, the search entry
  is fine (it still surfaces them); for actions the user can't run,
  capability-gate the *entry itself* with `if (viewer.canXxx)` so it
  doesn't show up at all.
- Re-route through the canonical destination — `ctx.push(...)`,
  `Skill(...)`, or a shared helper like `startNewObservation`. Never
  duplicate the action's inner flow inside the suggestion handler.

**Adding a new feature checklist.** When you wire a new screen or
action:
1. Add the route (if any) per §2.
2. Add a QuickActions tile (if appropriate) per §6.
3. Add an omnibox suggestion per §7. **This is mandatory** — not
   doing this means the feature is invisible to search.

---

## Changelog

- **2026-05-18** — §1 capability-toggle auto-save adopted after the
  draft/save race kept producing visible flicker even with a stream-
  listener guard. Migrated `MemberDetailScreen` and
  `ProgramSettingsScreen` to auto-save.
- **2026-05-18** — §2 settings-on-screens enforced. `SubjectFormSheet`
  and `GroupFormSheet` retired in favor of `SubjectEditScreen` and
  `GroupEditScreen`. The nested "Add guardian" sheet folded into an
  inline section on the subject edit screen (`_GuardiansSection`).
- **2026-05-18** — §3 `DismissGuard` codified after observing that
  swipe-down on bottom sheets silently discarded form state.
- **2026-05-18** — §6 Today becomes a capability-aware launchpad.
  First tiles: New observation (canObserve), Vehicles (canDrive or
  canManageProgram), Team (canInviteStaff or canManageProgram).
- **2026-05-18** — §7 omnibox must index every feature; mandatory
  step in the new-feature checklist. Backfilled Vehicles + New
  observation + per-classroom Observations entries.
- **2026-05-18** — Observations now support multiple photos with
  pinch-zoom via a fullscreen `PhotoViewer`. Primary photo stays in
  `entries.photo_url` for back-compat; extras serialize to
  `details.photos`. The split is encapsulated in `SerializedPhotos`
  + `EntryPhotosX.photos` so callers see one merged list.

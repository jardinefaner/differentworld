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

## 8. Every noun is a first-class entity

**Rule.** If a concept in the domain has its own identity, lifecycle,
or audit trail — i.e., a *noun* the user can talk about independently —
it gets its own table, providers, screens, routes, and search entry.
JSONB blobs are for **attributes** of an entity (capability flags,
kind-specific structured payloads). They are not a place to hide
entities you didn't feel like modelling.

**The test.** Ask: *would I ever query, list, or audit this
independently of its parent?* If yes — promote. If no — it can stay
as an attribute.

Two failure modes the rule prevents:

1. **Buried entities.** A noun stuck inside JSONB on another row has
   no list view, no detail screen, no search index, and no foreign
   keys pointing at it. Users reach it only through one ancestor path,
   and a director can't ask "show me everything of this kind." The
   feature feels unfindable because, mechanically, it is.
2. **Silent denormalization.** A repeating shape inside JSONB ends up
   duplicated across rows. When the same human (a guardian, a
   pickup person, a vehicle) shows up in five places, edits in one
   place don't propagate. Eventually we either build a "sync this
   blob" cron or we accept stale data.

**How.**
- New noun → migration adds `<noun>s` table with `space_id`, RLS,
  publication entry, sync rule line. Per `CLAUDE.md`'s five-places
  checklist.
- Add Drift class + mutators.
- Build feature dir under `lib/features/<noun>/` with providers,
  list / detail / edit screens, and (if relevant) inspection /
  log / action sub-screens.
- Register the screen as a route in `lib/app/router.dart`.
- Add an omnibox suggestion per §7.
- Add a QuickActions tile per §6 if the noun has a daily-use
  action.

**Capability flags stay JSONB.** Boolean flags that describe what an
entity can do or what it tracks (`canObserve`, `tracksDiapers`,
`pickupStrict`) are attributes, not entities. They live in the
`capabilities` JSONB columns by design. The rule applies to entities
that have *identity* — a row you'd want to fetch by id, list by some
criterion, or attach foreign keys to.

**Audit (current state, 2026-05-18).**

| Concept | Current shape | Decision | Notes |
|---|---|---|---|
| Space / Member / Group / Subject / Guardian | First-class ✓ | Keep | Core entities. |
| Entry (observation / meal / nap / …) | First-class ✓ | Keep | One row per logged event; `kind` discriminator. |
| Vehicle / VehicleLog | First-class ✓ | Keep | Fleet feature, just landed. |
| Invite | First-class ✓ | Keep | Has lifecycle + redemption. |
| Attendance record | First-class ✓ | Keep | One row per (subject, date). |
| Group assignment (`group_members`) | First-class ✓ | Keep | Join table with id. |
| **Certification** | JSONB on `members.capabilities` | **Promote** | Each cert has an expiry, an issuing org, a document, a renewal workflow. The director needs "show me certs expiring in 30 days." Today it's two parallel JSONB shapes that can desync (cert listed but no expiry, expiry for cert not on file). |
| **Pickup person** | JSONB on `subjects.capabilities` | **Promote** | A grandparent who picks up three siblings is currently stored 3× (and edits don't propagate). Should be a person row + join. |
| **Attachment** (photo/PDF/audio) | `photo_url` columns + `entries.details.photos` | **Promote** | Photos live on subjects, members, vehicles, entries via four different storage schemes. Cert documents are coming. A single `attachments` table unifies upload, GC, viewer, "all photos this week" search. |
| Inspection item result | JSONB on `vehicle_logs.items` | **Keep JSONB** | Tightly coupled to one log event. No independent identity. |
| Capability boolean flag | JSONB on each entity | **Keep JSONB** | Attribute, not entity. |
| Subject medical text (allergies, IEP notes) | Text columns on subjects | **Keep text (for now)** | Free-form. Promote to structured rows later if we need to expire/audit them. |
| Member role | Text column on `members` | **Keep text** | Fixed enum, small. |

**Prioritized refactor.**

1. **Certifications → first-class.** Highest leverage. Unlocks
   expiring-soon dashboards, document storage (photo of the
   license), renewal reminders, audit trails. Migration touches
   `members.capabilities` (drop `certifications` / `certification_expirations`
   keys) and adds `member_certifications` with `space_id`, `member_id`,
   `cert_key`, `issued_at`, `expires_at`, `document_url`.

2. **Attachments → first-class.** Unifies every photo path in the
   app. `attachments` table with `space_id`, `entity_kind`,
   `entity_id`, `url`, `thumb_url`, `taken_at`, `taken_by`,
   `mime_type`. Drops `subjects.photo_url`, `members.avatar_url`,
   `vehicles.photo_url`, `entries.photo_url` + `details.photos`.
   Enables cert documents from #1.

3. **Pickup people → first-class.** `pickup_people` (per-space
   directory) + `subject_pickup_people` join. Same grandparent
   appearing on multiple kids stays a single row, with one phone
   number, one photo, edits propagate.

4. **Inspection items → first-class (low priority, defer).** JSONB
   is fine until we want "show me every brake-light failure across
   the fleet last quarter" as a real query.

---

## 9. One canonical destination per action

**Rule.** For any single action (edit a student, add a vehicle, fire
the morning checklist), there is exactly **one** screen / route that
performs it. Multiple *entry points* (Today launchpad tile, omnibox
suggestion, contextual button on a detail screen) are fine and
encouraged — they all `context.push(...)` to the same destination.

**Why.** Divergent flows is how features quietly bifurcate. A "create
student" sheet at the FAB and a "create student" screen from search
become two different things — one gets a polish pass, the other rots.

**How.**
- Edit destinations are routes, never `static show()` sheets.
- Shortcuts → `context.push('/the/canonical/path')`. Never inline a
  copy of the form.
- Quick-action sheets (PhotoSourceSheet, ObservationFormSheet,
  AttendanceRow inline statuses, InviteShareSheet) survive because
  they're the *only* implementation of their action — they have one
  canonical form, just reached from many places.

**Refactor work outstanding.**
- The `_CapSwitch` widget is private-duplicated in `member_detail`,
  `program_settings`, `group_edit_screen`. Functionally identical.
  Promote to `lib/shared/widgets/cap_switch.dart` so styling/behavior
  evolve in one place.
- The "edit screen" scaffold pattern (EdgeScaffold + ContentHeader +
  DismissGuard + save IconButton + DestructiveButton) is repeated in
  ~5 files. Acceptable for now (the pattern is small) but if a sixth
  edit screen lands, factor into a shared `EditScaffold`.


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
- **2026-05-18** — Attendance status picker promoted from a
  bottom-modal sheet to an inline row of five icon buttons. New
  shared `AttendanceRow` widget used by both morning_checklist and
  attendance_screen; `status_picker_sheet.dart` deleted.
- **2026-05-18** — §8 "Every noun is a first-class entity" + §9
  "One canonical destination per action" adopted. Audit identified
  three concepts currently mis-modelled as JSONB on a parent:
  certifications, pickup people, and attachments. Refactor backlog
  recorded in §8.
- **2026-05-18** — §9 quick-win: `_CapSwitch` private duplicate in
  three screens consolidated into `lib/shared/widgets/cap_switch.dart`.
- **2026-05-18** — §8: certifications promoted to first-class
  (`member_certifications` table, `CertActions`,
  `certsForMemberProvider`). Migration backfilled existing JSONB
  data and dropped the `certifications` + `certification_expirations`
  keys from `members.capabilities`. Cert-gate cascade logic moved
  to `CertActions._cascadeOffGatedCaps`. Old `Viewer.certExpiry` /
  `Viewer.isCertExpired` helpers removed (no callers).
- **2026-05-18** — Observations index landed at `/observations` —
  first top-level entry surface for an existing first-class entity
  that was buried under classroom / child paths.

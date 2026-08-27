# Capabilities — properties, roles, feature flags

This is the master catalog of what every entity can have and do. It's
the source of truth that the schema, the UI, and the permission
checks pivot off of.

Capabilities are stored in a JSONB `capabilities` column on each
entity table (added in migration `20260518000001_universal_rename`).
The catalog below tells us what keys are valid on each entity and
what each key gates.

A method is allowed only when **all** capability checks at all layers
pass — Space → Member → Group → Subject. Any layer can veto. The UI
hides affordances when checks fail; backend re-checks for safety.

---

## Space capabilities (program-wide feature toggles)

These turn entire modules on or off for the whole Space. The director
sets them once during onboarding and rarely changes them.

| Key | Type | Default | What it controls |
|---|---|---|---|
| `feature_observations` | bool | true | Observation capture UI + sync rule for observation entries |
| `feature_medication_log` | bool | false | Medication-administered entries + member.can_administer_medication |
| `feature_field_trips` | bool | false | Trips module + permission-slip flow + member.can_drive |
| `feature_meal_logging` | bool | true | Meal-log entries (per-child, per-meal-time) |
| `feature_nap_logging` | bool | true | Nap-log entries (start, end, quality) |
| `feature_diaper_logging` | bool | false | Diaper-change entries (default off for preschool, on for infant/toddler) |
| `feature_incident_reports` | bool | true | Incident-report entries with parent notification |
| `feature_family_login` | bool | false | Family-facing UI for guardians (v2+) |
| `feature_billing` | bool | false | Billing module (later) |
| `state_compliance` | enum | `'none'` | One of: none / CA / NY / TX / FL / … — drives state-specific reports |
| `pickup_window_start` | time | `'15:00'` | When pickup window opens; "Pickup soon" prompts fire 30 min before |
| `pickup_window_end` | time | `'18:00'` | When pickup window closes; "Late pickup" auto-flagged after |
| `default_class_size` | int | 12 | Used as the default `capacity` for new Groups |
| `photo_default_consent` | bool | false | Default for `Subject.photo_consent` on new enrollments — start opt-in, change to true if you have blanket consent |
| `timer_presets` | JSON list | `[1,2,5,10]` | Present-surface timer's "house" preset minutes (Play today / Present an activity). Owner: `house_timer.dart` (`houseTimerPresetsProvider` / `HouseTimerActions.setPresetMinutes`) |
| `suggest_play_minutes` | int | 5 | Big Thinking play beat's suggested timer length, in minutes. Owner: `house_timer.dart` (`houseSuggestPlayMinutesProvider` / `HouseTimerActions.setPlayMinutes`); injected into `buildDayRun`/`buildActivityArc` via `playSeconds` |
| `phase_windows` | JSON object | afterschool | Day-phase boundaries `{arrival,program,pickup,closed}` as minutes-from-midnight; retimes the whole Today "RIGHT NOW" lead for camps / full-day programs. Owner: `DayPhaseWindows` + `dayPhaseWindowsProvider` + `DayPhaseActions.setWindows` in `today_providers.dart` |

Note: not every SpaceCaps key is a toggle, so a few string/JSON caps live on
the blob without a row here (`vertical`, `staff_pin`, `day_templates`,
`program_start_date`) — see `SpaceCaps` in
`lib/core/capabilities/capability_keys.dart` for the full list.

**Where the user sees these:** Settings → Program → "What's tracked"
(a checklist of features) + a "Defaults" section (photo consent, the two
timer caps) + a "Day rhythm" section (the four `phase_windows` time pickers).

---

## Member capabilities (what a staff member can do)

These gate actions a Member can perform. Default values come from
their `role`; the director can override per-Member.

| Key | Type | Default by role | Notes |
|---|---|---|---|
| `can_observe` | bool | teacher+ | Gates creating observation entries |
| `can_take_attendance` | bool | teacher+ | Gates attendance writes |
| `can_record_meal` / `can_record_nap` / `can_record_diaper` | bool | teacher+ | Gates daily-routine entries |
| `can_administer_medication` | bool | false (any role) | Requires state cert in many jurisdictions; explicit per-person opt-in |
| `can_drive` | bool | false | Field-trip volunteer eligibility |
| `can_open_building` / `can_close_building` | bool | lead_teacher+ | Building access (key holders) |
| `can_authorize_pickup` | bool | lead_teacher+ | Add/remove guardians from a Subject's pickup list |
| `can_view_billing` | bool | director only | Sees billing pages (when feature is on) |
| `can_invite_staff` | bool | director only | Send invitations |
| `can_view_audit_log` | bool | director only | Compliance log |
| `can_act_as_director` | bool | false | Backup admin role; used when director is offsite |
| `certifications` | text[] | `[]` | CPR, MAT (medication administration), state-specific. Stored as tags. |

**Where the user sees these:** when inviting a new Member or editing
an existing one, an "Abilities" section with checkboxes. Most users
match a Role preset; few need overrides.

---

## Role → default capability bundle

Roles are coarse defaults. The capability flags above are the truth.

| Role | Implied capabilities |
|---|---|
| `director` | Every `can_*` true except those explicitly gated by certifications (e.g. `can_administer_medication` stays false until a cert is added) |
| `lead_teacher` | `can_observe`, `can_take_attendance`, all `can_record_*`, `can_open_building`, `can_close_building`, `can_authorize_pickup` |
| `teacher` | `can_observe`, `can_take_attendance`, all `can_record_*` |
| `assistant` | `can_take_attendance`, `can_record_meal`, `can_record_nap`, `can_record_diaper` (not observe) |

When a Member is invited at a given role, the invite's `capabilities`
JSONB starts with the role's defaults. Director can edit before
sending OR after acceptance.

---

## Group capabilities (what's tracked in this room)

These determine which logging features show up for this room. An
infant room enables diapers + naps; a preschool room turns them off
and emphasizes observations. **The Group's capabilities override the
Space defaults** for the rooms they apply to.

| Key | Type | Default | Notes |
|---|---|---|---|
| `age_band` | enum | `'preschool'` | One of: `infant` (0-18mo) / `toddler` (18mo-3yr) / `preschool` (3-5yr) / `prek` (4-5yr) / `mixed` |
| `tracks_diapers` | bool | derived from age_band | infant + toddler → true; preschool+ → false |
| `tracks_naps` | bool | derived from age_band | infant + toddler + preschool → true |
| `tracks_meals_detailed` | bool | false | True for picky-eater age groups, false otherwise |
| `tracks_bottle_feeds` | bool | derived from age_band | only infant |
| `nap_schedule` | structured | null | `{start: '13:00', end: '14:30'}` if any |
| `has_outdoor_time` | bool | true | Drives sun-safety reminders, weather card on Today |
| `has_field_trips` | bool | false (preschool+: true) | Toggles trips UI |
| `curriculum_unit_id` | uuid | null | Currently-active curriculum unit (later) |
| `bilingual_languages` | text[] | `[]` | e.g. `['en', 'es']` for immersion rooms |

**Where the user sees these:** when creating or editing a Group, a
"What's tracked in this classroom" section. Most fields auto-fill
from `age_band` and the user only overrides exceptions.

---

## Subject capabilities (what's tracked for this child)

Per-child. Some overlap with Group capabilities (the child's
classroom-level defaults apply unless the child has an override).
Some are intrinsic to the child (allergies, IEP).

| Key | Type | Default | Notes |
|---|---|---|---|
| **Tracking flags** (inherit from Group unless set on Subject) | | | |
| `tracks_diapers` | bool | inherit | Override on a toddler who's potty-trained early |
| `tracks_naps` | bool | inherit | Override on a child who's transitioned out of nap |
| `tracks_bottle_feeds` | bool | inherit | Override on infants who've transitioned to solids |
| `tracks_potty_training` | bool | false | Toddler transition; daily notes vs full diaper logs |
| **Medical** | | | |
| `allergies` | array | `[]` | `[{type: 'peanut', severity: 'severe', epipen: true}]` — structured, not free text |
| `dietary` | text[] | `[]` | `['vegetarian', 'halal', 'kosher', 'gluten_free', 'dairy_free']` |
| `medications` | array | `[]` | `[{drug, dose, schedule, prescriber, prescription_url}]` |
| `medical_conditions` | text[] | `[]` | `['asthma', 'eczema', 'diabetes_t1']` |
| **Education** | | | |
| `has_iep` | bool | false | Has individualized education plan |
| `iep_notes` | text | null | Free text — what accommodations are required |
| `requires_one_on_one` | bool | false | Drives staffing-ratio calculations |
| **Pickup / family** | | | |
| `photo_consent` | bool | inherit | From Space.photo_default_consent on enrollment; override per-family |
| `pickup_strict` | bool | true | If true, only members of `authorized_pickup_guardian_ids[]` may pick up. If false, any adult ID-verified is OK. |
| `authorized_pickup_guardian_ids` | uuid[] | `[]` | References Guardians |
| `photo_visibility` | enum | `'family_only'` | `family_only` / `staff_only` / `program_wide` / `public_blurred` |
| **Behavioral / care notes** | | | |
| `comfort_items` | text[] | `[]` | e.g. `['blue blanket', 'monkey stuffed animal']` |
| `nap_routine` | text | null | "Needs back rubbed; falls asleep around 1:15." |
| `transition_notes` | text | null | "Hard separations — give 5 min at drop-off." |

**Where the user sees these:** the Subject (child) detail screen,
under "Profile" (basic) and "Care notes" (deeper). Director can
filter the catalog so teachers only see what they need.

---

## How capabilities check at runtime

Pattern in Riverpod:

```dart
final canRecordMedicationProvider =
    Provider.family<bool, ({String subjectId})>((ref, params) {
  final space = ref.watch(currentSpaceProvider).value;
  final me    = ref.watch(currentMemberProvider).value;
  final child = ref.watch(subjectProvider(params.subjectId)).value;

  if (space == null || me == null || child == null) return false;

  return space.cap('feature_medication_log') == true
      && me.cap('can_administer_medication') == true
      && (child.cap<List>('medications')?.isNotEmpty ?? false);
});
```

UI:
```dart
if (ref.watch(canRecordMedicationProvider((subjectId: subject.id)))) {
  // show the "Record medication" button
}
```

Cap accessor on each entity Dart class:
```dart
extension MemberCap on Member {
  T? cap<T>(String key) {
    final map = jsonDecode(capabilities) as Map<String, dynamic>;
    return map[key] as T?;
  }
}
```

(One small helper per entity; we won't keep typing JSONB access in
every consumer.)

---

## How tracking-flag inheritance works

For flags that exist on both Group and Subject (`tracks_diapers`,
`tracks_naps`, `tracks_bottle_feeds`):

1. **Check Subject.capabilities** — if the key is explicitly set
   (`true` or `false`), use that
2. **Otherwise check Group.capabilities** — if set, use that
3. **Otherwise** derive from `age_band` default

The same Subject's logging surface adapts: if you transfer them to a
new room, the Group defaults change automatically; if you've set an
explicit Subject override, it sticks across moves.

In code:
```dart
bool subjectTracks(Subject s, Group g, String key) {
  return s.cap<bool>(key)
      ?? g.cap<bool>(key)
      ?? _ageBandDefault(g.cap<String>('age_band'), key);
}
```

---

## What's NOT in capabilities (and why)

Some things look like capabilities but aren't:

- **`role`** on Member is a separate column (an enum). Capabilities
  are the truth, role is the default-bundle label. Two reasons: roles
  appear in many UI strings ("Hi, lead teacher"), and they're useful
  for fast queries ("show me all directors").
- **`color`** on Group is just a visual property, not a flag — not in
  the catalog.
- **`dob`** on Subject is intrinsic data, not a capability.

If a property answers "what can be done with this?" or "is this
on/off?" it's a capability. If it answers "what is this?" it's a
direct column.

---

## Updating this document

This is a living catalog. When a new feature gets added:

1. Identify the capability flags it needs (one or more per layer)
2. Add them here under the appropriate entity
3. Implement the JSONB read in Dart + the UI gate
4. Add the toggle to the relevant settings screen

Don't add a capability you can't toggle yet — features-without-UI is
how the catalog rots. If the feature isn't being built, don't list
its capability.

## Capabilities that gate nothing (audited 2026-08-26)

Six keys ship in the role bundles and are read by **nothing** outside the
roles reference and the member editor. They are intentions, not gates:

| Key | Status |
|---|---|
| ~~`can_record_meal`~~ | **RETIRED 2026-08-26** — infant-care verb, ages 5-12 |
| ~~`can_record_nap`~~ | **RETIRED** |
| ~~`can_record_diaper`~~ | **RETIRED** |
| `can_administer_medication` | appears only in `certifications_providers` (granting it), never enforcing it |
| `can_open_building` | nothing reads it; `/runbook` is open to everyone |
| `can_close_building` | same |

**Why this matters beyond tidiness.** A director toggling "Record meals"
off for a Substitute believes they have restricted something. They have
not. The switch moves, the roles screen renders a sentence about it, and
the app behaves identically — which is worse than an absent feature,
because it looks like a control.

`/you` deliberately omits the first four (offering work the app cannot do
is a claim a newcomer cannot check) and shows the runbook as OPEN rather
than blocked, because it genuinely is. Telling someone they are blocked
from something they can walk straight into is the same lie in the other
direction.

**Before adding a capability key**, check it will actually be read. A key
with no reader is a promise the UI makes on the app's behalf.

## Retired 2026-08-26

`can_record_meal` / `can_record_nap` / `can_record_diaper` are gone, and
the **`kitchen` role** with them — its entire bundle was
`canRecordMeal: true`, so once the verb went the role granted nothing at
all.

Deleted rather than kept "for a future infant vertical". Keeping unread
keys around for later is exactly how they accumulated; if infant care is
ever built they come back WITH the screens that read them.

**What survives, and why:**
- **`can_administer_medication` stays.** EpiPens, inhalers and ADHD meds
  are ordinary in an afterschool program — unlike diapers, this is a real
  5-12 need. It still gates nothing, which is now a known gap rather than
  a vestige.
- **`kitchen` stays a valid Postgres enum value.** Enum values cannot be
  dropped without recreating the type, and a legacy `role='kitchen'` row
  must keep syncing — blocking it in `members_dao._allowedRoles` would
  stall that member's entire upload queue. It is no longer OFFERED by
  `RoleBundles.rolesFor`, and its label is absent so such a row falls back
  to the default — the cue to move that person to another role. Same shape
  as the earlier `assistant` retirement.
- **Orphaned jsonb values are harmless.** Existing `members.capabilities`
  rows may still carry `can_record_meal`; nothing reads it, and no
  migration is needed to clean it up.

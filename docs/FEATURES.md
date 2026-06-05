# Feature registry

The canonical map of every feature in the app. Folder-grained: one
section per immediate subdirectory of `lib/features/`. Each section has
a fixed shape; if you find yourself wanting a new field, propose it to
the user — don't invent it.

**Maintained by**: the `feature-mapper` agent. Re-runs whenever files
under `lib/features/`, `lib/app/router.dart`,
`lib/features/omnibox/omnibox_results.dart`,
`lib/features/omnibox/omnibox_catalog.dart`,
`lib/shared/widgets/main_drawer.dart`,
`lib/features/settings/settings_screen.dart`, or
`supabase/migrations/` change.

**Queryable**:
- `Agent blast-radius` — "if I touch X, what else moves?"
- `Agent persona-audit` — "is each persona served?"

**Schema** (any "Discovery surface" claim is verified against the
code; mismatches show up as drift warnings):

```
## <FeatureName>
**Path**: `lib/features/<dir>/`
**Purpose**: One sentence — what the user gets, not how it works.
**Personas served**: Maya | Jordan | Lauren | Devon | Coach Sam | Helen | Marcus | Brianna | Pat | Ava | All staff | All guardians
**Discovery surfaces**:
- Routes: <go_router paths>
- Omnibox: <yes/no with labels + keyword aliases>
- Slash: <command names or "none">
- Drawer: <yes/no — label + position>
- Settings: <yes/no — row label + _SettingsGroup>
**Capabilities**: <required caps, or "None — open to all signed-in members">
**Data**: <synced tables touched — names only, see docs/SCHEMA.md>
**Surfaces**:
- *<surface name>* — `<file>`. One line of what + what action.
**Depends on**: <other features it imports>
**Consumed by**: <other features that import this>
**Last verified**: <ISO date>
```

---

## Top-level orientation

The drawer (mobile) and desktop nav rail both render from the single
canonical list in `lib/shared/widgets/nav_destinations.dart`
(`buildNavDestinations(viewer)`). Top-level destinations in canonical
order: **Today**, **Schedule**, **Observations** (gated `canObserve`),
**Captures**, **Tasks**, **Tools**, **Present**, **Brain Breaks**,
**Missions**, **Brainstorm Board**, **Insights**, **Surveys**,
**Vehicles** (gated `canDrive || canManageSpace`), **Settings**. Everything narrower is reachable via the
omnibox (`/search`) or slash commands. Settings is the library / admin
surface — preferences + roster + fleet, not primary workflows.

---

## ActivityRuntime
**Path**: `lib/features/activity_runtime/`
**Purpose**: Short, card-shaped brain-break activities that a teacher (or a kid) can launch mid-session to reset the room.
**Personas served**: All staff (Jordan, Coach Sam, Brianna launch breaks), Ava (Photography is kid-locked; Role Cards, Group Discussions, and Pattern Maker are teacher-paced).
**Discovery surfaces**:
- Routes: `/breaks` (deck), `/activity/math` (Many Paths), `/activity/math-game` (Math Game), `/activity/photo` (Photo Studio), `/activity/this-or-that` (Quick Picks), `/activity/starts-with` (Beat the Letter), `/activity/as-if` (Act It Out), `/activity/roles` (Role Cards), `/activity/pattern` (Make a Pattern), `/activity/discussions` (Group Discussions), `/activity/riddles` (Riddles), `/activity/breathe` (Mindful Minute), `/activity/fact-or-fib` (Fact or Fib), `/activity/story` (Story Starters), `/activity/rhyme-time` (Rhyme Time)
- Omnibox: no direct entry for individual activities — all activity routes are reachable through the Brain Breaks deck (`/breaks`) which is in the drawer; individual `/activity/*` routes are also reachable from their slash commands
- Slash: `/breaks` (aliases: `break`, `brainbreaks`, `games`, `play`), `/math {answer}` (aliases: `paths`), `/mathgame` (aliases: `quiz`, `quickmath`), `/photo {prompt}` (aliases: `camera`, `photos`), `/thisorthat` (aliases: `this`, `tot`, `wouldyourather`), `/startswith` (aliases: `letters`, `ck`, `words`), `/asif` (aliases: `acting`, `drama`, `act`), `/roles` (aliases: `role`, `animal`, `animals`, `people`, `jobs`, `cards`, `pretend`), `/pattern` (aliases: `patterns`, `tile`, `kaleidoscope`, `symmetry`, `repeat`), `/discuss` (aliases: `discussion`, `talk`, `circle`, `grouptalk`, `conversation`), `/riddles` (aliases: `riddle`, `brainteaser`, `brainteasers`, `guess`), `/breathe` (aliases: `breath`, `calm`, `mindful`, `relax`, `breathing`), `/factorfib` (aliases: `fact`, `fib`, `trueorfalse`, `truefalse`, `trivia`), `/story` (aliases: `stories`, `storytime`, `imagine`, `tale`, `twist`), `/rhyme` (aliases: `rhymes`, `rhymetime`, `words`)
- Drawer: yes — "Brain Breaks" (main destinations, position between Tasks and Settings)
- Settings: no
**Capabilities**: None — open to all signed-in staff. Photography is the only kid-locked activity; all others are teacher-paced and exit via the back arrow.
**Data**: [content_items](SCHEMA.md#content_items) — read via `bankedContentProvider` (`lib/features/activity_runtime/content_bank_providers.dart`); the `LocalContentBank.seededWith` factory merges the curated Dart floor with any synced DB rows. Growing the bank means adding seed migrations through Claude Code — see `docs/CONTENT_BANK.md §1.3`. Live multi-device activities (Charades, live This-or-That) intentionally read the curated floor only (`LocalContentBank.seeded`) for deterministic shared order across devices. Pattern Maker captures a photo via `image_picker` but does not write to any synced table.
**Surfaces**:
- *Brain Breaks deck* — `lib/features/activity_runtime/brain_breaks_screen.dart`. Fourteen cards + a Surprise button; each card pushes its activity route.
- *Role Cards screen* — `lib/features/activity_runtime/role_cards_screen.dart`. Deck-switcher chip row; Animals & Nature deck (23 cards) + People & Jobs deck (12 profession cards). Catalog + `RoleDeck` struct in `roles.dart`. Teacher-paced.
- *Group Discussions screen* — `lib/features/activity_runtime/discussions_screen.dart`. Teacher picks a topic + age band; one curated open-ended prompt at a time; optional "Go deeper" follow-up. Pure-Dart catalog. Teacher-paced.
- *Make a Pattern screen* — `lib/features/activity_runtime/pattern_maker_screen.dart`. Snap a tile → kaleidoscope-tiled repeating pattern. `image_picker` camera. Teacher-paced.
- *Photo Studio* — `lib/features/activity_runtime/photography_runner_screen.dart`. Full-screen camera with a teacher-provided prompt. The ONLY kid-locked break (enters kid mode in `initState`, exits in `dispose`; 5-tap top-left staff exit).
- *Many Paths (math runner)* — `lib/features/activity_runtime/math_runner_screen.dart`. How many ways to a target number? Teacher-paced. `?target=N` seeds the answer; defaults to 12.
- *Math Game* — `lib/features/activity_runtime/math_game_screen.dart`. Mixed-mechanic one-question-at-a-time arithmetic. Teacher-paced.
- *Beat the Letter* — `lib/features/activity_runtime/letter_words_screen.dart`. Words that start with a given letter. DB-backed via `bankedContentProvider`. Teacher-paced.
- *Act It Out* — `lib/features/activity_runtime/as_if_screen.dart`. Perform a line in an emotion/character. DB-backed via `bankedContentProvider`. Teacher-paced.
- *Quick Picks* — `lib/features/activity_runtime/this_or_that_screen.dart`. Binary this-or-that questions. DB-backed via `bankedContentProvider`. Teacher-paced.
- *Riddles* — `lib/features/activity_runtime/riddles_screen.dart`. Guess-the-answer riddles. DB-backed via `bankedContentProvider`. Teacher-paced.
- *Mindful Minute* — `lib/features/activity_runtime/breathe_screen.dart`. Calm breathing break. Teacher-paced.
- *Fact or Fib* — `lib/features/activity_runtime/fact_or_fib_screen.dart`. True/false claims; room votes; Reveal shows the verdict + real fact. DB-backed via `bankedContentProvider`. Teacher-paced.
- *Story Starters* — `lib/features/activity_runtime/story_starters_screen.dart`. Build a story aloud with plot twists. DB-backed via `bankedContentProvider`. Teacher-paced.
- *Rhyme Time* — `lib/features/activity_runtime/rhyme_time_screen.dart`. How many rhymes can the room find for a given word? DB-backed via `bankedContentProvider`. Teacher-paced.
- *Kid mode lock mixin* — `lib/features/activity_runtime/kid_mode_lock.dart`. Shared `KidModeLock<T>` mixin used ONLY by Photography; other activities do not use it.
- *Content bank* — `lib/features/activity_runtime/content_bank.dart`. `ContentItem`, `ContentKind`, `ContentSource`, `LocalContentBank` — the source-agnostic interface all DB-backed activities depend on. `curatedSeeds` is the offline floor. `LocalContentBank.seededWith(extra)` merges banked DB rows on top.
- *Content bank providers* — `lib/features/activity_runtime/content_bank_providers.dart`. `bankedContentProvider` (StreamProvider, keepAlive) — watches `content_items` via `ContentBankDao` and yields `curatedSeeds ++ banked` rows; falls back to `curatedSeeds` on DB error.
**Depends on**: Kid mode (Photography only), Photos (pattern_maker uses image_picker; bytes are not stored in any synced table).
**Consumed by**: LiveSession + games framework (`content_bank.dart` seeds every `GameDefinition`'s `initialState`).
**Migration note (2026-06-03)**: five host-present activities were PORTED to `GameDefinition`s under `lib/features/games/games/` and now share the unified game UI + go present/live — Rhyme Time (`rhyme_time_game`), Letter Words / "starts-with" (`letter_words_game`), As-If (`as_if_game`), Story Starters (`story_starters_game`), Math Game (`math_quiz_game`). Their bespoke `*_screen.dart` files were deleted; `/activity/<x>` now renders `GameRunner(def:)` + a new `/live/<x>`. Left bespoke (correctly not host-present games): `breathe_screen` (animation), `pattern_maker_screen` + `photography_runner_screen` (camera), `math_runner_screen` (typed input), `role_cards_screen` (catalog), `discussions_screen` (setup picker doesn't fit the host loop). `feature-mapper` should reconcile the surfaces list.
**Last verified**: 2026-06-03

---

## Attendance
**Path**: `lib/features/attendance/`
**Purpose**: Daily check-in / check-out for one cohort at a time.
**Personas served**: All staff (Maya for oversight, Jordan + Coach Sam day-to-day).
**Discovery surfaces**:
- Routes: `/checklist`, `/groups/:id/attendance`
- Omnibox: yes — "Morning checklist", "Take attendance · {Group.name}" (per cohort), "Mark absent today · {Child name}" (per subject, single-tap write with snackbar + "Open attendance" action for course-correction)
- Slash: `/attendance {group}` (alias `/atd`)
- Drawer: no
- Settings: no
**Capabilities**: `can_take_attendance`
**Data**: [attendance_records](SCHEMA.md#attendance_records), [groups](SCHEMA.md#groups), [subjects](SCHEMA.md#subjects)
**Surfaces**:
- *Morning checklist* — `lib/features/attendance/morning_checklist_screen.dart`. Today's cohorts list; one tap opens a cohort's check-in.
- *Attendance screen* — `lib/features/attendance/attendance_screen.dart`. Per-cohort grid of subjects with present/absent/late toggles.
**Depends on**: Groups, Subjects.
**Consumed by**: Insights (late streaks), Today (morning card).
**Last verified**: 2026-05-21

---

## Auth
**Path**: `lib/features/auth/`
**Purpose**: Google-only sign-in; gates the whole app.
**Personas served**: All staff, All guardians.
**Discovery surfaces**:
- Routes: `/login`
- Omnibox: no — pre-auth surface
- Slash: none
- Drawer: no — drawer is signed-in-only; sign-out lives in the drawer header
- Settings: no
**Capabilities**: None — pre-auth.
**Data**: None directly — reads `auth.users` via Supabase; member resolution happens in `viewer.dart`.
**Surfaces**:
- *Login screen* — `lib/features/auth/login_screen.dart`. "Continue with Google" → `supabase.auth.signInWithOAuth(provider: google, redirectTo: com.jardine.differentworld://login-callback)`.
**Depends on**: Supabase client configuration in `main.dart`.
**Consumed by**: Every signed-in feature (via `viewerProvider`).
**Last verified**: 2026-05-21

---

## Captures
**Path**: `lib/features/captures/`
**Purpose**: One-tap "I noticed…" inbox. Quick thoughts triaged later into observations, tasks, or discarded.
**Personas served**: All staff (Jordan + Coach Sam on the floor; Maya triaging the inbox).
**Discovery surfaces**:
- Routes: `/captures`, `/captures/new`
- Omnibox: yes — "Capture inbox", "Capture a note" (action), also Recent Captures strip on `/search`
- Slash: `/captures` (alias `/inbox`)
- Drawer: yes — "Captures" (main destinations, position 3)
- Settings: no
**Capabilities**: None — open to all signed-in staff. Promotion to task/observation requires the respective cap.
**Data**: [captures](SCHEMA.md#captures), [tasks](SCHEMA.md#tasks), [entries](SCHEMA.md#entries)
**Surfaces**:
- *Capture inbox* — `lib/features/captures/capture_inbox_screen.dart`. List of open captures; swipe to promote / dismiss.
- *Capture screen* — `lib/features/captures/capture_screen.dart`. Free-text input; on submit, writes a new capture row.
- *Composer integration* — the omnibox bar's "capture mode" (lightning-bolt) writes through this feature.
- *Promotion actions* — `CaptureActions.promoteToObservation` and `promoteToTask` in `lib/features/captures/captures_providers.dart`. Both wrap their two-row writes (create entry / task + mark capture promoted) in a single `db.transaction(...)` so a mid-flight failure can't leave an orphan entry/task or a half-flipped capture status. Blast-radius flagged the prior "atomic-ish" two-write path 2026-05-22.
**Depends on**: Tasks (promotion destination), Entries (observation promotion destination).
**Consumed by**: Today (composer + recent strip), Review (open-captures stat + "Capture a reflection" CTA).
**Last verified**: 2026-05-22

---

## Certifications
**Path**: `lib/features/certifications/`
**Purpose**: Track staff certs (MAT, CPR, Driver) with issue + expiration dates; gate caps that require them.
**Personas served**: Maya (compliance oversight), All staff (read their own).
**Discovery surfaces**:
- Routes: none — embedded in Member detail
- Omnibox: no
- Slash: none
- Drawer: no
- Settings: no — reached via `/settings/team/:id`
**Capabilities**: Reading certs is open; writing requires `can_manage_staff` (lives on director / lead).
**Data**: [member_certifications](SCHEMA.md#member_certifications)
**Surfaces**:
- *Cert section in Member detail* — embedded in `lib/features/settings/member_detail_screen.dart`. Per-member list + add/edit form.
**Status**: provider-only feature folder; no top-level screen. Cert UI lives inline in Member detail.
**Depends on**: Members.
**Consumed by**: Vehicles (Driver cert gates `can_drive`), Insights (expiring-cert signal).
**Last verified**: 2026-05-21

---

## Entries
**Path**: `lib/features/entries/`
**Purpose**: Unified daily log — observations, meals, naps, diapers, incidents — all rows in one table with a `kind` discriminator.
**Personas served**: All staff (Jordan + Coach Sam log; Maya reviews; Marcus + Lauren read).
**Discovery surfaces**:
- Routes: `/observations`, `/observations/new`, `/observations/:id/edit`, `/groups/:id/observations`
- Omnibox: yes — "Observations" (gated by `can_observe`), "Observations · {Group.name}" (per cohort), "New {entry label}" (action), "Quick observation · {Name}" (per subject)
- Slash: `/log {kid}` (aliases `/observe`, `/obs`)
- Drawer: yes — "Observations" (canonical nav, gated `canObserve`; position between Schedule and Captures)
- Settings: no
**Capabilities**: `can_observe`
**Data**: [entries](SCHEMA.md#entries), [attachments](SCHEMA.md#attachments)
**Surfaces**:
- *Observations index* — `lib/features/entries/observations_index_screen.dart`. Newest-first feed across all groups (filterable).
- *Observations screen* — `lib/features/entries/observations_screen.dart`. Per-cohort feed.
- *Observation form* — `lib/features/entries/observation_form_screen.dart`. Create / edit a single entry; photo attach, voice dictation via Deepgram mic (suffix-icon on the body TextField; owns its own `DeepgramVoiceController` instance — does NOT consume the shared `deepgramVoiceProvider` singleton, to avoid the dual-listener race against AppShell's composer mic).
**Depends on**: Subjects, Groups, Attachments, Photos, Voice (Deepgram dictation on the body field).
**Consumed by**: Exports (Progress Report compiles entries), Captures (promotion destination), Insights (pattern detection), Family (Lauren read), Today (recent activity card).
**Last verified**: 2026-06-01

---

## Exports
**Path**: `lib/features/exports/`
**Purpose**: Compile a child's observations into a shareable PDF and send to family via email or copy-link.
**Personas served**: Maya (creates), Jordan / Coach Sam / Brianna (all have `can_observe`, can create for their own subjects), Lauren / Devon / Helen / Marcus (recipients).
**Discovery surfaces**:
- Routes: `/groups/:id/students/:sid/progress-report`, `/exports/:id/send`
- Omnibox: yes — "Progress report · {Name}" (per subject, action)
- Slash: none
- Drawer: no
- Settings: no
**Capabilities**: Generating: `can_observe`. Sending: same (recipient list comes from `subject_guardians`).
**Data**: [exports](SCHEMA.md#exports), [export_recipients](SCHEMA.md#export_recipients), [entries](SCHEMA.md#entries), [guardians](SCHEMA.md#guardians), [attachments](SCHEMA.md#attachments) (signed-URL preview of observation photos in the compiled report)
**Surfaces**:
- *Progress report screen* — `lib/features/exports/progress_report_screen.dart`. Preview the compiled PDF; Send → push to `/exports/:id/send`.
- *Send export screen* — `lib/features/exports/send_export_screen.dart`. Pick recipients (guardian checkboxes preloaded with their email + manual-entry email) and send via Edge Function, or copy a 7-day signed URL.
**Depends on**: Entries, Subjects, Guardians, Photos (signed-URL preview of attachments).
**Consumed by**: Family Today (Lauren / Devon / Helen / Marcus see received reports via the `_ReceivedReportsCard`, shipped 2026-05-23 in Wave 39). Direct-PostgREST read (`myReceivedExportsProvider` queries Supabase directly), NOT the local Drift mirror — guardians' `members.space_id = null` means `by_space` never delivers `exports` / `export_recipients` to them. RLS on `export_recipients` gates by recipient identity. Tap → mint a 10-min signed Storage URL → `url_launcher` → OS PDF viewer. Wave 42 added Devon-persona read tracking: opening a report stamps `export_recipients.read_at` via the `markReceivedExportRead` helper; the card then renders a "Seen" badge on already-opened rows so co-parents can tell which reports they've already worked through. Co-parent visibility ("Also seen by Lauren") still deferred — needs a sibling-recipient query shape.
**Last verified**: 2026-05-23

---

## Family
**Path**: `lib/features/family/`
**Purpose**: Guardian (parent) lens. Read-only view of linked children + the messaging surface.
**Personas served**: Lauren, Devon, Helen, Marcus.
**Discovery surfaces**:
- Routes: `/children/:sid` (FamilySubjectDetailScreen), `/messages` (FamilyMessagesScreen — index), `/messages/:subjectId/:guardianId`
- Omnibox: yes — "Messages" (gated by guardian + has-linked-children)
- Slash: none
- Drawer: no — guardian sees a different drawer (TBD); today drawer is staff-only
- Settings: no
**Capabilities**: Guardian role (`member.role == 'guardian'` AND `guardians.user_id == auth.uid()`).
**Data**: [guardians](SCHEMA.md#guardians) (offline-first via `by_guardian` stream), [spaces](SCHEMA.md#spaces) (offline-first via `by_guardian` stream), [subject_guardians](SCHEMA.md#subject_guardians) (offline-first via `by_guardian` stream), [messages](SCHEMA.md#messages) (offline-first via `by_guardian` stream), [export_recipients](SCHEMA.md#export_recipients) (offline-first via `by_guardian` stream), [subjects](SCHEMA.md#subjects) (direct PostgREST — 2-level subquery deferred), [attendance_records](SCHEMA.md#attendance_records) (direct PostgREST — 2-level subquery deferred), [entries](SCHEMA.md#entries) (direct PostgREST — 2-level subquery deferred), [attachments](SCHEMA.md#attachments) (direct PostgREST — 2-level subquery deferred), [exports](SCHEMA.md#exports) (direct PostgREST via `myReceivedExportsProvider`)
**Surfaces**:
- *Family today* — `lib/features/family/family_today_screen.dart`. Each linked child's card; recent observation count, today's activity. Header carries a Display action that opens the shared text-size sheet (Helen-persona; guardians never reach `/settings`). Photo-of-the-moment shipped 2026-05-22. Wave 39 added a `_ReceivedReportsCard` above the kid list that surfaces the most recent progress-report PDFs the staff have sent the guardian. Per-child reads (subjects, attendance, entries, attachments) route through `family_providers.dart` via direct PostgREST — the 2-level subquery needed for PowerSync's `by_guardian` stream is deferred. Row-keyed tables (guardians, spaces, subject_guardians, messages, export_recipients) are now offline-first via the `by_guardian` stream.
- *Family subject detail* — `lib/features/family/family_subject_detail_screen.dart`. Read-only child profile + photo gallery. Reads subjects + attachments via `familySubjectByIdProvider` / `familyAttachmentsForEntityProvider` (PostgREST, gated by `viewer.canSeeSubject`).
- *Family messages index* — `lib/features/family/family_messages_screen.dart`. Per-child thread list. Messages now offline-first via `by_guardian` stream.
- *Message thread screen* — `lib/features/messages/message_thread_screen.dart` (cross-feature — see Messages).
- *Family providers* — `lib/features/family/family_providers.dart`. Five `FutureProvider.autoDispose` PostgREST-backed providers: `familyChildrenProvider`, `familySubjectByIdProvider`, `familyAttendanceForSubjectProvider`, `familyEntriesForSubjectProvider`, `familyAttachmentsForEntityProvider`. All gate on `viewer is GuardianViewer` + `viewer.canSeeSubject(subjectId)`. Replaces the prior Drift reads for per-subject data that the `by_space` stream never delivers to guardian devices.
**Depends on**: Subjects (PostgREST), Guardians, Messages (offline-first via `by_guardian`), Settings (shared text-size sheet), Exports (received-reports card reads `myReceivedExportsProvider`).
**Consumed by**: Nothing — this is a leaf lens.
**Last verified**: 2026-05-23

---

## Groups
**Path**: `lib/features/groups/`
**Purpose**: Classrooms / cohorts. Roster, age band, capabilities, staffing.
**Personas served**: Maya (creates + assigns staff), All staff (read their assigned cohorts).
**Discovery surfaces**:
- Routes: `/groups/new`, `/groups/:id`, `/groups/:id/edit`
- Omnibox: yes — "{Group.name}" (per cohort, classroom category), "Add a {group label}" (action, gated by `can_manage_space`)
- Slash: none directly; group resolution underpins `/attendance {group}` and `/log {kid}`
- Drawer: no
- Settings: no — groups are top-level
**Capabilities**: Read: all members of the space. Write (create / edit): `can_manage_space`.
**Data**: [groups](SCHEMA.md#groups), [group_members](SCHEMA.md#group_members), [subjects](SCHEMA.md#subjects)
**Surfaces**:
- *Group detail* — `lib/features/groups/group_detail_screen.dart`. Roster, today's activity, attendance shortcut, observations shortcut.
- *Group edit* — `lib/features/groups/group_edit_screen.dart`. Create / update form (name, age band, capabilities).
**Depends on**: Members (staff assignment), Subjects (enrollment).
**Consumed by**: Attendance, Entries, Schedule, Subjects, Today (per-cohort cards).
**Last verified**: 2026-05-21

---

## Guardians
**Path**: `lib/features/guardians/`
**Purpose**: Parent / family contact records. Distinct from Members (who are staff).
**Personas served**: Maya (manages roster), Lauren / Devon / Helen / Marcus (are guardians, read their own).
**Discovery surfaces**:
- Routes: none — embedded in Subject detail
- Omnibox: no
- Slash: none
- Drawer: no
- Settings: no
**Capabilities**: Read: `can_observe` (sees the contact list). Write: `can_manage_space`.
**Data**: [guardians](SCHEMA.md#guardians), [subject_guardians](SCHEMA.md#subject_guardians)
**Surfaces**:
- *Guardian section in Subject detail* — embedded in `lib/features/subjects/subject_detail_screen.dart`. Per-subject list of linked parents; add / remove / set primary.
**Status**: data-layer feature folder; no top-level screen.
**Depends on**: Subjects.
**Consumed by**: Exports (recipients), Messages (thread participants), Pickup (authorized people).
**Last verified**: 2026-05-21

---

## Insights
**Path**: `lib/features/insights/`
**Purpose**: System-derived questions from patterns — expiring certs, late streaks, stale vehicles, unwritten observations, low-signal surveys.
**Personas served**: Maya (director-tier oversight). All staff with `can_observe` see the surface.
**Discovery surfaces**:
- Routes: `/insights`
- Omnibox: yes — "Insights"
- Slash: `/insights`
- Drawer: yes — "Insights" (canonical nav, position between Surveys and Vehicles)
- Settings: no
**Capabilities**: None — open to all signed-in staff. Some insights are member-scoped (only the affected staff sees them); some are space-wide.
**Data**: derived — reads [attendance_records](SCHEMA.md#attendance_records), [member_certifications](SCHEMA.md#member_certifications), [vehicle_logs](SCHEMA.md#vehicle_logs), [entries](SCHEMA.md#entries), [captures](SCHEMA.md#captures), [survey_responses](SCHEMA.md#survey_responses). Snooze state in [dismissed_insights](SCHEMA.md#dismissed_insights).
**Surfaces**:
- *Insights screen* — `lib/features/insights/insights_screen.dart`. Card list; tap to drill into the underlying data; swipe to dismiss (per-member snooze).
**Depends on**: Attendance, Certifications, Vehicles, Entries, Captures, Surveys.
**Consumed by**: Today (top-N insight chip).
**Last verified**: 2026-06-01

---

## Invites
**Path**: `lib/features/invites/`
**Purpose**: Staff + guardian onboarding via 6-char invite codes (deep link + QR + share-text); cold-launch & warm-app deep links both supported.
**Personas served**: Maya (creates + revokes staff AND guardian invites), Brianna (redeems on her phone), Lauren / Devon / Helen / Marcus (redeem as guardians).
**Discovery surfaces**:
- Routes: `/settings/team/invite/new`, `/settings/team/invite/:id`
- Omnibox: yes — "Invite a teammate" (action, director-gated, routes directly to `/settings/team/invite/new`); "Invite a parent · {Child name}" (per-subject action, director-gated, routes to the subject edit screen's inline Guardians editor); "Revoke pending invite · {label}" (per-pending-invite action, director-gated, destructive-confirm before InviteActions.revoke). Keyword aliases: parent, family, mom, dad, guardian, revoke, cancel, pending
- Slash: none
- Drawer: no
- Settings: no — embedded in Team / Subject detail
**Capabilities**: Create / revoke staff: `can_invite_staff`. Create guardian invites: `can_manage_space`. Redeem: pre-auth or post-auth without an active space; the RPC takes an explicit `caller_uid` to work around the ES256 auth.uid()-null gotcha (see migration 20260523000003).
**Data**: [invites](SCHEMA.md#invites)
**Surfaces**:
- *Invite create screen* — `lib/features/invites/invite_create_screen.dart`. Role + optional email + expiry chips.
- *Invite share screen* — `lib/features/invites/invite_share_screen.dart`. The created code; copy / QR / share-text.
- *Subject-edit inline Guardians editor* — embedded in `lib/features/subjects/subject_edit_screen.dart`. The Add Guardian flow mints a guardian invite for that specific kid via `createGuardianInvite`; this is the destination of the omnibox "Invite a parent" entry.
- *Deep-link listener* — `lib/features/invites/deep_link_listener.dart`. Captures `differentworld://invite/<code>` and the https fallback into `pendingInviteCodeProvider`; consumed by `home_redeem_invite_host.dart`.
**Depends on**: Members (assigning role), Spaces, Subjects (guardian invites need a subject_id), Guardians (guardian invites create + link rows).
**Consumed by**: Team screen (pending-invites list), Onboarding (redeem path), Subject detail (inline Guardians editor + invite-share navigation).
**Last verified**: 2026-05-23

---

## Kid mode
**Path**: `lib/features/kid_mode/`
**Purpose**: Locked tablet mode — hide the omnibox bar + drawer so a child user can't navigate out of a kid surface (survey-take, kid journal).
**Personas served**: Ava.
**Discovery surfaces**:
- Routes: none — feature is a flag on the shell, not a destination
- Omnibox: no — hidden when active
- Slash: none
- Drawer: no — hidden when active
- Settings: no
**Capabilities**: None — any signed-in staff can toggle when entering a kid surface.
**Data**: None — Notifier<bool> in memory.
**Surfaces**:
- *Provider* — `lib/features/kid_mode/kid_mode_provider.dart`. `kidModeProvider` (Notifier<bool>) drives AppShell visibility.
- *Exit dialog* — `lib/features/kid_mode/kid_mode_exit_dialog.dart`. `showKidModeExitDialog()` — staff-only exit affordance gated by `staff_pin` from the space's capabilities (or confirm-tap when no PIN is set).
- *Auto-enter from survey-take* — `lib/features/surveys/survey_take_screen.dart` enters in `initState`, exits in `dispose`; calls the exit dialog before allowing system-back to leave the screen.
**Status**: PARTIAL. Mechanism + staff-only exit dialog shipped. Kid-journal feature itself + drawer suppression hardening still deferred.
**Depends on**: AppShell.
**Consumed by**: Surveys (auto-enter + exit dialog), future Kid journal.
**Last verified**: 2026-05-22

---

## LiveSession
**Path**: `lib/features/live_session/`
**Purpose**: Phone-as-remote / screen-as-presentation mode for host-run brain-break games (This-or-That, Charades) and the anonymous Brainstorm Board — one device presents on a projector while others control or post over Supabase Realtime.
**Personas served**: All staff (any teacher running a game on a big screen with their phone as the remote; any meeting facilitator posting anonymously).
**Discovery surfaces**:
- Routes: `/live/<game>` for every framework game (`this-or-that`, `charades`, `poll`, `cues`, `rhyme-time`, `starts-with`, `as-if`, `story`, `math-game`, `picker`, `now-next`) → `LiveGameScreen(def:)`; `/board` (BoardScreen); `/join?code=<CODE>&game=<ID>` → `LiveGameScreen(autoJoin:)` — the "one place to join" path, resolves the game from the session id so the joiner never picks; `/present` (PresentHubScreen) and `/present/<game>` for single-device `GameRunner` variants (poll, cues, picker, now-next).
- Omnibox: yes — "Brainstorm Board" (`page.board`, keywords: board, brainstorm, meeting, agenda, ideas, anonymous) → `/board`; "Present to the room" (`page.present`, keywords: present, cast, big screen, projector, room, remote, classroom remote, tv) → `/present`. No direct catalog entries for `/live/this-or-that` or `/live/charades` — those are reached via the Quick Picks screen action and via slash commands respectively.
- Slash: `/live` (alias: `session`) → `/live/this-or-that`; `/present` (aliases: `cast`, `room`, `screen`, `projector`, `remote`) → `/present`; `/charades` (aliases: `act`, `acting`, `mime`, `guess`) → `/live/charades`; `/board` (aliases: `brainstorm`, `meeting`, `agenda`, `ideas`) → `/board`
- Drawer: yes — "Brainstorm Board" for `/board` (canonical nav, position between Missions and Insights); "Present" for `/present` (canonical nav, Activities group, position between Tools and Brain Breaks). `/live/this-or-that` and `/live/charades` have no drawer entry — those remain reached via the Brain Breaks deck and slash commands.
- Settings: no
**Capabilities**: None — open to all signed-in staff.
**Data**: None persisted. Uses Supabase Realtime broadcast + presence — a documented ephemeral-coordination exception (same class as auth and Storage). This-or-That + Charades use channel `dw-session-<CODE>`; Board uses `dw-board-<CODE>`. No Drift tables, no PowerSync sync, no migration.
**Surfaces**:
- *Program lobby* — `lib/features/live_session/live_lobby.dart`. `LobbyAnnouncer` (presenter side: tracks `{code, game, presenter}` on `dw-live-<spaceId>`) + `LobbyWatcher` (watcher side: streams `List<LiveSessionAd>` from presence; subscribe-only, never tracks). Entirely ephemeral Realtime — no durable rows, no PowerSync.
- *Lobby providers* — `lib/features/live_session/live_lobby_providers.dart`. `activeSessionsProvider` (StreamProvider.autoDispose): opens a `LobbyWatcher` for the current space and streams live session ads; tears down on dispose. Drives the Today banner.
- *Today live-session banner* — `lib/features/live_session/live_session_banner.dart`. `LiveSessionBanner` (ConsumerWidget): renders a `primaryContainer` tap-to-join card at the top of Today when `activeSessionsProvider` has at least one session; auto-hidden when empty. Single session → direct `/join?code=…&game=…` push; multiple sessions → `showGlassSheet` picker. Mounted in `lib/features/today/widgets/today_sections.dart`.
- *Generic live screen* — `lib/features/live_session/live_game_screen.dart`. **THE one live UI for every `GameDefinition`** (This-or-That, Charades, Poll, Cues, Rhyme Time, Letter Words, As-If, Story, Math Game, Spotlight, Now & Next): lobby (Present / Join, + "I'm acting" when `def.hasSecretRole`), presenter view (`buildStage`), secret view (`buildSecretStage` — the actor), controller view (sees `buildSecretStage ?? buildStage` + `buildControls`/the intent bar). `autoJoin` param: when set (`{code, role}`), skips the lobby and enters as a controller immediately — used by the `/join` route so the banner's one-tap join works. Presenter auto-announces to `LobbyAnnouncer` on `_open`; tears down on `_leave`/`dispose`. Charades is no longer a bespoke screen — it's `games/games/charades_game.dart` (a `GameDefinition` with `hasSecretRole`/`buildSecretStage`); `charades_live_screen.dart` + `charades.dart` were DELETED. `DataSeededGame` (`games/data_seeded_game.dart`) wraps the live-vs-runner branch for Drift-seeded games (Spotlight, Now & Next).
- *LiveSession / SessionRole / LiveReducer / LiveStatus* — `lib/features/live_session/live_session.dart`. Game-agnostic protocol layer: wraps a Supabase Realtime channel; supports `SessionRole.{present, control, secret}`. Each game injects its reducer via `LiveGameController`.
- *Generic live screen* — `lib/features/live_session/live_game_screen.dart`. **THE one live UI for every `GameDefinition`** (This-or-That, Charades, Poll, Cues, Rhyme Time, Letter Words, As-If, Story, Math Game, Spotlight, Now & Next): lobby (Present / Join, + "I'm acting" when `def.hasSecretRole`), presenter view (`buildStage`), secret view (`buildSecretStage` — the actor), controller view (sees `buildSecretStage ?? buildStage` + `buildControls`/the intent bar). Charades is no longer a bespoke screen — it's `games/games/charades_game.dart` (a `GameDefinition` with `hasSecretRole`/`buildSecretStage`); `charades_live_screen.dart` + `charades.dart` were DELETED. `DataSeededGame` (`games/data_seeded_game.dart`) wraps the live-vs-runner branch for Drift-seeded games (Spotlight, Now & Next).
- *Board session* — `lib/features/live_session/board_session.dart`. `BoardSession` over Realtime channel `dw-board-<CODE>`; broadcasts `idea` events with no sender identity (anonymous by design); append-only wall; presence for participant count.
- *Board screen* — `lib/features/live_session/board_screen.dart`. Lobby → presenter wall (all ideas tiled, projected) or contributor post-field (phone keyboard, tap to send). Routes to `/board`. Realizes VISION.md dream #5 (anonymous collective voice in a meeting).
- *Entry action on Quick Picks* — `lib/features/activity_runtime/this_or_that_screen.dart`. `SecondaryActionButton` (cast icon, tooltip "Present on a big screen") → `context.push('/live/this-or-that')`. Primary discovery path for the This-or-That live session.
- *Brain Breaks deck card* — `lib/features/activity_runtime/brain_breaks_screen.dart`. "Charades" card → `/live/charades`.
**Depends on**: ActivityRuntime (`content_bank.dart` — seeds This-or-That pairs and the 24 Charades prompts via `ContentKind.charades`); Games (`game_registry.dart` — `gameById` resolves game ids in the `/join` route and in `LiveSessionBanner._gameName`).
**Consumed by**: Today (`live_session_banner.dart` mounted in `today_sections.dart`; `activeSessionsProvider` drives the banner).
**Last verified**: 2026-06-03

---

## Messages
**Path**: `lib/features/messages/`
**Purpose**: Staff↔Guardian per-child thread. Async written communication.
**Personas served**: All staff (write to family), Lauren / Devon / Helen / Marcus (receive + reply).
**Discovery surfaces**:
- Routes: `/messages`, `/messages/:subjectId/:guardianId`
- Omnibox: yes — "Messages" (gated by guardian-with-children — guardian-side page entry). Staff side: per-subject "Messages · {Child name}" action (gated by `can_observe`, routes to subject detail where the per-thread navigation lives). Keyword aliases: message, chat, family, parent, mom, dad, guardian.
- Slash: none
- Drawer: no — guardians may eventually get a dedicated drawer entry
- Settings: no
**Capabilities**: Staff: `can_observe` (gates "can talk to a family"). Guardian: linked to subject via [subject_guardians](SCHEMA.md#subject_guardians).
**Data**: [messages](SCHEMA.md#messages)
**Surfaces**:
- *Message thread screen* — `lib/features/messages/message_thread_screen.dart`. One thread per (subject, guardian); newest-at-bottom, send composer at bottom.
- *Family messages index* — `lib/features/family/family_messages_screen.dart` (cross-feature). Guardian's view of all their threads.
**Depends on**: Subjects, Guardians.
**Consumed by**: Family lens (Lauren), Today (unread-messages chip — not yet wired).
**Last verified**: 2026-05-21

---

## Omnibox
**Path**: `lib/features/omnibox/`
**Purpose**: The persistent bottom composer — search / capture / slash command / voice. The spine of the app's interaction model.
**Personas served**: All staff.
**Discovery surfaces**:
- Routes: `/search` (OmniboxSearchScreen)
- Omnibox: this IS the omnibox — its own catalog is the schema for every other feature's discovery
- Slash: this IS the slash dispatcher
- Drawer: yes — a "Search anything" tile at the top of the drawer mirrors the bar
- Settings: no
**Capabilities**: None — visible to all signed-in members, hidden in kid mode.
**Data**: None directly. Reads providers for catalog (groups, subjects, activities, locations, vehicles, members). Persists pinned + recent IDs in SharedPreferences.
**Surfaces**:
- *Bottom omnibox bar* — `lib/features/omnibox/bottom_omnibox_bar.dart`. The persistent composer in AppShell.
- *Omnibox search screen* — `lib/features/omnibox/omnibox_search_screen.dart`. The suggestion / results list at `/search`. Wave 24 (2026-05-22) hardening: dispatch context is captured via `Navigator.of(context, rootNavigator: true).context` BEFORE `context.pop()` so the post-pop `onSelect` / `runSlash` / "see all inbox" callbacks fire against a live BuildContext rather than the screen's own (which deactivates the instant pop runs). Fixes the "tap a suggestion, nothing happens" bug.
- *Omnibox catalog* — `lib/features/omnibox/omnibox_results.dart` + `omnibox_catalog.dart`. Source of all OmniboxEntry rows. Subjects whose `groupId` is null are filtered out at the catalog layer (the subject-detail route is nested under cohort — there's nowhere for a no-cohort subject to navigate to). "If the user can't do it, don't show it" invariant.
- *Slash commands* — `lib/features/omnibox/slash_commands.dart`. The `/today`, `/captures`, `/log {kid}`, etc. dispatch table.
**Interaction invariants (Wave 24, 2026-05-22)**:
- *Push on focus, not on keystroke.* AppShell's bar focus listener pushes `/search` the moment the bar gains focus (tap → suggestion panel + keyboard + cursor land together). Typing does NOT trigger a push — by the time `_onQueryChanged` fires, `/search` is already on top from the focus event. Single source of truth for "is the search route open?" is `_focus.hasFocus` plus the in-flight push lock.
- *Lock held for /search lifetime.* `_pushingSearch` is set true on push, released when `context.push('/search').then(...)` resolves (i.e. when the route pops). Holding the lock across the route's full lifetime — not just one frame — means rapid re-focus events can never stack duplicate `/search` routes. At-most-one `/search` in the navigator stack, regardless of typing/tap cadence.
- *Re-grant focus + force IME show on rotation.* The push briefly rotates the FocusScope's active node off the bar, which on Android dismisses the soft keyboard. If focus loss lands within 500ms of the most recent push (`_lastPushAt`), AppShell calls `_focus.requestFocus()` + `SystemChannels.textInput.invokeMethod('TextInput.show')` to keep the IME up. Older intentional taps-outside (>500ms) are left alone.
- *Canonical widget test* — `test/widget/omnibox_interaction_test.dart` exercises tap-→-push-→-IME-up-→-type-→-suggestion-tap-→-dispatch end-to-end. The `interaction-guard` agent + `~/.claude/hooks/interaction-stop-gate.sh` stop-hook enforce that any change in `app_shell.dart` / `omnibox_search_screen.dart` / `bottom_omnibox_bar.dart` triggers a re-run of this test. CLAUDE.md "Interaction invariants" section is the durable contract.
**Depends on**: Every feature (catalog references their routes); Voice (mic), Captures (capture mode submits here), Schedule (substitute-lead sheet invoked from "Cover today · {Group}").
**Consumed by**: AppShell (mounts the bar + listens for focus).
**Last verified**: 2026-05-22

---

## Onboarding
**Path**: `lib/features/onboarding/`
**Purpose**: Post-auth, pre-space flow. Lets a new signed-in user join an existing space (via invite code) or create a new one.
**Personas served**: Brianna (joining), Maya (creating).
**Discovery surfaces**:
- Routes: `/onboarding/join-or-create` (and any sub-routes)
- Omnibox: no — pre-space surface
- Slash: none
- Drawer: no — drawer only mounts after space is selected
- Settings: no
**Capabilities**: None — pre-space.
**Data**: [spaces](SCHEMA.md#spaces), [members](SCHEMA.md#members), [invites](SCHEMA.md#invites)
**Surfaces**:
- *Join-or-create screen* — `lib/features/onboarding/join_or_create_screen.dart`. Two paths: enter an invite code, or create a new program. Pushes Create when the user chooses to start fresh.
- *Create space screen* — `lib/features/onboarding/create_space_screen.dart`. Bare-minimum form (program name + vertical). Inserts the `spaces` row + flips the current member into it.
**Depends on**: Invites (redeem), Auth.
**Consumed by**: Router (post-login redirect when `viewer.spaceId == null`).
**Last verified**: 2026-05-22

---

## Photos
**Path**: `lib/features/photos/`
**Purpose**: Signed-URL minting + cached display for person photos (avatars, observation attachments). Bytes live in Supabase Storage's private `person-photos` bucket; rows carry only the bucket-relative path.
**Personas served**: All staff (upload + view), All guardians (view their own children).
**Discovery surfaces**:
- Routes: none — utility widgets
- Omnibox: no
- Slash: none
- Drawer: no
- Settings: no
**Capabilities**: Read via signed URL (RLS-scoped to space membership; first path segment must match caller's `members.space_id`). Write: any staff who can mutate the parent row.
**Data**: References [members](SCHEMA.md#members).`avatar_url`, [subjects](SCHEMA.md#subjects).`photo_url`, [attachments](SCHEMA.md#attachments) — none of those tables is owned by this feature.
**Surfaces**:
- *PersonAvatar widget* — `lib/shared/widgets/person_avatar.dart`. Renders an avatar by minting a 1-hour signed URL.
- *PersonPhotoNetwork* — used by gallery + viewer sites.
- *Signed-URL provider* — `lib/features/photos/person_photo_url.dart`. `signedPersonPhotoUrlProvider` is the single mint point; handles legacy full-URL rows via `extractPersonPhotoPath`.
**Depends on**: Supabase Storage client.
**Consumed by**: Members, Subjects, Entries (attachment display), Family.
**Last verified**: 2026-05-21

---

## Poster
**Path**: `lib/features/poster/`
**Purpose**: Tile one image across several Letter/A4 pages — print all of them and tape them into one big poster (a kid's drawing blown up, a welcome banner, a giant map). The grid auto-fits the image's shape; you can reposition the crop, rotate, and add trim/assembly guides.
**Personas served**: All staff (a maker / room-decoration utility). Not guardians — staff-only; the router allow-list bounces guardians off `/poster`.
**Discovery surfaces**:
- Routes: `/poster`
- Omnibox: yes — "Poster — print big" (keywords: poster, print big, blow up, enlarge, banner, big print, large print, tile, engineer print, wall art, welcome sign, sign). Gated `viewer is! GuardianViewer`.
- Slash: none
- Drawer: no
- Settings: yes — "Poster" row in the Resources `_SettingsGroup`.
**Capabilities**: None — open to all signed-in staff. No child data touched.
**Data**: None — fully local. The picked image bytes never persist to the cloud (no DB row, no Storage upload); the PDF is generated on-device and handed to the OS print / share sheet. The chosen size/fit/paper/labels/guides options persist locally in SharedPreferences (`PosterPrefs`).
**Surfaces**:
- *PosterScreen* — `lib/features/poster/poster_screen.dart`. Pick image (gallery/camera, capped 6000 px; preview decodes downsized via `cacheWidth`); live WYSIWYG preview with cut-lines; Size (2–5) + "Fit to image shape" + Fit (edge-to-edge / whole image) + Paper (Letter/A4) + Page orientation (Auto / Portrait / Landscape — forces every page to that turn regardless of image shape) + Print quality (Standard/High/Lossless) + Corner labels + Assembly guides controls; Rotate (bakes 90° into the bytes) + Reset crop; in Fill mode the preview is interactive (drag to pan, pinch to zoom); three delivery actions — "Save PDF" (share sheet → Files/Drive/email → computer, with "print at 100%" guidance), "Save PNG" (single tiled image for programs that print images), "Print" (OS print dialog); determinate progress bar during tile render; working/error banners.
- *Poster engine* — `lib/features/poster/poster_engine.dart`. Pure geometry (`computePosterLayout` picks cols×rows + page orientation to match the image aspect; `posterCoverCrop`/`posterViewRect` = fill crop with zoom + focal point; `posterContainPlacement` = whole-image fit) + `rotateImageQuarterTurn` + `renderPosterTiles` (heavy decode/crop/resize in an isolate; web falls back to the main thread; per-quality DPI cap + JPEG-or-PNG tile encoding) + `buildPosterPdf` (Letter/A4, portrait/landscape, optional trim border + dashed cut line + crop marks + an "Assembly map" page; built-in Helvetica — no network). `renderPosterTilesForTest` is the `@visibleForTesting` sync seam.
- *Poster options* — `lib/features/poster/poster_models.dart`. `PosterFit {fill, whole}`, `PosterPaper {letter, a4}`, `PosterQuality {standard, high, lossless}`, `PosterOrientation {auto, portrait, landscape}`, `PosterOptions {size, fitShape, fit, paper, orientation, quality, labels, guides}`.
- *Poster prefs* — `lib/features/poster/poster_prefs.dart`. Load/save the durable options (defensive: corrupt/missing/out-of-range → defaults).
**Depends on**: `image` (decode/rotate/crop/resize), `pdf` + `printing` (PDF + OS print/share), `image_picker`, `shared_preferences`, EdgeScaffold + shared chrome primitives.
**Consumed by**: none.
**Last verified**: 2026-06-03

---

## Pickup
**Path**: `lib/features/pickup/`
**Purpose**: Authorized-pickup records — who's allowed to take a child home.
**Personas served**: Maya (configures), All staff (verifies at dismissal), Lauren / Devon (their entries).
**Discovery surfaces**:
- Routes: none — embedded in Subject detail
- Omnibox: no
- Slash: none
- Drawer: no
- Settings: no
**Capabilities**: Configure: `can_authorize_pickup` (gated cap). Verify at dismissal: all staff.
**Data**: Lives in [subjects](SCHEMA.md#subjects).capabilities JSONB (`pickup_people`, `authorized_pickup_guardian_ids`, `pickup_strict`).
**Surfaces**: Status: not yet wired to UI. Authorized-pickup section embedded in `lib/features/subjects/subject_detail_screen.dart` is the planned home.
**Status**: stub — data shape lives in `subjects.capabilities` but no dedicated screen yet.
**Depends on**: Subjects, Guardians.
**Consumed by**: Future end-of-day dismissal flow.
**Last verified**: 2026-05-21

---

## Review
**Path**: `lib/features/review/`
**Purpose**: Guided reflection — weekly (one-question-per-page walk) and yearly (annual re-grounding).
**Personas served**: Maya (director reflection). All signed-in staff can run the walk; guardians (Lauren, Devon, Helen, Marcus) don't reach `/review`.
**Discovery surfaces**:
- Routes: `/review`, `/review/year`
- Omnibox: yes — "Weekly review", "Yearly review"
- Slash: `/review`
- Drawer: no
- Settings: no
**Capabilities**: None — open to all signed-in staff.
**Data**: Reads [entries](SCHEMA.md#entries), [captures](SCHEMA.md#captures), [tasks](SCHEMA.md#tasks); writes a synthesis as a Capture (or future "Review" entry kind).
**Surfaces**:
- *Weekly review screen* — `lib/features/review/weekly_review_screen.dart`. One question per page; "walk me through it" cadence.
- *Yearly review screen* — `lib/features/review/yearly_review_screen.dart`. Annual reflection.
**Depends on**: Entries, Captures, Tasks.
**Consumed by**: Today (review prompt when due).
**Last verified**: 2026-05-21

---

## Schedule
**Path**: `lib/features/schedule/`
**Purpose**: Per-cohort, per-day block planning — activities, locations, leads, and one-tap "X is out, Y is covering" substitution.
**Personas served**: Maya (plans the week — tablet grid deferred), Coach Sam (sees blocks + pre-block brief), Pat (covers absent leads), All staff (see their day).
**Discovery surfaces**:
- Routes: `/schedule`, `/schedule/block`
- Omnibox: yes — "Schedule" (with keywords: day, block, rotation, agenda, plan, field trip, trip), "Schedule · {Group.name}" (per cohort), "Cover today · {Group.name}" (per cohort, action, gated by `can_manage_schedule`)
- Slash: `/schedule`
- Drawer: yes — "Schedule" (main destinations, position 2)
- Settings: no
**Capabilities**: Read: all members. Write: `can_manage_schedule` (director / lead-tier).
**Data**: [schedule_blocks](SCHEMA.md#schedule_blocks), [activities](SCHEMA.md#activities), [locations](SCHEMA.md#locations), [trip_logistics](SCHEMA.md#trip_logistics), [trip_vehicles](SCHEMA.md#trip_vehicles), [permission_slips](SCHEMA.md#permission_slips), [headcounts](SCHEMA.md#headcounts), [entries](SCHEMA.md#entries) (reads via `schedule_block_id` back-reference — live-block capture tagging, see migration `20260531000002`), [activity_supplies](SCHEMA.md#activity_supplies) (reads via `activitySupplyLinksProvider` in the activity editor), [supplies](SCHEMA.md#supplies) (reads via `suppliesProvider` to populate the pack-list picker in the activity editor)
**Surfaces**:
- *Schedule screen* — `lib/features/schedule/schedule_screen.dart`. Cohort tabs × time-of-day list (phone-friendly). Tablet grid deferred for Maya.
- *Block edit screen* — `lib/features/schedule/block_edit_screen.dart`. Create / edit one block (start, end, activity, lead, location, kind).
- *Substitute lead sheet* — `lib/features/schedule/widgets/substitute_lead_sheet.dart`. Modal bottom sheet: pick absent lead → pick cover. Bulk-writes `lead_substitute_member_id` for all matching blocks on the day. Surfaceable directly from the omnibox via "Cover today · {Group.name}" (Pat persona) without first entering the schedule editor.
- *Leading-today card* — `lib/features/schedule/widgets/leading_today_card.dart`. Embedded on home; signed-in lead's blocks + cabin notes for today.
**Depends on**: Groups, Members, Activities, Locations, Vehicles (trip assignment), Entries (reads `schedule_block_id` back-reference for live-block capture tagging), Supplies (pack-list picker in `activity_edit_screen.dart` reads `suppliesProvider` + `activitySupplyLinksProvider`).
**Consumed by**: Today (leading-today card), Attendance (block-context for headcounts), Captures (block-context tag), Omnibox (substitute-lead sheet invoked from the per-cohort "Cover today" entry).
**Last verified**: 2026-06-01

---

## Settings
**Path**: `lib/features/settings/`
**Purpose**: Library / admin surfaces — program config, team, fleet, locations, activities, member detail, plus device preferences.
**Personas served**: Maya (all of it), All staff (preferences + read-only team / vehicles), Helen (text-size override, also reachable from Family Today header), Jordan (outdoor-mode toggle).
**Discovery surfaces**:
- Routes: `/settings`, `/settings/program`, `/settings/team`, `/settings/team/:id`, `/settings/roles`, `/settings/vehicles`, `/settings/locations`. (Activities lives at `/activities`, not under settings, because it's used more often than configured.)
- Omnibox: yes — "Settings", "Program settings", "Team", "Roles & permissions", "Vehicles", "Locations", "Activities"
- Slash: none directly; sub-features may add some later
- Drawer: yes — "Settings" (main destinations, position 5)
- Settings: this IS the settings screen
**Capabilities**: Read: all members. Program settings: `can_manage_space`. Team write / vehicles write: `can_manage_space`. Roles screen is read-only for everyone (the catalog itself is a code constant).
**Data**: [spaces](SCHEMA.md#spaces), [members](SCHEMA.md#members), [locations](SCHEMA.md#locations) plus what each sub-screen owns. Roles screen reads no DB — the role catalog is `RoleBundles.rolesFor(vertical)` / `defaultsFor()` in `lib/core/capabilities/`.
**Surfaces**:
- *Settings screen* — `lib/features/settings/settings_screen.dart`. Grouped list (Account / Space / Preferences / About).
- *Program settings* — `lib/features/settings/program_settings_screen.dart`. Per-space capability flags + pickup window.
- *Team screen* — `lib/features/settings/team_screen.dart`. Members + pending invites.
- *Member detail* — `lib/features/settings/member_detail_screen.dart`. Per-staff profile + certifications.
- *Roles & permissions* — `lib/features/settings/roles_screen.dart`. Read-only directory of every role offered in the active vertical + the default capabilities each one ships with. Surfaces cert-gated caps in a separate group so directors don't think "the bundle says false; I'll flip it" without realizing the cert is the actual gate. Shipped 2026-05-22 (Wave 36).
- *Locations list* — `lib/features/settings/locations_list_screen.dart`. Place catalog for scheduling.
- *Shared text-size tile / picker* — `lib/features/settings/widgets/text_size_tile.dart`. Public `TextSizeTile` + `showTextSizePicker(context, ref)` helper, reused by Family Today so guardians can reach the override without a Settings screen.
**Depends on**: Members, Spaces, Vehicles, Locations, Activities, Invites, Certifications, Capabilities catalog.
**Consumed by**: Most features (config), Helen (text scale — staff AND family-side via shared picker), Jordan (outdoor mode), Family Today (text-size picker).
**Last verified**: 2026-05-23

---

## Missions
**Path**: `lib/features/missions/`
**Purpose**: The program's catalog of real jobs kids do — each with a manual (rules), a practiceable checklist (actions), and an evidence kind — so responsibility is concrete, doable, and verifiable.
**Personas served**: Maya, Coach Sam, Brianna (directors/leads maintain catalog via `canManageSpace`); Ava and all kids (will claim + do missions in slice 2); All staff (view).
**Discovery surfaces**:
- Routes: `/settings/missions`
- Omnibox: yes — "Missions" (id `page.missions`), keywords: missions, jobs, helpers, chores, responsibilities, equipment manager, snack helper → `/settings/missions`
- Slash: none
- Drawer: yes — "Missions" (canonical nav, position between Brain Breaks and Brainstorm Board)
- Settings: no
**Capabilities**: View: all signed-in staff. Create / edit / delete: `canManageSpace` (director / lead). Slice 2 will add kid-side claim with no cap gate.
**Data**: [missions](SCHEMA.md#missions)
**Surfaces**:
- *Missions list screen* — `lib/features/missions/missions_list_screen.dart`. EdgeScaffold; four states (loading / empty / error / data); empty state offers "Add the starter set (11)" + "Add your own"; mission tiles; tap → read-only detail sheet (icon, builds, age, rules, numbered steps, evidence kind); edit sheet. Edit actions gated by `viewer.canManageSpace`.
- *Missions providers* — `lib/features/missions/missions_providers.dart`. `missionsProvider` (StreamProvider → `db.missionsDao.watchInSpace`); `MissionActions` Notifier with create / update_ / delete_ / addStarterSet (one-tap seed from templates).
- *Mission templates* — `lib/features/missions/mission_templates.dart`. `MissionTemplate` + `missionTemplates` (11 starter jobs: Equipment Manager, Snack Helper, Cleanup Crew, Supply Keeper, Line Leader, Greeter, Library Keeper, Lights & Doors, Recycle Captain, Plant & Pet Caretaker, Peace Buddy); `MissionEvidenceKind` enum (photo/count/note/check); actions JSON codec (encode/decodeMissionActions).
**Depends on**: Nothing — leaf catalog feature in slice 1.
**Consumed by**: Nothing in slice 1. Slice 2 will add mission_assignments + Entries/Attachments as the evidence destination.
**Last verified**: 2026-06-01 (nav refactor)

---

## Supplies
**Path**: `lib/features/supplies/`
**Purpose**: The program's real-world inventory catalog — track items (markers, paper, balls) once, flag low stock, and reference by id from activities.
**Personas served**: Maya, Coach Sam, Brianna (directors/leads maintain via `canManageSpace`); All staff (view).
**Discovery surfaces**:
- Routes: `/settings/supplies`
- Omnibox: yes — "Supplies" (id `page.supplies`), keywords: supplies, inventory, materials, stock, markers, paper → `/settings/supplies`
- Slash: none
- Drawer: no — library surface (same convention as Locations, Activities)
- Settings: no — omnibox is the canonical discovery entry; Settings screen is preferences-only per the library convention
**Capabilities**: View: all signed-in staff. Create / edit / delete: `canManageSpace` (director / lead).
**Data**: [supplies](SCHEMA.md#supplies), [activity_supplies](SCHEMA.md#activity_supplies) (read via `activitySupplyLinksProvider` + written via `ActivitySuppliesActions`), [locations](SCHEMA.md#locations) (read for the Location lens — `location_id` FK added in migration `20260601000003`)
**Surfaces**:
- *Supplies list screen* — `lib/features/supplies/supplies_list_screen.dart`. EdgeScaffold; three-view toggle (Category / Location / Running low) backed by `_SuppliesView` enum; `groupSuppliesByLocation` groups by the `location_id` FK when in Location mode; all four states (loading / empty / error / data); add/edit via `openSupplyEditSheet`. Edit actions gated by `viewer.canManageSpace`. Low-stock highlighting via `isLowStock` helper.
- *Supply edit sheet* — inline glass sheet opened from `SuppliesListScreen`. Create / update a supply row (name, category, quantity, unit, location_id → Locations FK, free-text sub-spot, low_stock_threshold, notes, photo_url).
- *Activity supplies providers* — `lib/features/supplies/activity_supplies_providers.dart`. `activitySupplyLinksProvider` (StreamProvider.family by activityId → `db.activitySuppliesDao.watchForActivity`); `ActivitySuppliesActions` Notifier with `setForActivity` (replace-all write via `replaceForActivity`).
- *Supplies providers* — `lib/features/supplies/supplies_providers.dart`. `suppliesProvider` (StreamProvider → `db.suppliesDao.watchInSpace`); `supplyActionsProvider` (`SupplyActions` Notifier with create / update_ / delete_).
- *Supplies grouping helpers* — `lib/features/supplies/supplies_grouping.dart`. Pure functions: `supplyCategoryLabel`, `isLowStock`, `groupSuppliesByCategory`, `groupSuppliesByLocation`, `supplyLocationLabel`, `formatSupplyNumber`. No UI — consumed by the list screen.
**Depends on**: Locations (Location lens reads `locationsProvider` for `location_id → name` resolution).
**Consumed by**: Activities / Schedule (`activity_edit_screen.dart` imports `activity_supplies_providers.dart` and `supplies_providers.dart`; the structured "Supplies needed" picker writes `activity_supplies` rows on save).
**Last verified**: 2026-06-01

---

## Subjects
**Path**: `lib/features/subjects/`
**Purpose**: The child / student / patient record. Profile, health intake, photo, drop-off / pickup, guardian links.
**Personas served**: Maya (manages roster), All staff (read), Lauren / Devon (read their own via Family lens).
**Discovery surfaces**:
- Routes: `/groups/:id/students/new`, `/groups/:id/students/:sid`, `/groups/:id/students/:sid/edit`, `/subjects/:id/health`
- Omnibox: yes — "{FirstName} {LastName}" (per subject), "Add a {subject label} · {Group.name}" (action)
- Slash: subject resolution underpins `/log {kid}`
- Drawer: no
- Settings: no — subjects are top-level
**Capabilities**: Read: all members of the space. Write: `can_manage_space` (create) and `can_observe` (some inline edits).
**Data**: [subjects](SCHEMA.md#subjects), [guardians](SCHEMA.md#guardians), [subject_guardians](SCHEMA.md#subject_guardians)
**Surfaces**:
- *Subject detail* — `lib/features/subjects/subject_detail_screen.dart`. Profile + guardians + recent observations.
- *Subject edit* — `lib/features/subjects/subject_edit_screen.dart`. Create / update form.
- *Health profile screen* — `lib/features/subjects/health_profile_screen.dart`. Medical intake (allergies, dietary, IEP, etc.).
**Depends on**: Groups, Guardians, Photos.
**Consumed by**: Attendance, Entries, Exports, Family, Messages, Surveys.
**Last verified**: 2026-05-21

---

## Surveys
**Path**: `lib/features/surveys/`
**Purpose**: Anonymous questionnaires kids fill out themselves — director taps "Start a new survey" on a template, hands the device to a kid, who picks a reader voice + tells us their age band / grade / school on the About-you page, then answers one-question-per-page. No kid name is ever attached to the response.
**Personas served**: Maya (reviews cross-cohort trends via the table view), Ava (kid-mode take). Guardians (Lauren, Devon, Helen, Marcus) don't reach the survey surface.
**Discovery surfaces**:
- Routes: `/surveys`, `/surveys/:templateId`, `/surveys/:templateId/take`, `/surveys/:templateId/table`
- Omnibox: yes — "Surveys"
- Slash: none
- Drawer: yes — "Surveys" (canonical nav, position between Insights and Vehicles)
- Settings: no — surveys are top-level
**Capabilities**: None for taking. Authoring templates is gated by `can_manage_space`.
**Data**: [survey_responses](SCHEMA.md#survey_responses), [survey_picker_options](SCHEMA.md#survey_picker_options). Templates live in code today (no `survey_templates` table yet).
**Surfaces**:
- *Survey index* — `lib/features/surveys/survey_list_screen.dart`. List of templates with a per-template completed-response counter.
- *Survey template detail* — same file. Big "Start a new survey" button + history strip linking to the table view. No kid roster (responses are anonymous).
- *Survey take screen* — `lib/features/surveys/survey_take_screen.dart`. Generates a fresh response id per landing (no resume). Page 0 is the combined About-you surface (voice picker + age band / grade / school chips + Start). Auto-enters kid mode; 5-tap top-right corner is the staff-exit gesture.
- *Survey table* — `lib/features/surveys/survey_table_screen.dart`. One row per response, anonymized (recorded-at timestamp + identity columns + answer slots). Status filter (all / completed / drafts). CSV export.
**Depends on**: Kid mode, Voice (Deepgram Aura 2 TTS).
**Consumed by**: Insights (low-signal survey detection).
**Last verified**: 2026-06-01

---

## Tasks
**Path**: `lib/features/tasks/`
**Purpose**: To-do list with optional subject linkage. Promotion destination from Captures.
**Personas served**: All staff (Maya delegates, Jordan + Coach Sam do).
**Discovery surfaces**:
- Routes: `/tasks`, `/tasks/new`
- Omnibox: yes — "Tasks"
- Slash: `/tasks`
- Drawer: yes — "Tasks" (main destinations, position 4)
- Settings: no
**Capabilities**: None — open to all signed-in staff.
**Data**: [tasks](SCHEMA.md#tasks)
**Surfaces**:
- *Tasks screen* — `lib/features/tasks/tasks_screen.dart`. Pending list + completed-today.
- *Task screen* — `lib/features/tasks/task_screen.dart`. Create / edit one task.
**Depends on**: Subjects (optional link), Captures (promotion source).
**Consumed by**: Today (open-tasks count), Captures (promotion destination).
**Last verified**: 2026-05-21

---

## Curricula (Through My Eyes)
**Path**: `lib/features/curricula/`
**Purpose**: Editorial reference content — a 3-week / 6-session photography curriculum ("Through My Eyes") for ages 5-7. Each session has setup instructions, a game (rules + duration), a "looking together" guided discussion, 3 expandable AI label examples, an end ritual, a takeaway highlight, and a materials list. A second view, "Vocabulary Journey," surfaces which photography terms attach to which session (~30 terms across 6 sessions). Shipped as a Dart const today; a per-space overrides table can layer on later if directors ask to author their own sessions.
**Personas served**: All staff — particularly Coach Sam / specialists running a structured program; Maya as a curriculum reviewer.
**Discovery surfaces**:
- Routes: `/settings/curricula/photo`
- Omnibox: yes — "Through My Eyes" (keywords: through my eyes, photo curriculum, photography, camera, photo program, gallery, six games)
- Slash: no
- Drawer: no
- Settings: yes — "Through My Eyes" row under Resources group (alongside Teacher Toolkit)
**Capabilities**: None — open to every signed-in staff member. Read-only in Wave 164. Guardian-gated at the omnibox layer (router redirect would bounce them anyway).
**Data**: None (Wave 164, Dart const catalog). Stable per-session slugs (`photo.s1.click-game`, etc.) are the contract a future overrides table would join on.
**Surfaces**:
- *Photo curriculum catalog* — `lib/features/curricula/photo_curriculum.dart`. Dart const `photoCurriculum`: 6 sessions × 9 fields (slug, number, week, day, title, color, glyph, bigIdea, setup, gameName, gameRules, gameDuration, lookingTogether, aiExamples, endRitual, takeaway, materials). Also `vocabJourney`: 6 stops × terms + natural note.
- *Photo curriculum screen* — `lib/features/curricula/photo_curriculum_screen.dart`. Session selector dots (6, color-progressed), SegmentedButton view toggle (Sessions / Vocabulary), session body with SectionCards for setup/game/looking/end-ritual/takeaway/materials + tappable-expand AI example cards, vocab journey with one card per session + total + sample certificate.
**Depends on**: Nothing — pure content.
**Consumed by**: Nothing yet. Future: a curriculum could attach to schedule blocks as the activity series for an afternoon, with each session auto-becoming a scheduled block.
**Last verified**: 2026-05-26

---

## Toolkit
**Path**: `lib/features/toolkit/`
**Purpose**: Editorial reference library — 30 in-the-moment teaching moves (Celebrate, Tough Moments, Know Your Kids, Classroom Culture, Self-Care). Search-by-situation + tool detail (Instead of / Try this / Why this works / Quick script). Content ships in the binary; Wave 162 will add a per-space overrides table for director-authored additions and built-in hides.
**Personas served**: All staff. Especially Jordan (in-the-moment scripts when it falls apart), Coach Sam (door-greeting + cohort culture), Brianna (specific-notice + 5:1 ratio while learning the room), Lauren (parent-text language).
**Discovery surfaces**:
- Routes: `/settings/toolkit`
- Omnibox: yes — "Teacher Toolkit" (keywords cover toolkit, scripts, phrases, celebrate, praise, tough, angry, meltdown, parent text, morning, door greeting, cool down, repair, boundary, self care, burnout)
- Slash: no
- Drawer: no
- Settings: yes — "Teacher Toolkit" row under Resources group
**Capabilities**: None — open to every signed-in staff member. Read-only in Wave 161.
**Data**: None (Wave 161, Dart const catalog). Wave 162 will add a `toolkit_overrides` table joined on `builtin_slug` to the const list.
**Surfaces**:
- *Toolkit catalog* — `lib/features/toolkit/toolkit_catalog.dart`. Dart const `toolkitCatalog`: 5 categories × 6 tools, each with stable slug + name/when/instead/tryThis/why/quick fields.
- *Toolkit screen* — `lib/features/toolkit/toolkit_screen.dart`. Search across all tools, category strip, expandable tool detail card with Instead/Try pair + Why-this-works rail + optional Quick-script chip.
**Depends on**: Nothing — pure content.
**Consumed by**: Nothing yet. Future: tagged captures could surface a "Try this" toolkit suggestion contextually.
**Last verified**: 2026-05-26

---

## Speak
**Path**: `lib/features/speak/`
**Purpose**: Paste any prompt / quote / block, pick a voice, and hear it read aloud while it takes the stage as big, elegant, editorial type — one line at a time, the spoken word swelling in weight as the voice lands on it. A read-aloud showpiece for the room and a follow-along aid for emerging readers.
**Personas served**: All staff. Especially Jordan + Coach Sam (run a prompt with the room), Lauren-side read-aloud for emerging readers. Staff-facing (gated `viewer is! GuardianViewer`).
**Discovery surfaces**:
- Routes: `/speak`
- Omnibox: yes — "Speak" (keywords cover speak, read aloud, read it, karaoke, subtitles, captions, lyrics, text to speech, voice, narrate, prompt, quote)
- Slash: `/speak` (aliases: `read`, `karaoke`, `subtitles`, `narrate`, `voice`)
- Drawer: no
- Settings: no
- Also on the Tools shelf — registered as a runnable `ThinkingTool` (`id: speak` → `/speak`) in `runnableThinkingTools`.
**Capabilities**: None — open to every signed-in staff member. Read-only / ephemeral.
**Data**: None synced. Audio (`.mp3`) + char-level alignment (`.json`) are cached server-side in the public `tts-cache` Storage bucket, keyed by a content hash — no PowerSync tables, nothing persisted on-device. Only the (staff-authored) prompt text is sent; no child PII. Two variable display fonts (Fraunces + Space Grotesk) are bundled under `assets/fonts/` (OFL-licensed; NOT runtime-fetched, so the stage works offline).
**Surfaces**:
- *SpokenScript model* — `lib/features/speak/spoken_script.dart`. Pure timing model (unit-tested in `test/unit/spoken_script_test.dart`): `SpokenWord` (text + start/end), `SpokenScript` (audio url + words), `SpokenLine` (a phrase + its window), `wordsFromAlignment` (ElevenLabs char-alignment → words), `linesFromWords` (words → short editorial lines on punctuation/length), `currentWordIndex` / `lineIndexAt` (which word/line at a position).
- *TypeTheme* — `lib/features/speak/type_theme.dart`. The two type voices: `SpeakType.serif` (Fraunces) + `.grotesque` (Space Grotesk), with per-voice variable-font axes (`fontVariations`), rest/active weights, tracking, and swell timing. The live toggle flips between them.
- *SpeakVoices* — `lib/features/speak/speak_voices.dart`. The `SpeakVoice` catalog (voice_id + label + colour palette) the picker offers — six voices; first is the default. IDs are NOT secret (the API key is); add/swap by editing the list, no server change. The chosen id rides to the Edge Function, which caches audio per (voice, text).
- *SpeakPalette + LivingBackground* — `lib/features/speak/speak_palette.dart`, `living_background.dart`. Voice = colour: each voice carries a `SpeakPalette` (gradient poles + accent). The stage's background is a slow drifting gradient in that palette + a vignette + faint static grain; the active word glows faintly in the accent. Colour lives in the ambience — the ink stays near-white for legibility.
- *Presentation modes* — `lib/features/speak/speak_presentation.dart` (the `SpeakPresentation` enum + the implemented-list the pickers read) and the per-mode views. All read the same timeline (lines / words / position), so the user flips between them live (a "Show" picker on input + a cycle button in the perform chrome). Five modes: **Stage** (`speak_stage.dart` — one line at a time, the spoken word swelling in weight, past→present→future brightness gradient), **One Big Word** (`one_big_word_view.dart` — one giant word filling the frame, punching in on the beat), **Stack** (`stack_view.dart` — lines accumulate teleprompter-style, newest brightest at the bottom), **Collage** (`collage_view.dart` — each phrase a seeded editorial poster: varied sizes/weights/angles, stable per line, the spoken word illuminating within it), **Spotlight** (`spotlight_view.dart` — the whole passage dim, the spoken word igniting in place; doubles as a reading aid).
- *SpeakService* — `lib/features/speak/speak_service.dart`. Calls the `tts-subtitles` Edge Function (ElevenLabs `with-timestamps`, key brokered server-side per docs/SECRETS.md), builds a `SpokenScript`, plays via `just_audio`; exposes `currentPosition` (read per-frame by the stage's ticker for voice-accurate flips). Idempotent dispose; playback degrades silently.
- *Speak screen* — `lib/features/speak/speak_screen.dart`. Paste prompt → pick a voice (Mark/Hope/Elise/Dan) + the type (live font-preview pills) → "Speak it" → full-bleed dark stage; perform controls (switch type / New text / Replay) live in the top chrome pill. Voice is a pre-speak choice (different voice = different audio, re-synthesizes); type stays live during the performance. `_SpeakStageHost` drives the stage from a per-frame ticker; loading is an inline "Voicing…" spinner; failure shows a clear "not set up / offline" live-region note (never blocks).
- *tts-subtitles Edge Function* — `supabase/functions/tts-subtitles/index.ts`. Brokers `ELEVENLABS_API_KEY`; caches audio + alignment by content hash in the `tts-cache` bucket; authenticated-only; CORS-allowed for web. Needs `supabase functions deploy tts-subtitles` + `supabase secrets set ELEVENLABS_API_KEY=…`.
**Depends on**: Voice (shares the `tts-cache` bucket + the brokered-key Edge Function pattern from `tts-generate`); Tools (registered there as a runnable tool); bundled Fraunces + Space Grotesk fonts (`assets/fonts/`).
**Consumed by**: Tools (lists Speak as a runnable `ThinkingTool`).
**Last verified**: 2026-06-04

---

## Tools (Thinking Tools)
**Path**: `lib/features/tools/`
**Purpose**: One searchable shelf that unifies the two halves of the "thinking tools" vision (docs/THINKING_TOOLS.md) — the runnable activities (run with the room) and the editorial reference cards — so a staffer browses, then either launches a tool or reads the move. Phase 1 is a view-model adapter over both existing sources; Phases 2–3 broaden the content past the classroom and open it to contributors.
**Personas served**: All staff. Especially Coach Sam + Brianna (grab a discussion / warm-up to run), Jordan (read the reference move in the moment).
**Discovery surfaces**:
- Routes: `/tools`
- Omnibox: yes — "Tools" (keywords cover tools, thinking tools, thinking, toolkit, activities, run with the room, discussion, frameworks, mental models)
- Slash: `/tools` (aliases: `toolkit`, `thinking`, `frameworks`, `activities`)
- Drawer: yes — "Tools" (Activities group, position before Present)
- Settings: no
**Capabilities**: None — open to every signed-in staff member (staff-facing; gated `viewer is! GuardianViewer` in the omnibox). Read-only.
**Data**: None — pure content (a Dart adapter over the toolkit const catalog + a curated runnable list).
**Surfaces**:
- *ThinkingTool model* — `lib/features/tools/thinking_tool.dart`. The unified view-model + `ThinkingTool.fromToolkit` (reference adapter), `runnableThinkingTools` (curated runnable list), `buildToolLibrary()` (merged shelf, runnable-first).
- *Tools screen* — `lib/features/tools/tools_screen.dart`. Searchable list of `FeatureCard` tiles; runnable tiles launch `tool.route`, reference tiles open a glass reading sheet (when / why / script).
**Depends on**: Toolkit (reads `toolkitCatalog`); the activity routes (`/activity/*`, `/live/*`) and Speak (`/speak`) it launches into.
**Consumed by**: Nothing yet.
**Last verified**: 2026-06-03

---

## Today
**Path**: `lib/features/today/`
**Purpose**: The daily launchpad. Root destination. Context-driven cards: morning (attendance, leading-today, captures); afternoon (pickup, end-of-day capture); director pulse (oversight signals).
**Personas served**: All staff (Jordan + Coach Sam's home base), Maya / Pat (oversight cards), Coach Sam / Brianna (identity strip surfaces "Specialist · Coach" / "Substitute today" so Sam and Brianna orient at a glance).
**Discovery surfaces**:
- Routes: `/` (TodayScreen)
- Omnibox: yes — "Today"
- Slash: `/today` (alias `/home`)
- Drawer: yes — "Today" (main destinations, position 1)
- Settings: no
**Capabilities**: None — open to all signed-in staff. Cards self-gate by capability (DirectorPulseCard renders only when `viewer.isDirector` AND there's a signal to flag).
**Data**: Aggregates from Attendance, Schedule, Captures, Tasks, Insights, Messages, Entries, Certifications.
**Surfaces**:
- *Today screen* — `lib/features/today/today_screen.dart`. Card list, refresh on pull.
- *Live-session banner* — `lib/features/live_session/live_session_banner.dart` (cross-feature, mounted in `today_sections.dart`). Auto-shows at the top of Today when `activeSessionsProvider` has active sessions; hidden when none. One-tap join pushes `/join?code=…&game=…`. Multiple live sessions → picker sheet.
- *Embedded cards* — leading-today (from Schedule), morning-checklist (from Attendance), recent-captures (from Captures), open-tasks (from Tasks), insights (from Insights), unread-messages (deferred).
- *Director pulse card* — `_DirectorPulseCard` inside `today_screen.dart`. Director-only proactive pulse: surfaces today's absent kids (from group day state), cohorts running on substitute coverage (from schedule), and certs expiring within 30 days (from certs-in-space). Renders nothing on "all clear" so it never adds noise. Shipped 2026-05-22 (Wave 36).
- *Identity strip* — `_IdentityStrip` inside `today_screen.dart`. Renders only for specialists ("You are: Specialist · Coach") and substitutes ("You are: Substitute today"); silent for director / lead_teacher / teacher / guardian / kitchen because their context makes the role obvious. Tap → `/settings/roles`. Specialist without a specialty assigned gets a tertiary-tinted hint matching the team-list pattern. Closes the Coach Sam identity gap surfaced by persona-audit 2026-05-23. Shipped Wave 40.
**Depends on**: nearly everything, including LiveSession (`live_session_banner.dart` cross-imports via `today_sections.dart`).
**Consumed by**: Nothing — Today is a leaf.
**Last verified**: 2026-06-03

---

## Vehicles
**Path**: `lib/features/vehicles/`
**Purpose**: Fleet management — create / edit vehicles, pre-trip checkout, post-trip checkin (inspection trail).
**Personas served**: Maya (manages fleet), All staff with `can_drive` (checkout / checkin), Coach Sam (trip days).
**Discovery surfaces**:
- Routes: `/vehicles`, `/vehicles/new`, `/vehicles/scan`, `/vehicles/:id`, `/vehicles/:id/edit`, `/vehicles/:id/checkout`, `/vehicles/:id/checkin` (old `/settings/vehicles*` paths redirect here — preserved for printed QR codes from before Wave 95)
- Omnibox: yes — "Vehicles", "{Vehicle.name}" (per vehicle), "Check out · {Vehicle.name}" (action, gated by `can_drive`), "Check in · {Vehicle.name}" (action, gated by `can_drive`), "Add a vehicle" (action, gated by `can_manage_space`)
- Slash: `/checkout {vehicle}` (alias `/co`), `/checkin {vehicle}` (aliases `/ci`, `/return`) — gated by `can_drive || can_manage_space`
- Drawer: yes — "Vehicles" (canonical nav, gated `canDrive || canManageSpace`; position between Surveys and Settings)
- Settings: yes — "Vehicles" row under {Space name} group
**Capabilities**: Read: all members. Create / edit: `can_manage_space`. Checkout / checkin: `can_drive` (which itself requires an active Driver cert).
**Data**: [vehicles](SCHEMA.md#vehicles), [vehicle_logs](SCHEMA.md#vehicle_logs), [member_certifications](SCHEMA.md#member_certifications) (Driver cert gates `can_drive`)
**Surfaces**:
- *Vehicles list* — `lib/features/vehicles/vehicles_list_screen.dart`. Fleet roster.
- *Vehicle detail* — `lib/features/vehicles/vehicle_detail_screen.dart`. One vehicle's record + recent log.
- *Vehicle edit* — `lib/features/vehicles/vehicle_edit_screen.dart`. Create / update form.
- *Vehicle scan* — `lib/features/vehicles/vehicle_scan_screen.dart`. Camera QR scanner that resolves a scanned vehicle deep link and routes to checkout / checkin.
- *Vehicle inspection* — `lib/features/vehicles/vehicle_inspection_screen.dart`. Pre-trip + post-trip checklist (same screen, different mode). QR PDFs now encode the custom-scheme deep link (`differentworld://v/<id>/<kind>`) — staff always have the app, so the scheme opens the app directly with no browser hop (Wave 171). Invite QRs intentionally keep the HTTPS path for the no-app-installed case.
**Depends on**: Members, Certifications.
**Consumed by**: Schedule (trip assignment), Insights (stale-vehicle signal).
**Last verified**: 2026-06-01

---

## Voice
**Path**: `lib/features/voice/`
**Purpose**: Voice dictation service — Deepgram WebSocket integration, used by the omnibox mic button.
**Personas served**: Jordan (primary — on-the-floor dictation), All staff (any voice composer).
**Discovery surfaces**:
- Routes: none — utility service
- Omnibox: yes — mic button in the composer bar
- Slash: none
- Drawer: no
- Settings: no
**Capabilities**: None — open to all signed-in staff. Requires mic permission at first use.
**Data**: None — audio is streamed, not stored.
**Surfaces**:
- *Deepgram voice service* — `lib/features/voice/deepgram_voice_service.dart`. WebSocket client; emits interim + final transcripts.
**Status**: voice dictation wired in THREE places — the omnibox composer mic, the observation-form body field, AND the capture-form body field. Capture mic shipped 2026-05-23 (Wave 38), closing the Jordan / Brianna floor-use gap. Free-text future fields can adopt the same pattern: form-local `DeepgramVoiceController`, snapshot `_voicePrefix`, append `transcript` on each update, tear down in dispose before the text controller.
**Depends on**: `DEEPGRAM_API_KEY` in `.env`, `record` plugin, mic permission.
**Consumed by**: Omnibox (composer mic — uses the shared `deepgramVoiceProvider` singleton), Entries (observation form body field — form-local `DeepgramVoiceController`), Captures (capture form body field — form-local `DeepgramVoiceController`).
**Last verified**: 2026-05-23

---

## Coverage gaps to track (auto-populated by persona-audit)

This section is intentionally left for the `persona-audit` agent to fill
in. Run `Agent persona-audit` to refresh.

---

## Drift / discovery warnings (auto-populated by feature-mapper)

_Run 2026-06-01 (nav refactor)_ — no unresolved discovery drift after this run. Updates applied:
- Drawer field updated for 6 features now in `buildNavDestinations`: **Entries** (Observations), **Insights**, **Missions**, **LiveSession** (Board `/board`), **Surveys**, **Vehicles**. Missions and Board are the genuinely new additions; the others were already in the rail but not in the old hardcoded drawer.
- "Top-level orientation" blurb rewritten to reflect the full canonical list.
- Settings drop-in note for Missions removed (was `no — omnibox canonical discovery`; now `no` with drawer as the primary surface).
- SCHEMA.md: no changes — this refactor touched no synced tables and no migrations.
- Cross-link reconcile: none — only Drawer fields changed, no (feature → table) or (table → feature) links were affected.

_Run 2026-06-01 (content bank)_ — no unresolved discovery drift. Updates applied this run:
- **ActivityRuntime** — `**Data**` field rewritten: now lists `content_items` read via `bankedContentProvider` + `ContentBankDao`. Confirmed consumers: `this_or_that_screen.dart`, `letter_words_screen.dart`, `as_if_screen.dart`, `riddles_screen.dart`, `fact_or_fib_screen.dart`, `story_starters_screen.dart`, `rhyme_time_screen.dart` (7 screens read `bankedContentProvider`). Charades + live This-or-That confirmed NOT in the consumer list (curated floor only — deterministic order required). Growing the bank = adding seed migrations through Claude Code (docs/CONTENT_BANK.md §1.3) — noted inline.
- **ActivityRuntime** — Routes extended to include the five new DB-backed activity routes confirmed in `router.dart`: `/activity/riddles`, `/activity/breathe`, `/activity/fact-or-fib`, `/activity/story`, `/activity/rhyme-time`. Slash commands extended accordingly: `/riddles`, `/breathe`, `/factorfib`, `/story`, `/rhyme` — all confirmed in `slash_commands.dart`. Brain Breaks deck card count updated from nine to fourteen (all confirmed in `brain_breaks_screen.dart`). Surfaces sublist expanded with five new surface entries.
- **SCHEMA.md** — `content_items` table entry added (dual sync rule: `by_space` for per-space crowd rows + `global_content` auto-subscribe for `space_id IS NULL` global rows; both confirmed in `supabase/sync_rules.yaml`). Consumers: ActivityRuntime.
- Cross-link reconcile: ActivityRuntime `**Data**` claims `content_items`; `content_items` `**Consumers**` lists ActivityRuntime. Bidirectional. No other (feature → table) or (table → feature) drift.

_Run 2026-06-01 (Charades + Board)_ — no unresolved discovery drift. Updates applied this run:
- **LiveSession** — entry rewritten. Routes extended to include `/live/charades` (CharadesLiveScreen) and `/board` (BoardScreen). Omnibox updated: `page.board` entry confirmed in `omnibox_catalog.dart` (`label: 'Brainstorm Board'`, keywords: board, brainstorm, meeting, agenda, ideas, anonymous, `onSelect` pushes `/board`). Slash commands updated: `/charades` (aliases: act, acting, mime, guess) and `/board` (aliases: brainstorm, meeting, agenda, ideas) both confirmed in `slash_commands.dart`. No drawer entry, no Settings ListTile — correct for both surfaces. Brain Breaks deck card "Charades" → `/live/charades` confirmed in `brain_breaks_screen.dart`. No Board card in the Brain Breaks deck — Board is reached via omnibox `page.board` and `/board` slash (correct; it is not an activity card). `live_session.dart` generalized-seam note added: `LiveReducer` typedef, `SessionRole.secret`, game-agnostic `Map<String,dynamic>` state. `charades.dart` and `board_session.dart` new surfaces added. `content_bank.dart` `ContentKind.charades` + 24 prompts confirmed. All claimed surfaces verified.
- **SCHEMA.md** — no changes. Both Charades and Board are ephemeral Realtime surfaces with no synced tables and no migrations.
- Cross-link reconcile: LiveSession claims no synced tables; no (feature → table) or (table → feature) additions or removals. ActivityRuntime `**Consumed by**` already includes LiveSession; `**Depends on**` in LiveSession already includes ActivityRuntime. Content bank now also seeds Charades prompts — noted in LiveSession `**Depends on**` and `charades.dart` surface line; no new cross-link needed (ActivityRuntime ↔ LiveSession link was already bidirectional).

_Run 2026-06-01 (Live Sessions)_ — no unresolved discovery drift. Updates applied this run:
- **LiveSession** — new feature entry added. Route `/live/this-or-that` confirmed in `router.dart` (top-level GoRoute nested under the shell). Slash `/live` with aliases `present`, `projector`, `remote`, `session` confirmed in `slash_commands.dart`. "Present on a big screen" `SecondaryActionButton` (cast icon → `context.push('/live/this-or-that')`) confirmed in `this_or_that_screen.dart`. No drawer entry, no Settings ListTile — correct: this is a mode of a brain break, not a standalone destination. All claimed surfaces verified.
- **ActivityRuntime** — `**Consumed by**` updated from "Nothing — ActivityRuntime is a leaf" to include LiveSession (`live_session_screen.dart` imports `content_bank.dart`).
- **SCHEMA.md** — no new table entry. Feature uses Supabase Realtime broadcast + presence (ephemeral coordination, not durable data — same documented-exception class as auth and Storage). A note confirming the absence is in the LiveSession `**Data**` field.
- Cross-link reconcile: LiveSession claims no synced tables; no (feature → table) or (table → feature) additions. ActivityRuntime ↔ LiveSession dependency link is now bidirectional (LiveSession `**Depends on**` includes ActivityRuntime; ActivityRuntime `**Consumed by**` includes LiveSession).

_Run 2026-06-01 (pack-list + Location lens)_ — no unresolved discovery drift. Updates applied this run:
- **Supplies** — `**Data**` extended: `activity_supplies` (read + written via `activitySupplyLinksProvider` / `ActivitySuppliesActions`) and `locations` (read for the Location lens — `location_id` FK, migration `20260601000003`). `**Surfaces**` updated: list screen now documents the three-view toggle (Category / Location / Running low), the `groupSuppliesByLocation` helper, and the new Activity supplies providers surface. `**Depends on**` updated from "nothing" to Locations. `**Consumed by**` updated: Activities / Schedule now a real consumer via `activity_edit_screen.dart` importing `activity_supplies_providers.dart` + `supplies_providers.dart`.
- **Schedule** — `**Data**` extended: `activity_supplies` and `supplies` (both read in `activity_edit_screen.dart`). `**Depends on**` extended to include Supplies.
- **SCHEMA.md** — `activity_supplies` new table entry added. `supplies` key-columns updated with `location_id`. `activities` Consumers updated to include Schedule (was already listed; Activity edit screen is in the schedule folder). `locations` Consumers updated to include Supplies. `supplies` Consumers updated to include Schedule.
- Cross-link reconcile: see below.

_Run 2026-06-01 (Missions slice 1)_ — no unresolved discovery drift. Updates applied this run:
- **Missions** — new feature entry added. Route `/settings/missions` confirmed in `router.dart` (nested under `/settings`, same pattern as `supplies`, `locations`). Omnibox entry `page.missions` confirmed in `omnibox_catalog.dart` with keywords: missions, jobs, helpers, chores, responsibilities, equipment manager, snack helper; `onSelect` pushes `/settings/missions`. No drawer entry, no Settings ListTile, no slash command — correct per the library-surface convention (same as Supplies, Locations). Claimed surfaces verified: all match code.
- **SCHEMA.md** — `missions` table entry added.
- Cross-link reconcile: Missions claims `missions` table; `missions` Consumers lists Missions. Bidirectional. No other (feature → table) or (table → feature) drift.

_Run 2026-06-01 (Supplies slice 1)_ — no unresolved discovery drift. Updates applied this run:
- **Supplies** — new feature entry added. Route `/settings/supplies` confirmed in `router.dart` (nested under `/settings` alongside `locations`, same pattern). Omnibox entry `page.supplies` confirmed in `omnibox_catalog.dart` with keywords: supplies, inventory, materials, stock, markers, paper; `onSelect` pushes `/settings/supplies`. No drawer entry, no Settings ListTile, no slash command — correct per the library-surface convention (same as Locations, Toolkit, Curricula). Claimed surfaces verified: all match code.
- **SCHEMA.md** — `supplies` table entry added.
- Cross-link reconcile: Supplies claims `supplies` table; `supplies` Consumers lists Supplies. Bidirectional. No other (feature → table) or (table → feature) drift.

_Run 2026-06-01 (Group Discussions + Role Cards deck-switcher)_ — no unresolved discovery drift. Updates applied this run:
- **ActivityRuntime** — Group Discussions added: route `/activity/discussions` → `GroupDiscussionScreen`; Brain Breaks deck card "Group Talk / Discuss — by topic & age" confirmed in `brain_breaks_screen.dart`; slash `/discuss` (aliases: discussion, talk, circle, grouptalk, conversation) confirmed in `slash_commands.dart`. Not in drawer (surface is a deck card, same pattern as all other individual activities) or settings. No new synced tables — `discussions.dart` is a pure-Dart catalog.
- **ActivityRuntime** — Role Cards deck-switcher: `roles.dart` now defines `RoleDeck {id, name, emoji, tagline, cards}` and `roleDecks` (animals 23 cards, people 12 cards). `roleCatalog` kept as back-compat alias. Surfaces sublist updated; `/roles` slash hint updated to "animals, people & jobs"; aliases updated to include `people` and `jobs`.
- **ActivityRuntime** — Brain Breaks deck card count updated from eight to nine.
- No new synced tables. All new content is pure-Dart. SCHEMA.md unchanged.
- Cross-link reconcile: ActivityRuntime has no Data tables. No (feature → table) or (table → feature) drift found.

_Run 2026-06-01 (Wave A — Role Cards + Make a Pattern)_ — no unresolved discovery drift for the new surfaces (they follow the established activity-runtime pattern: drawer via Brain Breaks deck, slash commands for direct access, no separate omnibox or settings entries). Updates applied this run:
- **ActivityRuntime** — new feature entry added. Covers all eight break surfaces, including the two new ones (Role Cards at `/activity/roles`, Make a Pattern at `/activity/pattern`). Kid-lock status corrected: Photography remains the only kid-locked break; Math Game, Many Paths, Beat the Letter, and Act It Out were de-locked this session (teacher-paced exit via back arrow).
- **ActivityRuntime** — discovery surfaces verified: `/breaks` drawer entry confirmed in `main_drawer.dart` at line 263; `/activity/roles` and `/activity/pattern` routes confirmed in `router.dart`; `/roles` and `/pattern` slash commands confirmed in `slash_commands.dart`. Omnibox catalog has NO direct entries for individual activities or for the Brain Breaks deck — this is the established precedent (same as Toolkit), not a drift. The deck is the discovery surface; slash is the power-user shortcut.
- No new synced tables. `roles.dart` and `pattern_maker.dart` are pure-Dart catalogs. `pattern_maker_screen.dart` uses `image_picker` but writes no row. SCHEMA.md unchanged.
- Cross-link reconcile: ActivityRuntime has no Data tables. Kid mode **Consumed by** does not need ActivityRuntime added — only Photography uses the lock (not the whole feature folder), and the kid-mode entry already lists Surveys as the canonical consumer; the per-screen note in ActivityRuntime's Surfaces is sufficient.

_Run 2026-05-29 (Wave 171 vehicle QR scheme change)_ — one discovery drift corrected (see below). No new migrations; SCHEMA.md unchanged. No omnibox, slash, drawer, or settings claims changed. Updates applied this run:
- **Vehicles** — Routes corrected from `/settings/vehicles*` to `/vehicles*` (Wave 95 moved the top-level path; `/settings/vehicles` still exists as a redirect, not a live route). `/vehicles/scan` surface added — `VehicleScanScreen` was in the router but absent from the doc.
- **Vehicles** — Vehicle inspection surface note updated: QR PDFs now encode `differentworld://v/<id>/<kind>` (Wave 171), replacing the prior HTTPS github.io path. Invite QRs keep HTTPS — the distinction is documented inline.
- Cross-link reconcile: no (feature → table) or (table → feature) drift found. SCHEMA.md Consumers lists for vehicles, vehicle_logs, and member_certifications already include Vehicles.

_Run 2026-05-23 (family-lens sync fix)_ — no unresolved discovery drift; no route, omnibox, slash, drawer, or settings claims changed. Updates applied this run:
- **Family** — `**Data**` field rewritten to distinguish offline-first tables (guardians, spaces, subject_guardians, messages, export_recipients — served by the new `by_guardian` PowerSync stream) from direct-PostgREST reads (subjects, attendance_records, entries, attachments — 2-level subquery deferred — and exports via `myReceivedExportsProvider`). The prior "latent bug" note removed; the `by_guardian` stream resolves it for the row-keyed tables. Per-subject tables remain PostgREST-only pending 2-level subquery verification.
- **Family** — Surfaces sublist expanded: `family_providers.dart` entry added; subject-detail and messages-index surface descriptions updated to name the backing providers and their offline-first status.
- **Family** — Depends-on updated: Messages now noted as offline-first via `by_guardian`.
- SCHEMA.md — `by_guardian` stream added to sync-rule fields for guardians, spaces, subject_guardians, messages, and export_recipients. Family added to Consumers of all five tables where not already present.
- Cross-link reconcile: all (Family → table) claims in FEATURES.md verified bidirectional in SCHEMA.md. No drift found.

_Run 2026-05-22 (Wave 24 omnibox interaction hardening)_ — no
unresolved discovery drift; routes, omnibox catalog, slash
commands, drawer, and settings claims all verified against
`router.dart`, `omnibox_catalog.dart`, `slash_commands.dart`,
`main_drawer.dart`, and `settings_screen.dart`. No new
migrations since the previous run; SCHEMA.md unchanged. Updates
applied this run:
- **Omnibox** — Surfaces sublist tightened: search-screen entry
  now documents the rootNavigator dispatch-context fix (post-pop
  callbacks were short-circuiting on the deactivated screen
  context); catalog entry calls out the new "drop subjects whose
  groupId is null" filter so we stop showing tap-no-ops.
- **Omnibox** — new **Interaction invariants** sub-block (4
  bullets) capturing the Wave 24 contract: push-on-focus
  (not keystroke), lock held for `/search` lifetime,
  500ms-window focus + IME re-grant after the FocusScope
  rotation, canonical test + Interaction Guard wiring. This
  doesn't add a NEW FEATURES.md field — it's free-form text
  inside the existing Surfaces sublist style — but call it out
  here so the next feature-mapper run knows it's intentional.
  If the user wants this promoted to a first-class field on
  every feature, propose in a follow-up.
- **Omnibox** — Depends-on extended to include Schedule
  (omnibox catalog now constructs `SubstituteLeadSheet` directly
  from the "Cover today · {Group}" entry, importing from
  `lib/features/schedule/widgets/substitute_lead_sheet.dart`).
  Carries forward the Phase 1 Pat affordance — Schedule's
  Consumed-by line already names Omnibox so the cross-link is
  bidirectional.
- **Captures** — Surfaces sublist now lists `CaptureActions`
  with the transaction wrapper note (`promoteToObservation` +
  `promoteToTask` both run their two writes inside
  `db.transaction(...)`). Blast-radius flagged the prior path
  2026-05-22; this is the durable fix.
- **Entries** — no doc change; the form-local
  `DeepgramVoiceController` was already documented in the prior
  run. Confirmed still accurate.
- Cross-link reconciled — Omnibox→Schedule link verified
  bidirectional. No other (feature → table) or (table →
  feature) drift found.

_Run 2026-05-22 (voice-race hotfix follow-up)_ — no unresolved discovery
drift; no route, omnibox, slash, drawer, or settings claims changed.
Updates applied this run:
- **Entries** — observation-form surfaces line clarified: the form
  now owns its OWN `DeepgramVoiceController` instance (constructed in
  `initState`, disposed in `dispose`) and no longer reads
  `deepgramVoiceProvider`. The doc previously said "reuses
  `DeepgramVoiceController`" which was ambiguous between the class
  and the singleton; tightened to call out that it does NOT consume
  the singleton, to dodge the dual-listener race against AppShell's
  composer mic.
- **Voice** — Consumed-by line split: Omnibox uses the shared
  `deepgramVoiceProvider` singleton; Entries instantiates its own
  `DeepgramVoiceController` and does not consume the singleton. The
  Voice feature is still consumed by Entries because the form uses
  the controller CLASS — just not the provider.
- No new migrations, router changes, omnibox catalog changes, slash
  commands, drawer items, or settings rows since the prior run.
  SCHEMA.md unchanged.

_Run 2026-05-22 (Phase 1 follow-up)_ — no unresolved discovery drift.
Updates applied this run for the persona-audit Phase 1 ship:
- **Schedule** — added the new dynamic omnibox action "Cover today ·
  {Group.name}" (per cohort, gated by `can_manage_schedule`) to the
  discovery surfaces. Opens `SubstituteLeadSheet` directly. Surfaces
  sublist + Consumed-by line updated to call out the omnibox
  invocation path. Pat persona affordance.
- **Entries** — observation-form voice line flipped from "deferred
  for Jordan" to "voice dictation via Deepgram mic (suffix-icon on
  the body TextField; reuses `DeepgramVoiceController`)". Depends-on
  added Voice.
- **Voice** — Status note updated: omnibox mic + observation-form
  body field both ship; capture-form mic still pending. Consumed-by
  added Entries.
- Cross-link reconciled: Voice ↔ Entries link is now bidirectional
  (Entries.Depends-on includes Voice; Voice.Consumed-by includes
  Entries).
- SCHEMA.md verified — no table-level drift this run; no migration
  was added in Phase 1, so SCHEMA.md sections are unchanged.

Previous run (initial 2026-05-22 verification): Schedule keyword
example, Onboarding surfaces, Kid-mode exit dialog — all applied in
the prior pass; carrying forward.

All other discovery claims verified against `router.dart`,
`omnibox_catalog.dart`, `slash_commands.dart`, `main_drawer.dart`, and
`settings_screen.dart`.

_Run 2026-06-03 (Tools + LiveSession lobby + Poster orientation)_ — discovery drift corrected (see output report). Updates applied this run:
- **Top-level orientation** — added "Tools" and "Present" to the canonical nav list (both were in `buildNavDestinations` but missing from the blurb).
- **Tools** — all claimed discovery surfaces verified: `/tools` route in `router.dart`; `page.tools` omnibox entry in `omnibox_catalog.dart`; `/tools` slash with aliases `toolkit, thinking, frameworks, activities` in `slash_commands.dart`; "Tools" nav destination in `nav_destinations.dart`. No drift found.
- **LiveSession** — Routes extended: `/join` (one-place-to-join, `autoJoin`), `/present` and `/present/<game>` routes added. Slash `/live` aliases corrected: code has `['session']` only (not `present, projector, remote, session` as previously claimed — `present` and `projector` and `remote` aliases moved to the separate `/present` slash command). Slash `/present` entry added (aliases: `cast, room, screen, projector, remote`). Omnibox `page.present` entry added. Drawer: "Present" nav destination added. New surfaces: `live_lobby.dart` (LobbyAnnouncer + LobbyWatcher), `live_lobby_providers.dart` (`activeSessionsProvider`), `live_session_banner.dart` (`LiveSessionBanner` on Today). `LiveGameScreen.autoJoin` param documented. `Depends on` and `Consumed by` updated bidirectionally with Today.
- **Today** — `LiveSessionBanner` surface added to the surfaces list. `Depends on` updated to include LiveSession. `Last verified` updated.
- **Poster** — `PosterScreen` surface description updated: orientation control (Auto/Portrait/Landscape), three delivery actions (Save PDF / Save PNG / Print), determinate render progress. `PosterOptions` model updated to include `orientation`. `Last verified` updated.
- **SCHEMA.md** — no changes. No new synced tables in any of these features.
- Cross-link reconcile: LiveSession ↔ Today bidirectional dependency added. No (feature → table) or (table → feature) drift.

---

_Last full registry verification: 2026-06-03 (Tools + LiveSession lobby + Poster orientation)._
_If a feature is missing from this file, the feature-mapper agent will
add a stub the next time it runs. Don't hand-write entries unless
you're also updating the agent's view of truth._

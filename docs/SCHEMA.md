# Schema registry

The canonical map of every synced table. Table-grained: one section per
Drift Table class. Each section has a fixed shape; if you find
yourself wanting a new field, propose it to the user — don't invent it.

**Maintained by**: the `feature-mapper` agent. The `Consumers` list is
kept in sync bidirectionally with `docs/FEATURES.md` `**Data**` fields
on every run.

**Schema**:

```
## <table_name>
**Purpose**: One sentence.
**Key columns**: 5-10 most-important columns + types. Always include
`space_id` / `group_id` / `subject_id` / `member_id` if present.
**RLS gist**: One sentence. Note relaxation (see CLAUDE.md ES256 gotcha).
**Sync rule**: Which stream in `supabase/sync_rules.yaml`, gating column.
**Consumers**: Features that read / write — links to FEATURES.md.
**Last verified**: <ISO date>
```

For schema details beyond what's listed here, read the migration in
`supabase/migrations/` — this doc is a routing layer, not a duplicate
of the SQL.

---

## attendance_records
**Purpose**: Daily check-in / check-out / late status for each subject in a group.
**Key columns**:
- `id` (uuid, PK)
- `space_id` (uuid, NOT NULL → spaces.id)
- `group_id` (uuid, NOT NULL → groups.id)
- `subject_id` (uuid, NOT NULL → subjects.id)
- `date` (date)
- `status` (text — present / absent / late / excused)
- `check_in_at` / `check_out_at` (timestamptz)
- `recorded_by` (uuid → members.id)
**RLS gist**: relaxed (`current_user = 'authenticated'`); GRANT-level scoping does the real gating.
**Sync rule**: `by_space` stream; `WHERE space_id IN (SELECT space_id FROM members WHERE id = auth.user_id())`.
**Consumers**: [Attendance](FEATURES.md#attendance), [Insights](FEATURES.md#insights), [Family](FEATURES.md#family) (direct PostgREST via `familyAttendanceForSubjectProvider` — not in `by_guardian` stream; 2-level subquery deferred).
**Last verified**: 2026-05-23

---

## activities
**Purpose**: Reusable activity templates — name + description + default duration. Schedule blocks reference them.
**Key columns**:
- `id`, `space_id`
- `owner_member_id` (uuid → members.id)
- `name` (text)
- `description` (text, nullable)
- `default_duration_minutes` (integer)
- `capabilities` (jsonb — carries `action_verbs` (list of verb ids for the activity matcher), `senses`, `curriculum_key` (`worldId:index` — present on curriculum-imported rows; idempotency marker), `curriculum_world` (world id of the source curriculum world))
**RLS gist**: relaxed; reads open to all members.
**Sync rule**: `by_space`.
**Consumers**: [Schedule](FEATURES.md#schedule) (blocks reference activities; `activity_edit_screen.dart` in the schedule folder owns the edit UI), [Action Words](FEATURES.md#action-words) (writes via `CurriculumImporter.importActivities` — seeds ~75 curriculum activities tagged with `action_verbs` + `curriculum_key` in `capabilities` JSONB; also reads via the activity matcher screen `activity_match_screen.dart`).
**Last verified**: 2026-06-07

---

## activity_supplies
**Purpose**: Activity ↔ Supply pack-list join — an activity declares which catalog supplies it needs and how many.
**Key columns**:
- `id` (uuid PK — explicit, for PowerSync compat)
- `space_id` (uuid NOT NULL → spaces.id, on delete cascade)
- `activity_id` (uuid NOT NULL → activities.id, on delete cascade)
- `supply_id` (uuid NOT NULL → supplies.id, on delete cascade)
- `quantity` (real, nullable — NULL means "some / see notes")
- UNIQUE(activity_id, supply_id)
**RLS gist**: relaxed (`for all to authenticated using(true) with check(true)`); GRANT-level + space-scoped sync rule are the real gate.
**Sync rule**: `by_space` stream; `SELECT * FROM activity_supplies WHERE space_id IN (SELECT space_id FROM members WHERE id = auth.user_id())`. Dashboard deploy + device local-recreate required after adding this table.
**Consumers**: [Supplies](FEATURES.md#supplies) (provides `activitySupplyLinksProvider` + `ActivitySuppliesActions`), [Schedule](FEATURES.md#schedule) (activity editor reads + writes links via those providers).
**Last verified**: 2026-06-01

---

## attachments
**Purpose**: First-class attachments (photos, PDFs, audio) on any entity. Entity discriminator allows attachments to ride on observations, exports, captures, etc.
**Key columns**:
- `id`, `space_id`
- `entity_kind` (text — `entry`, `export`, `capture`, `subject`, `member`)
- `entity_id` (uuid)
- `storage_path` (text — bucket-relative path in `attachments` Storage bucket)
- `mime_type` (text)
- `created_at` (timestamptz)
**RLS gist**: relaxed; signed-URL minting scoped via Storage RLS.
**Sync rule**: `by_space`.
**Consumers**: [Entries](FEATURES.md#entries), [Exports](FEATURES.md#exports), [Photos](FEATURES.md#photos), [Family](FEATURES.md#family) (direct PostgREST via `familyAttachmentsForEntityProvider` — not in `by_guardian` stream; 2-level subquery deferred).
**Last verified**: 2026-05-23

---

## captures
**Purpose**: Quick-capture inbox row. Free-text "I noticed…" notes; status moves from `open` → `promoted` (to a task / observation) or `discarded`.
**Key columns**:
- `id`, `space_id`
- `author_id` (uuid → members.id)
- `body` (text)
- `status` (text — `open` / `promoted` / `discarded`)
- `promoted_to_kind` (text — `task` / `entry`, nullable)
- `promoted_to_id` (uuid, nullable)
- `created_at` (timestamptz)
**RLS gist**: relaxed.
**Sync rule**: `by_space`.
**Consumers**: [Captures](FEATURES.md#captures), [Today](FEATURES.md#today), [Review](FEATURES.md#review).
**Last verified**: 2026-05-21

---

## dismissed_insights
**Purpose**: Per-member snooze for derived insights — so dismissing "Driver cert expiring" on Maya's phone doesn't dismiss it on Jordan's.
**Key columns**:
- `id`, `space_id`
- `member_id` (uuid → members.id)
- `insight_id` (text — stable hash of the insight payload)
- `dismissed_at` (timestamptz)
**RLS gist**: relaxed.
**Sync rule**: `by_space`.
**Consumers**: [Insights](FEATURES.md#insights).
**Last verified**: 2026-05-21

---

## entries
**Purpose**: Unified daily log. Observations, meals, naps, diapers, incidents, custom-kind. The `kind` text discriminator picks the schema for `payload` JSONB.
**Key columns**:
- `id`, `space_id`
- `group_id` (uuid → groups.id, nullable for cross-cohort entries)
- `subject_id` (uuid → subjects.id, nullable for cohort-wide entries)
- `kind` (text — `observation` / `meal` / `nap` / `diaper` / `incident` / `departure` / `action_words` / `skill_measure` / etc.)
- `text` (text — narrative / body; for `incident` rows, staff-only — can name other children)
- `details` (jsonb — schema depends on kind; for `incident`: `{incident_type, action_taken?, parent_notified, family_note?}`)
- `photo_url` (text, nullable — bucket-relative path; stripped for guardian reads of incidents)
- `author_id` (uuid → members.id)
- `occurred_at` (timestamptz)
- `schedule_block_id` (uuid, nullable — no FK; see migration `20260531000002_entry_schedule_block.sql`. Intentionally FK-free so entries survive block deletion with their tag intact.)
**RLS gist**: relaxed (`for select to authenticated using(true)`). Guardian-side reads of `kind='incident'` rows MUST go through the `app.family_incidents_for_subject(caller_uid, p_subject_id)` RPC (migration `20260606000002_family_incidents_rpc.sql`), which strips `text` / `photo_url` / `details.action_taken` server-side before rows leave Postgres and enforces the guardian↔child link + surfaced-only policy. Direct `entries` reads by a guardian device would expose the full narrative over the wire even though RLS is `using(true)`.
**Sync rule**: `by_space` (no publication/sync-rule change needed — entries was already replicated and `SELECT *` covers the new column).
**Consumers**: [Entries](FEATURES.md#entries), [Exports](FEATURES.md#exports) (Progress Report), [Captures](FEATURES.md#captures) (promotion destination), [Insights](FEATURES.md#insights), [Family](FEATURES.md#family) (observations via direct PostgREST `familyEntriesForSubjectProvider`; incidents via server-stripping RPC `familyIncidentsForSubjectProvider`), [Review](FEATURES.md#review), [Schedule](FEATURES.md#schedule) (live-block capture tagging — see docs/LIVE_BLOCK_CONTEXT.md), [Incidents](FEATURES.md#incidents) (`kind='incident'`), [Pickup](FEATURES.md#pickup) (`kind='departure'`), [Action Words](FEATURES.md#action-words) (`kind='action_words'` — one row per subject per date; `details` = `{verb_picks, done, world_name?, word_of_day?, note}`), [Missions](FEATURES.md#missions) (`kind='mission'` — one row per Do-board completion; `details.missionId` identifies which mission; read via `missionCompletionsProvider`), [World](FEATURES.md#world) (`kind='skill_measure'` — one row per (subject, skill measurement); `details` = `{skill, value}`; read by `latestSkillValues` in `skill_measure.dart` to power the Skills section on CharacterSheetScreen; also reads `kind='week_log'` for Spells + Allies aggregation).
**Last verified**: 2026-06-07

---

## export_recipients
**Purpose**: Per-export delivery log — which guardians/members/external emails got the report and the delivery state from Resend (Edge Function fan-out).
**Key columns**:
- `id`, `space_id`
- `export_id` (uuid → exports.id)
- `kind` (text — `guardian` / `member` / `external`)
- `guardian_id` (uuid → guardians.id, nullable)
- `member_id` (uuid → members.id, nullable)
- `external_label` / `external_email` (text, nullable)
- `channel` (text — `email` / `link` / `manual`)
- `state` (text — `delivered` / `failed` / `manual`)
- `sent_at` (timestamptz)
**RLS gist**: relaxed; recipient-side reads gated server-side by the Edge Function.
**Sync rule**: `by_space` for staff. `by_guardian` stream delivers the guardian's own recipient rows (`WHERE guardian_id IN (SELECT id FROM guardians WHERE user_id = auth.user_id())`) for the "Seen by…" tracker; the parent `exports` row itself is still fetched via PostgREST in `myReceivedExportsProvider` (2-level join).
**Consumers**: [Exports](FEATURES.md#exports), [Family](FEATURES.md#family) (offline-first recipient rows via `by_guardian`).
**Last verified**: 2026-05-23

---

## exports
**Purpose**: A compiled snapshot (PDF, CSV) of a subject's or group's data, with audit trail. Status: `draft` → `stored` → `sent` → `archived`.
**Key columns**:
- `id`, `space_id`
- `author_id` (uuid → members.id)
- `subject_id` (uuid → subjects.id, nullable for program-wide exports)
- `group_id` (uuid → groups.id, nullable)
- `template_id` / `template_version` (text)
- `format` (text — `pdf` / `csv`)
- `storage_path` (text — bucket-relative in `exports` Storage bucket)
- `snapshot` (jsonb — the data the PDF was rendered from)
- `status` (text — `draft` / `stored` / `sent` / `archived`)
- `note` (text, nullable)
**RLS gist**: relaxed for staff; guardian reads gated server-side.
**Sync rule**: `by_space` for staff. Guardian-side reads bypass PowerSync.
**Consumers**: [Exports](FEATURES.md#exports), [Family](FEATURES.md#family) (received reports — direct PostgREST via `myReceivedExportsProvider`; not in `by_guardian` stream because the join requires 2 levels).
**Last verified**: 2026-05-23

---

## groups
**Purpose**: Classroom / cohort record. Capabilities JSONB carries age band + tracking flags + curriculum.
**Key columns**:
- `id`, `space_id`
- `name` (text)
- `capabilities` (jsonb — `age_band`, `tracks_diapers`, `tracks_naps`, `nap_schedule`, `bilingual_languages`, etc.)
- `created_at` (timestamptz)
**RLS gist**: relaxed.
**Sync rule**: `by_space`.
**Consumers**: [Groups](FEATURES.md#groups), [Attendance](FEATURES.md#attendance), [Entries](FEATURES.md#entries), [Schedule](FEATURES.md#schedule), [Subjects](FEATURES.md#subjects), [Today](FEATURES.md#today).
**Last verified**: 2026-05-21

---

## group_members
**Purpose**: Classroom staffing join — which members are assigned to which groups.
**Key columns**:
- `id` (uuid PK — explicit, for PowerSync compat — see CLAUDE.md "join tables need id")
- `group_id` (uuid → groups.id)
- `member_id` (uuid → members.id)
- `space_id` (uuid → spaces.id)
- `role_in_group` (text — `lead` / `assist` / `floater`, nullable)
- UNIQUE(group_id, member_id)
**RLS gist**: relaxed.
**Sync rule**: `by_space`.
**Consumers**: [Groups](FEATURES.md#groups), [Schedule](FEATURES.md#schedule).
**Last verified**: 2026-05-21

---

## guardians
**Purpose**: Parent / family contact records. Distinct from members (who are staff). May or may not have a Supabase auth user (`user_id`).
**Key columns**:
- `id`, `space_id`
- `name` (text)
- `email` (text, nullable)
- `phone` (text, nullable)
- `user_id` (uuid → auth.users.id, nullable — set when the guardian has signed in)
**RLS gist**: relaxed for staff; guardian self-reads via direct PostgREST with `user_id = auth.uid()`.
**Sync rule**: `by_space` for staff. `by_guardian` stream delivers the guardian's own row (`WHERE user_id = auth.user_id()`) so `GuardianViewer` resolution is offline-first.
**Consumers**: [Guardians](FEATURES.md#guardians), [Family](FEATURES.md#family), [Messages](FEATURES.md#messages), [Exports](FEATURES.md#exports), [Subjects](FEATURES.md#subjects) (guardian section embedded in Subject detail).
**Last verified**: 2026-05-23

---

## headcounts
**Purpose**: Headcount checkpoint at a schedule transition. "We loaded the bus with 18 kids." Audit + sanity check for trips.
**Key columns**:
- `id`, `space_id`
- `schedule_block_id` (uuid → schedule_blocks.id)
- `checkpoint_label` (text — `pre-departure`, `arrival`, `pre-return`, `back-at-base`)
- `count` (integer)
- `expected_count` (integer)
- `recorded_by` (uuid → members.id)
- `recorded_at` (timestamptz)
**RLS gist**: relaxed.
**Sync rule**: `by_space`.
**Consumers**: [Schedule](FEATURES.md#schedule), [Attendance](FEATURES.md#attendance).
**Last verified**: 2026-05-21

---

## invites
**Purpose**: 6-char invite codes for staff onboarding. The code is the deep-link payload (`differentworld://invite/<code>`).
**Key columns**:
- `id`, `space_id`
- `code` (text — UPPERCASE, 6 chars from the unambiguous alphabet)
- `role` (text — `director` / `lead_teacher` / `teacher` / `assistant`, or vertical equivalents)
- `email` (text, nullable — if set, redemption auto-binds when the user signs in with this email)
- `expires_at` (timestamptz, nullable — null = never expires)
- `created_by` (uuid → members.id)
- `created_at` (timestamptz)
- `redeemed_at` (timestamptz, nullable)
- `redeemed_by` (uuid → members.id, nullable)
- UNIQUE(code)
**RLS gist**: relaxed. KNOWN GAP — invites can be deleted by any authenticated user that knows the row id; see CLAUDE.md "ES256 gotcha." Re-tighten when JWT claims work.
**Sync rule**: `by_space`.
**Consumers**: [Invites](FEATURES.md#invites), [Onboarding](FEATURES.md#onboarding), [Settings](FEATURES.md#settings) (Team screen pending-invites list).
**Last verified**: 2026-05-21

---

## locations
**Purpose**: Place catalog for scheduling — "Cabin 3", "Pool", "Archery range", off-site addresses.
**Key columns**:
- `id`, `space_id`
- `name` (text)
- `kind` (text — `on_site` / `off_site`)
- `address` (text, nullable)
- `notes` (text, nullable)
**RLS gist**: relaxed.
**Sync rule**: `by_space`.
**Consumers**: [Schedule](FEATURES.md#schedule), [Settings](FEATURES.md#settings) (locations list), [Supplies](FEATURES.md#supplies) (Location lens reads `locationsProvider` to resolve `location_id → name`).
**Last verified**: 2026-06-01

---

## member_certifications
**Purpose**: Staff cert lifecycle. Each row is one cert held by one member; tracks issue + expiration so derived caps (e.g., `can_drive` gated by active Driver cert) can be evaluated.
**Key columns**:
- `id`, `space_id`
- `member_id` (uuid → members.id)
- `cert_key` (text — `mat` / `cpr` / `driver` / others)
- `issued_at` (date)
- `expires_at` (date, nullable)
- `verified_by` (uuid → members.id, nullable)
- `attachment_id` (uuid → attachments.id, nullable — scan of the cert)
**RLS gist**: relaxed.
**Sync rule**: `by_space`.
**Consumers**: [Certifications](FEATURES.md#certifications), [Vehicles](FEATURES.md#vehicles) (Driver cert gates `can_drive`), [Insights](FEATURES.md#insights) (expiring-cert signal).
**Last verified**: 2026-05-21

---

## members
**Purpose**: Staff roster. One row per signed-in user × space. The `user_id` links to `auth.users`; `role` + `capabilities` JSONB drive the UI.
**Key columns**:
- `id`, `space_id`
- `user_id` (uuid → auth.users.id)
- `display_name` (text)
- `role` (text — `director` / `lead_teacher` / `teacher` / `assistant` / `guardian` / vertical equivalents)
- `capabilities` (jsonb — see `lib/core/capabilities/capability_keys.dart` for the keys)
- `avatar_url` (text, nullable — Storage bucket-relative path, not full URL)
- `archived_at` (timestamptz, nullable — soft-delete)
**RLS gist**: relaxed.
**Sync rule**: `by_space`.
**Consumers**: [Settings](FEATURES.md#settings) (Team), [Schedule](FEATURES.md#schedule) (lead assignment), [Vehicles](FEATURES.md#vehicles) (Driver cert), [Photos](FEATURES.md#photos), [Auth](FEATURES.md#auth), [Onboarding](FEATURES.md#onboarding) (writes initial member row on space creation), and most other features via `viewer.dart`.
**Last verified**: 2026-05-22

---

## messages
**Purpose**: Staff ↔ Guardian per-child threads. One row per message; threads keyed by (subject_id, guardian_id).
**Key columns**:
- `id`, `space_id`
- `subject_id` (uuid → subjects.id)
- `guardian_id` (uuid → guardians.id)
- `author_id` (uuid, nullable — either member or guardian)
- `author_kind` (text — `staff` / `guardian`)
- `body` (text)
- `created_at` (timestamptz)
- `read_by_guardian_ids` (jsonb array — set of guardian.ids who have read this message)
**RLS gist**: relaxed for staff. Guardian self-reads via direct PostgREST with `guardian_id IN (SELECT id FROM guardians WHERE user_id = auth.uid())`.
**Sync rule**: `by_space` for staff. `by_guardian` stream delivers the guardian's own thread rows (`WHERE guardian_id IN (SELECT id FROM guardians WHERE user_id = auth.user_id())`) so the family messages index is now offline-first.
**Consumers**: [Messages](FEATURES.md#messages), [Family](FEATURES.md#family).
**Last verified**: 2026-05-23

---

## missions
**Purpose**: The program's editable catalog of real jobs kids do — each carrying a manual (rules), a checklist (actions JSON), an evidence kind, and optional age suitability.
**Key columns**:
- `id` (uuid PK)
- `space_id` (uuid NOT NULL → spaces.id, on delete cascade)
- `name` (text NOT NULL)
- `icon` (text, nullable — single emoji glyph)
- `builds` (text, nullable — trait the job grows, e.g. "responsibility")
- `rules` (text, nullable — the manual: how it's done + where things go)
- `actions` (text, nullable — ordered checklist as JSON array of strings)
- `evidence_kind` (text NOT NULL default 'check' — `photo` / `count` / `note` / `check`)
- `min_age` / `max_age` (int, nullable — age suitability; NULL = any age)
- `is_active` (boolean NOT NULL default true)
- `sort` (int NOT NULL default 0)
**RLS gist**: relaxed (`for all to authenticated using(true) with check(true)`); space-scoped sync rule + GRANT are the real gate.
**Sync rule**: `by_space` stream; `SELECT * FROM missions WHERE space_id IN (SELECT space_id FROM members WHERE id = auth.user_id())`. Dashboard deploy + device local-recreate pending as a user step.
**Consumers**: [Missions](FEATURES.md#missions).
**Last verified**: 2026-06-01

---

## permission_slips
**Purpose**: Field-trip parent consent. One row per (subject, trip); status tracks consent and audit.
**Key columns**:
- `id`, `space_id`
- `subject_id` (uuid → subjects.id)
- `trip_logistics_id` (uuid → trip_logistics.id)
- `status` (text — `pending` / `granted` / `declined`)
- `granted_at` (timestamptz, nullable)
- `granted_by_guardian_id` (uuid → guardians.id, nullable)
- `signature_storage_path` (text, nullable — signed PDF)
**RLS gist**: relaxed.
**Sync rule**: `by_space`.
**Consumers**: [Schedule](FEATURES.md#schedule).
**Last verified**: 2026-05-21

---

## schedule_blocks
**Purpose**: Per-cohort, per-day blocks of time with an optional lead, activity, location, and substitute lead. The substrate for the Schedule editor + LeadingTodayCard + Substitute sheet.
**Key columns**:
- `id`, `space_id`
- `group_id` (uuid → groups.id)
- `date` (date)
- `start_at` / `end_at` (timestamptz)
- `kind` (text — `on_site` / `field_trip` / `break` / `closed`)
- `activity_id` (uuid → activities.id, nullable for breaks)
- `location_id` (uuid → locations.id, nullable)
- `lead_member_id` (uuid → members.id, nullable — the planned lead)
- `lead_substitute_member_id` (uuid → members.id, nullable — today's cover. Preserves the planned roster for audit.)
- `notes` (text, nullable)
**RLS gist**: relaxed.
**Sync rule**: `by_space`.
**Consumers**: [Schedule](FEATURES.md#schedule) (block editor + day-template builder `applyToDate` writes via `scheduleDao.createDayBlocks`), [Today](FEATURES.md#today) (LeadingTodayCard).
**Last verified**: 2026-06-07

---

## spaces
**Purpose**: The workspace / program. One install runs one space with many groups; members are the team. Capabilities JSONB carries vertical + feature flags.
**Key columns**:
- `id` (uuid PK)
- `name` (text)
- `capabilities` (jsonb — `vertical`, `feature_observations`, `feature_meal_logging`, `pickup_window_start`, `pickup_window_end`, `default_class_size`, `photo_default_consent`, `state_compliance`, `staff_pin`, `day_templates` (JSON string — the director's day-template library; see `SpaceCaps.dayTemplates`), `program_start_date` (ISO date string — the curriculum journey start date; drives `currentCurriculumWeekProvider` and `currentWorldProvider` in Action Words; written by `WorldScheduleActions.setStartDate`), etc.)
- `created_at` (timestamptz)
- `created_by` (uuid → members.id)
**RLS gist**: relaxed.
**Sync rule**: `by_space` (a member's own space row). `by_guardian` stream also delivers the guardian's linked space row (`WHERE id IN (SELECT space_id FROM guardians WHERE user_id = auth.user_id())`) so the family lens resolves the space name offline-first.
**Consumers**: [Settings](FEATURES.md#settings), [Onboarding](FEATURES.md#onboarding), [Auth](FEATURES.md#auth) (viewer resolution), [Family](FEATURES.md#family) (offline-first via `by_guardian`), [Schedule](FEATURES.md#schedule) (day-template library stored as JSON in `capabilities['day_templates']`; read via `currentSpaceProvider`, written via `spaceCapActionsProvider`), [Action Words](FEATURES.md#action-words) (reads `capabilities['program_start_date']` via `currentCurriculumWeekProvider`; written via `WorldScheduleActions`), and every other feature via `viewer.spaceId`.
**Last verified**: 2026-06-07

---

## subjects
**Purpose**: The child / student / patient record. Capabilities JSONB carries health intake + photo consent + pickup configuration.
**Key columns**:
- `id`, `space_id`
- `group_id` (uuid → groups.id, nullable for floating / cross-cohort kids)
- `first_name` / `last_name` (text)
- `dob` (date, nullable)
- `photo_url` (text, nullable — Storage bucket-relative path)
- `capabilities` (jsonb — `allergies`, `dietary`, `medications`, `has_iep`, `photo_consent`, `pickup_strict`, `authorized_pickup_guardian_ids`, `pickup_people`, `comfort_items`, etc.)
- `enrolled_at` (timestamptz)
- `withdrawn_at` (timestamptz, nullable)
**RLS gist**: relaxed for staff. Guardian self-reads via direct PostgREST through `subject_guardians` join.
**Sync rule**: `by_space` for staff. Guardian-side reads bypass PowerSync.
**Consumers**: [Subjects](FEATURES.md#subjects), [Attendance](FEATURES.md#attendance), [Entries](FEATURES.md#entries), [Exports](FEATURES.md#exports), [Family](FEATURES.md#family), [Messages](FEATURES.md#messages), [Surveys](FEATURES.md#surveys), [Photos](FEATURES.md#photos), [Incidents](FEATURES.md#incidents) (log screen reads `subjectsInSpaceProvider` to resolve child identity on each card), [World](FEATURES.md#world) (reads `subjectByIdProvider` on the Me screen to resolve the child's first name).
**Last verified**: 2026-06-06 (Incidents added as consumer — log screen reads subjects)

---

## subject_guardians
**Purpose**: Child ↔ Parent join. One row per (subject, guardian) link; `is_primary` flag for the primary contact.
**Key columns**:
- `id` (uuid PK — explicit, for PowerSync compat)
- `subject_id` (uuid → subjects.id)
- `guardian_id` (uuid → guardians.id)
- `space_id` (uuid → spaces.id)
- `is_primary` (boolean)
- `relationship` (text — `mother` / `father` / `guardian` / etc.)
- UNIQUE(subject_id, guardian_id)
**RLS gist**: relaxed for staff. Guardian self-reads via direct PostgREST.
**Sync rule**: `by_space` for staff. `by_guardian` stream delivers the guardian's own link rows (`WHERE guardian_id IN (SELECT id FROM guardians WHERE user_id = auth.user_id())`) so the per-child fan-out in `myChildSubjectIdsProvider` is offline-first.
**Consumers**: [Guardians](FEATURES.md#guardians), [Family](FEATURES.md#family), [Messages](FEATURES.md#messages), [Exports](FEATURES.md#exports), [Subjects](FEATURES.md#subjects) (guardian links displayed inline on Subject detail).
**Last verified**: 2026-05-23

---

## survey_picker_options
**Purpose**: Per-space overrides for the survey "About you" identity chips — which labels appear for each dimension (age_band / grade / school) when kids self-identify before taking a survey.
**Key columns**:
- `id` (uuid PK)
- `space_id` (uuid NOT NULL → spaces.id, on delete cascade)
- `dimension` (text — `age_band` / `grade` / `school`)
- `label` (text — the chip label the kid sees)
- `sort_order` (int)
- UNIQUE(space_id, dimension, label)
**RLS gist**: relaxed (`for all to authenticated using(true) with check(true)`); GRANT-level + space-scoped sync rule are the real gate.
**Sync rule**: `by_space` stream; `SELECT * FROM survey_picker_options WHERE space_id IN (SELECT space_id FROM members WHERE id = auth.user_id())`.
**Consumers**: [Surveys](FEATURES.md#surveys).
**Last verified**: 2026-06-03

---

## survey_responses
**Purpose**: Questionnaire answers — JSONB `answers` keyed by `question_key`. Templates live in code (no `survey_templates` table yet).
**Key columns**:
- `id`, `space_id`
- `template_id` (text — the in-code template key)
- `template_version` (text — for replay safety when a template's questions change)
- `subject_id` (uuid → subjects.id, nullable for staff-as-respondent surveys)
- `respondent_member_id` (uuid → members.id)
- `answers` (jsonb — `{question_key: answer_value}`)
- `submitted_at` (timestamptz)
**RLS gist**: relaxed.
**Sync rule**: `by_space`.
**Consumers**: [Surveys](FEATURES.md#surveys), [Insights](FEATURES.md#insights).
**Last verified**: 2026-05-21

---

## supplies
**Purpose**: The program's real-world inventory catalog — items (markers, paper, balls) with quantity, unit, location, and an optional low-stock threshold.
**Key columns**:
- `id` (uuid PK)
- `space_id` (uuid NOT NULL → spaces.id, on delete cascade)
- `name` (text NOT NULL)
- `category` (text, nullable — free-text shelf label, e.g. "Art", "Sports")
- `quantity` (real, nullable — NULL = uncounted)
- `unit` (text, nullable — "boxes", "reams", "balls")
- `location_id` (uuid, nullable → locations.id on delete set null — the Location-catalog lens; added in migration `20260601000003`)
- `location` (text, nullable — free-text sub-spot within the location, e.g. "Cabinet B"; NOT a FK)
- `low_stock_threshold` (real, nullable — flags "running low" when quantity drops below)
- `photo_url` (text, nullable — Storage bucket-relative path; bytes in Supabase Storage)
**RLS gist**: relaxed (`for all to authenticated using(true) with check(true)`); GRANT-level + space-scoped sync rule are the real gate.
**Sync rule**: `by_space` stream; `SELECT * FROM supplies WHERE space_id IN (SELECT space_id FROM members WHERE id = auth.user_id())`. Dashboard deploy + device local-recreate still pending.
**Consumers**: [Supplies](FEATURES.md#supplies), [Schedule](FEATURES.md#schedule) (activity editor reads all space supplies to populate the pack-list picker).
**Last verified**: 2026-06-01

---

## tasks
**Purpose**: To-do list. Optional `subject_id` link for kid-specific tasks (follow up with X's parent). Captures promote into tasks; tasks can also be created standalone.
**Key columns**:
- `id`, `space_id`
- `author_id` (uuid → members.id)
- `assignee_id` (uuid → members.id, nullable)
- `subject_id` (uuid → subjects.id, nullable)
- `body` (text)
- `status` (text — `open` / `done` / `dropped`)
- `due_at` (timestamptz, nullable)
- `completed_at` (timestamptz, nullable)
- `created_from_capture_id` (uuid → captures.id, nullable)
**RLS gist**: relaxed.
**Sync rule**: `by_space`.
**Consumers**: [Tasks](FEATURES.md#tasks), [Captures](FEATURES.md#captures) (promotion destination), [Today](FEATURES.md#today), [Review](FEATURES.md#review).
**Last verified**: 2026-05-21

---

## trip_logistics
**Purpose**: Field-trip metadata for a schedule_block. Destination, departure / return times, manifest summary, permission-slip rollup.
**Key columns**:
- `id`, `space_id`
- `schedule_block_id` (uuid → schedule_blocks.id)
- `destination` (text)
- `departure_at` / `return_at` (timestamptz)
- `headcount_expected` (integer)
- `lead_member_id` (uuid → members.id)
**RLS gist**: relaxed.
**Sync rule**: `by_space`.
**Consumers**: [Schedule](FEATURES.md#schedule).
**Last verified**: 2026-05-21

---

## trip_vehicles
**Purpose**: Per-trip vehicle assignment with manifest. One row per (trip, vehicle).
**Key columns**:
- `id`, `space_id`
- `trip_logistics_id` (uuid → trip_logistics.id)
- `vehicle_id` (uuid → vehicles.id)
- `driver_member_id` (uuid → members.id)
- `manifest` (jsonb — array of subject_ids riding in this vehicle)
**RLS gist**: relaxed.
**Sync rule**: `by_space`.
**Consumers**: [Schedule](FEATURES.md#schedule), [Vehicles](FEATURES.md#vehicles).
**Last verified**: 2026-05-21

---

## vehicle_logs
**Purpose**: Pre-trip + post-trip inspection trail. One row per (vehicle, checkout-or-checkin event).
**Key columns**:
- `id`, `space_id`
- `vehicle_id` (uuid → vehicles.id)
- `kind` (text — `checkout` / `checkin`)
- `member_id` (uuid → members.id — the inspector)
- `checklist` (jsonb — per-item pass/fail)
- `odometer_reading` (integer, nullable)
- `notes` (text, nullable)
- `created_at` (timestamptz)
**RLS gist**: relaxed.
**Sync rule**: `by_space`.
**Consumers**: [Vehicles](FEATURES.md#vehicles), [Insights](FEATURES.md#insights) (stale-vehicle signal).
**Last verified**: 2026-05-21

---

## vehicles
**Purpose**: Fleet vehicle record. Capabilities JSONB carries seat count, fuel type, body color (for omnibox icon).
**Key columns**:
- `id`, `space_id`
- `name` (text — "Big Blue Van")
- `make` / `model` / `year` (text / text / integer, nullable)
- `seats` (integer)
- `capabilities` (jsonb — `body_color`, `fuel_type`, `accessibility`, etc.)
**RLS gist**: relaxed.
**Sync rule**: `by_space`.
**Consumers**: [Vehicles](FEATURES.md#vehicles), [Schedule](FEATURES.md#schedule) (trip assignment).
**Last verified**: 2026-05-21

---

## character_sheets
**Purpose**: The persistent in-world self for each child — drawn avatar + chosen name + born_on date + culture. 1:1 with subjects; the foundation of the Different World feature (docs/WORLD.md).
**Key columns**:
- `id` (uuid PK)
- `space_id` (uuid NOT NULL → spaces.id, on delete cascade)
- `subject_id` (uuid NOT NULL → subjects.id, on delete cascade; UNIQUE — 1:1 with the child)
- `chosen_name` (text, nullable — kid-authored world-self name; NULL until the day-one ritual)
- `avatar_url` (text, nullable — `person-photos` bucket-relative path for the drawn self-portrait; deliberately SEPARATE from `subjects.photo_url` which is the admin ID photo; may briefly hold `pending:<id>` when saved offline)
- `born_on` (date, nullable — enrollment/"birthday" in the world)
- `culture` (text, nullable — the kid's description of their world's culture)
- `capabilities` (jsonb NOT NULL default '{}' — per-sheet flags, future use)
- `created_at` / `updated_at` (timestamptz)
**RLS gist**: relaxed (`for all to authenticated using(true) with check(true)`); ES256 `auth.uid()`-null workaround in effect (see CLAUDE.md). Space-scoped sync rule + GRANT are the real gate.
**Sync rule**: `by_space` stream; `SELECT * FROM character_sheets WHERE space_id IN (SELECT space_id FROM members WHERE id = auth.user_id())`. PowerSync publication added in migration `20260606000001_character_sheets.sql`. Dashboard deploy + device local-recreate required.
**Consumers**: [World](FEATURES.md#world) (character_sheet_providers.dart via `characterSheetsDao`).
**Last verified**: 2026-06-06

---

## content_items
**Purpose**: The content bank — activity prompts (this-or-that pairs, riddles, fact-or-fib claims, story starters, rhyme words, act-it-out lines, charades words, etc.) made once and reused, so no AI model is called on the hot path of a play. `space_id IS NULL` rows are global (shared across every program); `space_id` set rows belong to one program's crowd-grown library.
**Key columns**:
- `id` (uuid PK)
- `space_id` (uuid, NULLABLE → `spaces.id` on delete cascade; NULL = global/shared, non-null = this program's crowd content)
- `kind` (text — `this_or_that` / `riddle` / `fact_or_fib` / `story_starter` / `story_twist` / `rhyme_word` / `line` / `as_if` / `charades` / `category` / …)
- `payload` (jsonb as text on device — shape varies by kind: `{a,b}` for this-or-that, `{prompt,answer}` for riddles, `{statement,isTrue,note}` for fact-or-fib, `{text}` for starters/twists/lines/as-if/rhyme, `{word,category}` for charades)
- `fingerprint` (text — de-dupe key; normalized payload hash; global items: `UNIQUE(kind,fingerprint) WHERE space_id IS NULL`; per-space items: `UNIQUE(kind,space_id,fingerprint) WHERE space_id IS NOT NULL`)
- `source` (text — `curated` / `ai` / `crowd` / `local`)
- `created_by` (uuid, nullable — member/auth id for crowd rows; null for AI)
- `created_at` (timestamptz)
**RLS gist**: relaxed (`for all to authenticated using(true) with check(true)`); non-PII game prompts — broad read is intentional. AI rows are inserted server-side with the service role (bypasses RLS). ES256 workaround in effect (see CLAUDE.md).
**Sync rule**: rides TWO streams — `by_space` delivers per-space crowd rows (`WHERE space_id IN (SELECT space_id FROM members WHERE id = auth.user_id())`); `global_content` auto-subscribes and delivers all global rows (`WHERE space_id IS NULL`). This is the second multi-stream table after `guardians`/`messages`/etc. in `by_guardian`. Growing the bank = adding seed migrations through Claude Code — the seed migration is the kid-safety review (content is plain SQL, human-readable before it ships; see `docs/CONTENT_BANK.md §1.3`). Dashboard deploy required after adding this table.
**Consumers**: [ActivityRuntime](FEATURES.md#activityruntime) — seven single-device screens read `bankedContentProvider` (`this_or_that`, `letter_words`, `as_if`, `riddles`, `fact_or_fib`, `story_starters`, `rhyme_time`); written via `ContentBankDao.bankCrowdItem` for crowd-grown items. Live multi-device activities (Charades, live This-or-That) intentionally bypass this table and use the curated Dart floor only.
**Last verified**: 2026-06-01

---

_Last full registry verification: 2026-06-07 (Play Today / Skills / System Games / Print Toolkit) — `entries` table: `skill_measure` added to `kind` column values list; World added to Consumers (reads `skill_measure` + `week_log` kinds for character-sheet synthesis). No new tables — all four new features are migration-free (bundled JSON / new EntryKind on existing `entries` table)._

_Last full registry verification: 2026-06-06 (Today wave 1 — `_RightNowCard` + `DayPhase`; Pickup wave 2 — dismissal board; Incidents — new feature. `entries` Consumers updated to include Incidents + Pickup; `departure` kind added to entries key-columns. 2026-06-06 incremental — Incidents waves 4/5/6/7: `subjects` Consumers updated to include Incidents; `entries` Consumers already correct. 2026-06-06 Wave A/B — Incidents PDF export + family-facing incidents. `entries` key-columns + RLS gist updated to document the stripping RPC; Family consumer note clarified to distinguish observations path from incidents RPC path. FEATURES.md Incidents + Family sections reconciled. 2026-06-06 Action Words waves 1-4: `entries` `kind` column updated to include `action_words`; Action Words added to `entries` Consumers list. FEATURES.md Action Words Routes field updated to include `/action-words/:subjectId`; top-level orientation paragraph updated to list Action Words in the nav destinations order. 2026-06-07 incremental — Spells new feature (no table); Missions Do board (`kind='mission'` entries); Action Words Send + world-book surfaces. `entries` Consumers updated to include Missions. FEATURES.md Spells added; Missions Routes/Omnibox/Data/Surfaces updated; Action Words Routes/Surfaces updated. 2026-06-07 themed-world wave — `spaces` `capabilities` key-columns updated to enumerate `current_world`; Action Words added to `spaces` Consumers. FEATURES.md Action Words: Routes updated to include `/action-words/this-week` + `/action-words/activities`; Omnibox updated to include `page.this-weeks-world`; Capabilities updated to document `SpaceCaps.currentWorld`; Data updated to note `spaces` touch; Surfaces updated to add `themed_worlds.dart`, `themed_world_screen.dart`, `activity_match_screen.dart`, `_ThisWeekBanner`, `currentThemedWorldProvider`; Status + Depends on updated. 2026-06-07 Different Worlds rename (af7ed97) — `spaces` `capabilities` key-columns: removed `current_world` enumeration. `spaces` Consumers: removed Action Words (the `current_world` cap and `currentThemedWorldProvider` were deleted; the feature no longer reads `spaces.capabilities`). FEATURES.md Action Words: Routes renamed `/action-words/this-week` → `/action-words/different-worlds`; Omnibox entry renamed `page.this-weeks-world` / "This week's world" → `page.different-worlds` / "Different Worlds" with new keywords; Capabilities field: removed `SpaceCaps.currentWorld` sentence; Data field: removed `spaces` touch; Surfaces: updated `action_words_providers.dart` (removed `currentThemedWorldProvider`), updated `themed_world_screen.dart` description to gallery shape, updated `action_words_screen.dart` banner route ref; Depends on: removed Spaces. 2026-06-07 day-template builder (commit 74e8594) — `schedule_blocks` Consumers updated to note day-template `applyToDate` writes via `createDayBlocks`; `spaces` `capabilities` key-columns updated to enumerate `day_templates`; `spaces` Consumers updated to include Schedule. FEATURES.md Schedule: Routes updated to add `/schedule/day-templates` + `/schedule/day-templates/:id`; Omnibox updated to include `page.day-templates`; Capabilities updated to document `SpaceCaps.dayTemplates`; Data updated to add `spaces` touch; Surfaces updated to add day-template model/providers/library/editor; Depends on updated to add Spaces. 2026-06-07 week engine + worksheets + cast waves (commits fbfdda3, f53c430, 206b108) — `spaces` `capabilities` key-columns updated to enumerate `program_start_date`; Action Words added to `spaces` Consumers. FEATURES.md Action Words: Routes updated to add `/this-week` + `/present-world/:id`; Omnibox updated to add `page.this-week`; Data updated to note `spaces` touch via `program_start_date`; Surfaces updated to add `curriculum.dart`, `world_schedule.dart`, `this_week_screen.dart`, `world_present_screen.dart`, `worksheet_pdf.dart`, `_ThisWeekWorldCard`; Status, Depends on, Consumed by updated. 2026-06-07 "the Book" + "import curriculum activities" (commits 2021813 + 5d4db52) — `activities` `capabilities` key-columns updated to enumerate `action_verbs`, `curriculum_key`, `curriculum_world`; Action Words added to `activities` Consumers. FEATURES.md Action Words: Routes updated to add `/book/:subjectId`; Data updated to add `activities` write via `CurriculumImporter`; Surfaces updated to add `book_screen.dart` + `curriculum_import.dart`; Status + Depends on updated. Story feature folder stub added (no prior entry).)_
_If a synced table is missing, the feature-mapper agent will add a stub
the next time a migration touches that table. The Consumers list is
maintained bidirectionally with FEATURES.md — don't edit it by hand._

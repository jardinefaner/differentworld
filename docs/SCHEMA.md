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
**RLS gist**: relaxed; reads open to all members.
**Sync rule**: `by_space`.
**Consumers**: [Schedule](FEATURES.md#schedule).
**Last verified**: 2026-05-21

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
- `kind` (text — `observation` / `meal` / `nap` / `diaper` / `incident` / etc.)
- `payload` (jsonb — schema depends on kind)
- `author_id` (uuid → members.id)
- `occurred_at` (timestamptz)
- `schedule_block_id` (uuid, nullable — no FK; see migration `20260531000002_entry_schedule_block.sql`. Intentionally FK-free so entries survive block deletion with their tag intact.)
**RLS gist**: relaxed.
**Sync rule**: `by_space` (no publication/sync-rule change needed — entries was already replicated and `SELECT *` covers the new column).
**Consumers**: [Entries](FEATURES.md#entries), [Exports](FEATURES.md#exports) (Progress Report), [Captures](FEATURES.md#captures) (promotion destination), [Insights](FEATURES.md#insights), [Family](FEATURES.md#family), [Review](FEATURES.md#review), [Schedule](FEATURES.md#schedule) (live-block capture tagging — see docs/LIVE_BLOCK_CONTEXT.md).
**Last verified**: 2026-06-01

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
**Consumers**: [Schedule](FEATURES.md#schedule), [Settings](FEATURES.md#settings) (locations list).
**Last verified**: 2026-05-21

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
**Consumers**: [Schedule](FEATURES.md#schedule), [Today](FEATURES.md#today) (LeadingTodayCard).
**Last verified**: 2026-05-21

---

## spaces
**Purpose**: The workspace / program. One install runs one space with many groups; members are the team. Capabilities JSONB carries vertical + feature flags.
**Key columns**:
- `id` (uuid PK)
- `name` (text)
- `capabilities` (jsonb — `vertical`, `feature_observations`, `feature_meal_logging`, `pickup_window_start`, `pickup_window_end`, `default_class_size`, `photo_default_consent`, `state_compliance`, `staff_pin`, etc.)
- `created_at` (timestamptz)
- `created_by` (uuid → members.id)
**RLS gist**: relaxed.
**Sync rule**: `by_space` (a member's own space row). `by_guardian` stream also delivers the guardian's linked space row (`WHERE id IN (SELECT space_id FROM guardians WHERE user_id = auth.user_id())`) so the family lens resolves the space name offline-first.
**Consumers**: [Settings](FEATURES.md#settings), [Onboarding](FEATURES.md#onboarding), [Auth](FEATURES.md#auth) (viewer resolution), [Family](FEATURES.md#family) (offline-first via `by_guardian`), and every other feature via `viewer.spaceId`.
**Last verified**: 2026-05-23

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
**Consumers**: [Subjects](FEATURES.md#subjects), [Attendance](FEATURES.md#attendance), [Entries](FEATURES.md#entries), [Exports](FEATURES.md#exports), [Family](FEATURES.md#family), [Messages](FEATURES.md#messages), [Surveys](FEATURES.md#surveys), [Photos](FEATURES.md#photos).
**Last verified**: 2026-05-21

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
- `location` (text, nullable — free text, NOT a FK to locations; this is a storage location, not a scheduling place)
- `low_stock_threshold` (real, nullable — flags "running low" when quantity drops below)
- `photo_url` (text, nullable — Storage bucket-relative path; bytes in Supabase Storage)
**RLS gist**: relaxed (`for all to authenticated using(true) with check(true)`); GRANT-level + space-scoped sync rule are the real gate.
**Sync rule**: `by_space` stream; `SELECT * FROM supplies WHERE space_id IN (SELECT space_id FROM members WHERE id = auth.user_id())`. Dashboard deploy + device local-recreate still pending.
**Consumers**: [Supplies](FEATURES.md#supplies).
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

_Last full registry verification: 2026-06-01 (Missions slice 1)._
_If a synced table is missing, the feature-mapper agent will add a stub
the next time a migration touches that table. The Consumers list is
maintained bidirectionally with FEATURES.md — don't edit it by hand._

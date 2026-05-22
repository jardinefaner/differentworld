-- ---------------------------------------------------------------------------
-- Safe member deletion — relax `recorded_by` / `driver_member_id` etc. so
-- a member row can be deleted (account-deletion request, test data
-- cleanup, mistake correction) without blowing up the history.
--
-- The rule we're enforcing across the schema:
--
--   * "who did this" / "who recorded this" columns are HISTORY metadata.
--     When the member row goes away, the history row stays — the actor
--     column flips to NULL. UI displays as "Unknown" or "Former staff."
--
--   * Member-only side-tables (`member_certifications`, `group_members`,
--     `enrollments`, `dismissed_insights`) CASCADE — they exist FOR that
--     member; once the member's gone, the rows have no meaning.
--
--   * Nothing uses RESTRICT (the "block all deletes until you deactivate
--     manually" pattern). The product layer's "archive instead of delete"
--     UX is a softer rule that lives in the app; the schema has to survive
--     hard deletes anyway (GDPR / COPPA delete requests, automated test
--     cleanup).
--
-- This migration touches the columns that were either NOT NULL or missing
-- an `ON DELETE` clause. Columns that were already `ON DELETE SET NULL` /
-- `ON DELETE CASCADE` are not re-declared.
--
-- Supabase advisor reference: "Unindexed foreign keys" + "Restrict delete"
-- linter rules — this migration closes both classes (FK + index in one
-- pass per touched table).
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- attendance_records.recorded_by — was `not null references … on delete set
-- null`, which is internally inconsistent (the FK clause would set null
-- but the column rejected null). Make it nullable.
-- ---------------------------------------------------------------------------
alter table public.attendance_records
  alter column recorded_by drop not null;

-- ---------------------------------------------------------------------------
-- entries.recorded_by — was `not null references … (no on delete)`.
-- Drop NOT NULL + rewrite the FK to SET NULL.
-- ---------------------------------------------------------------------------
alter table public.entries
  alter column recorded_by drop not null;

alter table public.entries
  drop constraint if exists entries_recorded_by_fkey;
alter table public.entries
  add constraint entries_recorded_by_fkey
    foreign key (recorded_by) references public.members(id)
    on delete set null;

-- ---------------------------------------------------------------------------
-- vehicle_logs.driver_member_id — same shape as entries.recorded_by.
-- ---------------------------------------------------------------------------
alter table public.vehicle_logs
  alter column driver_member_id drop not null;

alter table public.vehicle_logs
  drop constraint if exists vehicle_logs_driver_member_id_fkey;
alter table public.vehicle_logs
  add constraint vehicle_logs_driver_member_id_fkey
    foreign key (driver_member_id) references public.members(id)
    on delete set null;

-- ---------------------------------------------------------------------------
-- attachments.uploaded_by — nullable already, missing ON DELETE clause.
-- ---------------------------------------------------------------------------
alter table public.attachments
  drop constraint if exists attachments_uploaded_by_fkey;
alter table public.attachments
  add constraint attachments_uploaded_by_fkey
    foreign key (uploaded_by) references public.members(id)
    on delete set null;

-- ---------------------------------------------------------------------------
-- trip_vehicles.driver_member_id — nullable already, missing ON DELETE.
-- ---------------------------------------------------------------------------
alter table public.trip_vehicles
  drop constraint if exists trip_vehicles_driver_member_id_fkey;
alter table public.trip_vehicles
  add constraint trip_vehicles_driver_member_id_fkey
    foreign key (driver_member_id) references public.members(id)
    on delete set null;

-- ---------------------------------------------------------------------------
-- headcounts.taken_by_member_id — nullable already, missing ON DELETE.
-- ---------------------------------------------------------------------------
alter table public.headcounts
  drop constraint if exists headcounts_taken_by_member_id_fkey;
alter table public.headcounts
  add constraint headcounts_taken_by_member_id_fkey
    foreign key (taken_by_member_id) references public.members(id)
    on delete set null;

-- ---------------------------------------------------------------------------
-- survey_responses.recorded_by — nullable already, missing ON DELETE.
-- ---------------------------------------------------------------------------
alter table public.survey_responses
  drop constraint if exists survey_responses_recorded_by_fkey;
alter table public.survey_responses
  add constraint survey_responses_recorded_by_fkey
    foreign key (recorded_by) references public.members(id)
    on delete set null;

-- ---------------------------------------------------------------------------
-- Unindexed foreign keys — every FK column gets an index so cascade /
-- set-null on parent delete doesn't trigger full table scans. Advisor
-- flagged these; we add only the ones currently missing.
-- ---------------------------------------------------------------------------
create index if not exists attendance_records_recorded_by_idx
  on public.attendance_records(recorded_by);
create index if not exists entries_recorded_by_idx
  on public.entries(recorded_by);
create index if not exists vehicle_logs_driver_member_id_idx
  on public.vehicle_logs(driver_member_id);
create index if not exists attachments_uploaded_by_idx
  on public.attachments(uploaded_by);
create index if not exists trip_vehicles_driver_member_id_idx
  on public.trip_vehicles(driver_member_id);
create index if not exists headcounts_taken_by_member_id_idx
  on public.headcounts(taken_by_member_id);
create index if not exists survey_responses_recorded_by_idx
  on public.survey_responses(recorded_by);

-- Index the SET NULL columns we already had so they also delete cleanly.
create index if not exists schedule_blocks_lead_member_id_idx
  on public.schedule_blocks(lead_member_id);
create index if not exists schedule_blocks_lead_substitute_member_id_idx
  on public.schedule_blocks(lead_substitute_member_id);
create index if not exists tasks_author_id_idx
  on public.tasks(author_id);
create index if not exists tasks_completed_by_idx
  on public.tasks(completed_by);
create index if not exists captures_author_id_idx
  on public.captures(author_id);
create index if not exists exports_author_id_idx
  on public.exports(author_id);
create index if not exists export_recipients_member_id_idx
  on public.export_recipients(member_id);
create index if not exists export_recipients_guardian_id_idx
  on public.export_recipients(guardian_id);
create index if not exists invites_created_by_idx
  on public.invites(created_by);
create index if not exists invites_accepted_by_idx
  on public.invites(accepted_by);
create index if not exists activities_owner_member_id_idx
  on public.activities(owner_member_id);
create index if not exists messages_sender_member_id_idx
  on public.messages(sender_member_id);
create index if not exists messages_sender_guardian_id_idx
  on public.messages(sender_guardian_id);
create index if not exists permission_slips_signer_guardian_id_idx
  on public.permission_slips(signer_guardian_id);

-- ---------------------------------------------------------------------------
-- Notes for the next round of advisor work (not addressed here):
--
--   * RLS init-plan optimization: replace `auth.uid()` with
--     `(select auth.uid())` in policies so Postgres evaluates the auth
--     function once per query, not once per row. Gated on fixing the
--     known `auth.uid()` returns null on ES256-keyed projects issue
--     documented in CLAUDE.md "Known gotchas" — once that's resolved
--     the relaxed `to authenticated using (true)` policies will tighten
--     to per-user / per-space and the init-plan fix becomes meaningful.
--
--   * The relaxed write policies (`using (true)` to authenticated) are
--     a known temporary workaround for the same `auth.uid()` issue.
--     Tightening them is the next big security pass — separate migration
--     because it requires either rotating to legacy HS256 keys or
--     finding why PostgREST isn't populating `request.jwt.claims`.
-- ---------------------------------------------------------------------------

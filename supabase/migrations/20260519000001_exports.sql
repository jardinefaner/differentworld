-- ---------------------------------------------------------------------------
-- exports: the audit / snapshot table for transmissions out of the
-- program (PDFs, CSVs, future emails).
--
-- An `exports` row is created the moment a director generates a
-- document; the row stays whether or not the doc was actually sent.
-- The status field follows the lifecycle:
--
--   draft     — generated locally, not yet shared (preview state)
--   sent      — handed to the platform share sheet / email channel
--   archived  — explicitly retired (kept for audit, hidden from list)
--
-- `snapshot_json` carries enough source data to re-render the PDF
-- byte-for-byte from the template at the same `template_version`.
-- We don't store the rendered bytes themselves on the row — they go
-- in Supabase Storage under `exports/<id>.pdf` (or `.csv`), URL on
-- the row. That keeps Postgres rows small and binary egress fast.
--
-- `export_recipients` is the join: who the document was sent to.
-- We support guardians (resolves to a guardian row), members
-- (internal share), or free-text email/identifier for external
-- parties without an account in the system.
-- ---------------------------------------------------------------------------

create table if not exists public.exports (
  id                uuid primary key default gen_random_uuid(),
  space_id          uuid not null references public.spaces(id) on delete cascade,

  -- Who ran the export. Nullable for the case where the author has
  -- left the program by the time someone reviews the audit log.
  author_id         uuid references public.members(id) on delete set null,

  -- The template that rendered this document. Looked up by string id
  -- in code (`progress_report`, `attendance_monthly`, etc.). Versioned
  -- so a future render against a different template version doesn't
  -- silently change what an old snapshot looks like.
  template_id       text not null,
  template_version  text not null default 'v1',

  -- Optional pointer to the entity the export is about. Most
  -- progress reports are subject-keyed; an end-of-month attendance
  -- might be group-keyed; a regulatory submission is space-keyed
  -- only (both subject_id and group_id null).
  subject_id        uuid references public.subjects(id) on delete set null,
  group_id          uuid references public.groups(id) on delete set null,

  -- The export's lifecycle.
  status            text not null default 'draft'
                      check (status in ('draft', 'sent', 'archived')),

  -- Output format. Used for the storage path's extension + the
  -- audit display.
  format            text not null check (format in ('pdf', 'csv')),

  -- Storage path for the rendered bytes — Supabase Storage object
  -- key. Null while still a draft. Populated when the file lands in
  -- Storage.
  storage_path      text,

  -- The full data the renderer used. JSON shape is template-specific.
  -- Stored so any future tool (a "re-render this with a new
  -- template version" feature, an audit fact-check) has the source
  -- of truth without depending on the live entities (which may have
  -- been edited since the snapshot).
  snapshot_json     jsonb not null default '{}'::jsonb,

  -- Human note from the author at export time. Optional.
  note              text,

  -- Lifecycle stamps.
  generated_at      timestamptz not null default now(),
  sent_at           timestamptz,
  archived_at       timestamptz,

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index if not exists exports_space_status_idx
  on public.exports (space_id, status, generated_at desc);

-- Per-subject export history — drives the "Sent reports" surface on
-- the subject detail screen.
create index if not exists exports_subject_idx
  on public.exports (subject_id, generated_at desc)
  where subject_id is not null;

create table if not exists public.export_recipients (
  id            uuid primary key default gen_random_uuid(),
  export_id     uuid not null references public.exports(id) on delete cascade,
  space_id      uuid not null references public.spaces(id) on delete cascade,

  -- Discriminator: which kind of recipient identity this row carries.
  --   'guardian' → guardian_id set
  --   'member'   → member_id set (internal share / handoff)
  --   'external' → external_email / external_label only (no entity)
  kind          text not null check (kind in ('guardian', 'member', 'external')),

  guardian_id   uuid references public.guardians(id) on delete set null,
  member_id     uuid references public.members(id) on delete set null,

  -- Free-text recipient — used when `kind = 'external'`. The label
  -- is shown in the audit ("Dr. Smith"); email is the routing key.
  external_label text,
  external_email text,

  -- Channel used to deliver. Free text so we can add channels
  -- (sms, in-app, paper) without a schema bump. 'manual' covers
  -- "the director shared the PDF via the OS share sheet, we have
  -- no idea where it ended up."
  channel       text not null default 'manual',

  -- Delivery state.
  --   pending → queued (will be set by future email/sms channels)
  --   delivered → confirmed receipt (bounce-checked)
  --   failed → channel reported failure
  --   manual → no auto-tracking (the share sheet path)
  state         text not null default 'manual'
                  check (state in ('pending', 'delivered', 'failed', 'manual')),

  state_detail  text,
  sent_at       timestamptz,
  read_at       timestamptz,

  created_at    timestamptz not null default now()
);

create index if not exists export_recipients_export_idx
  on public.export_recipients (export_id);

alter table public.exports replica identity full;
alter table public.export_recipients replica identity full;
alter table public.exports enable row level security;
alter table public.export_recipients enable row level security;

-- Read: space-scoped for staff; a guardian sees only the exports
-- where they're on the recipient list (so a parent can pull up
-- "what reports has the program sent me about my kid").
create policy "exports_read_by_space_or_recipient"
  on public.exports
  for select
  to authenticated
  using (
    space_id in (
      select space_id from public.members where id = auth.uid()
    )
    or id in (
      select export_id from public.export_recipients er
      join public.guardians g on g.id = er.guardian_id
      where g.user_id = auth.uid()
    )
  );

create policy "export_recipients_read_by_space_or_recipient"
  on public.export_recipients
  for select
  to authenticated
  using (
    space_id in (
      select space_id from public.members where id = auth.uid()
    )
    or guardian_id in (
      select id from public.guardians where user_id = auth.uid()
    )
  );

-- Writes: relaxed per the auth.uid() workaround.
create policy "exports_write_authenticated"
  on public.exports
  for all
  to authenticated
  using (true) with check (true);

create policy "export_recipients_write_authenticated"
  on public.export_recipients
  for all
  to authenticated
  using (true) with check (true);

alter publication powersync add table public.exports;
alter publication powersync add table public.export_recipients;

-- ---------------------------------------------------------------------------
-- Storage bucket for the rendered bytes. Private; signed URLs only.
-- The Edge Function in phase 4 mints download links.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('exports', 'exports', false)
on conflict (id) do nothing;

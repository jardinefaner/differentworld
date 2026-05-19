-- ---------------------------------------------------------------------------
-- captures: the upward loop's INPUT side.
--
-- Quick low-friction "I noticed…" entries that aren't yet tied to a
-- specific noun (subject / vehicle / day). A teacher mid-class wants to
-- jot "Bobby seemed off today" in two taps without stopping to fill in
-- an observation form. The capture goes to an inbox; later (end of day,
-- weekly review) the user triages it:
--   - Promote to an Observation for a specific kid
--   - Just remind me later (status=open stays put)
--   - Discard
--
-- Captures intentionally have no `subject_id` column. The whole point
-- is that the categorization happens AFTER the thought. Once promoted,
-- the new row lives in its own table (entries / future tasks / etc.)
-- and the capture gets status='promoted' + a pointer to what it became
-- (so we can build a small "what did this thought turn into" audit
-- trail without coupling the schemas).
--
-- Why a separate table from entries? Because:
--   • entries require a subject; captures don't
--   • status / triage state is a capture concept, not an observation
--   • the upward loop conversation (UX_DECISIONS) named capture as its
--     own first-class noun — promote it to a real table, not a JSONB
--     key on entries
-- ---------------------------------------------------------------------------

create table if not exists public.captures (
  id                uuid primary key default gen_random_uuid(),
  space_id          uuid not null references public.spaces(id) on delete cascade,
  -- Who jotted it. Nullable so a former staffer's captures survive the
  -- delete-as-set-null when they leave the program. The inbox can show
  -- "(former staff)" rather than disappear the row.
  author_id         uuid references public.members(id) on delete set null,

  -- The thought itself. No length cap — sometimes a capture is a
  -- paragraph of a parent conversation. Render in the UI with a
  -- 2-line snippet, full text on tap.
  body              text not null,

  -- Triage state.
  --   open       — still in the inbox, waiting on the human
  --   promoted   — turned into a downstream row (entry / task / etc.)
  --   discarded  — explicitly dismissed (kept for audit, hidden from inbox)
  status            text not null default 'open'
                      check (status in ('open', 'promoted', 'discarded')),

  -- What the capture became, when status='promoted'. Loose pointer —
  -- not a FK because the downstream table is open-ended (today it's
  -- entries; tomorrow it might be tasks / events / etc.). The kind
  -- string disambiguates.
  promoted_to_kind  text check (
    promoted_to_kind is null
    or promoted_to_kind in ('entry', 'task', 'insight')
  ),
  promoted_to_id    uuid,
  -- Optional: which subject the capture was promoted to (when
  -- promoted_to_kind='entry'). Lets the inbox show "→ Bobby's
  -- observation" inline without joining entries.
  promoted_subject_id uuid references public.subjects(id) on delete set null,

  processed_at      timestamptz,

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- Inbox feed: newest open first, scoped to space.
create index if not exists captures_space_created_idx
  on public.captures (space_id, created_at desc);

-- Status filter (open-only view in the inbox).
create index if not exists captures_space_status_idx
  on public.captures (space_id, status, created_at desc);

-- (No DB-side trigger for updated_at — every other table in this
-- project relies on the app to set it explicitly on write. Keeps the
-- contract one-way: client mutates, server stores.)

alter table public.captures replica identity full;
alter table public.captures enable row level security;

-- Read: any member of the space sees their team's captures (a
-- co-director shouldn't be locked out of a teacher's quick note).
-- We are NOT scoping by author here — the inbox is shared.
create policy "captures_read_by_space"
  on public.captures
  for select
  to authenticated
  using (
    space_id in (
      select space_id from public.members where id = auth.uid()
    )
  );

-- Write: relaxed per the CLAUDE.md ES256 / auth.uid() workaround.
-- Any authenticated user can write; the GRANT layer + space-scoped
-- SELECT keep the blast radius tight in practice. Re-tighten when
-- the JWT claims fix lands (see docs/SCALE_PUNCH_LIST.md).
create policy "captures_write_authenticated"
  on public.captures
  for insert
  to authenticated
  with check (true);

create policy "captures_update_authenticated"
  on public.captures
  for update
  to authenticated
  using (true) with check (true);

create policy "captures_delete_authenticated"
  on public.captures
  for delete
  to authenticated
  using (true);

alter publication powersync add table public.captures;

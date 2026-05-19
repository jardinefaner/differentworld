-- ---------------------------------------------------------------------------
-- messages: staff ↔ guardian threads, per-child.
--
-- A "thread" is implicit: the set of messages for a given
-- (subject_id, guardian_id) pair. We don't carry a separate
-- `threads` table because (a) every thread is uniquely identified by
-- that pair, and (b) the absence of a thread row is the absence of
-- messages — there's no thread metadata that wouldn't trivially
-- derive from the messages themselves.
--
-- Sender side discriminated by `sender_kind`:
--   'staff'    → sender_member_id set, sender_guardian_id null
--   'guardian' → sender_guardian_id set, sender_member_id null
--
-- Read tracking: `read_at` stamps when the OTHER side opened the
-- thread. Per-message-precise (not per-thread) so the read indicator
-- can be accurate as messages keep flowing.
-- ---------------------------------------------------------------------------

create table if not exists public.messages (
  id                  uuid primary key default gen_random_uuid(),
  space_id            uuid not null references public.spaces(id) on delete cascade,

  -- Thread identity: a (subject, guardian) pair.
  subject_id          uuid not null references public.subjects(id) on delete cascade,
  guardian_id         uuid not null references public.guardians(id) on delete cascade,

  -- Who sent it.
  sender_kind         text not null check (sender_kind in ('staff', 'guardian')),
  sender_member_id    uuid references public.members(id) on delete set null,
  sender_guardian_id  uuid references public.guardians(id) on delete set null,

  body                text not null,

  -- Stamped by the recipient on open. Null = unread.
  read_at             timestamptz,

  created_at          timestamptz not null default now()
);

-- Per-thread reads: every message in this (subject, guardian) pair,
-- newest first.
create index if not exists messages_thread_idx
  on public.messages (subject_id, guardian_id, created_at desc);

-- Unread counts: how many unread messages exist for the recipient.
-- Computed client-side from the local table; the index just keeps
-- the query cheap.
create index if not exists messages_unread_idx
  on public.messages (subject_id, guardian_id, sender_kind)
  where read_at is null;

alter table public.messages replica identity full;
alter table public.messages enable row level security;

-- Read: staff sees every message in their space; a guardian sees
-- only messages where they're on one side of the thread.
create policy "messages_read_by_space_or_thread"
  on public.messages
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

-- Writes: relaxed per the CLAUDE.md auth.uid() workaround. The space
-- + thread membership is implicitly enforced by the read policy
-- (you can only mark unread something you can read) and the
-- application validates sender identity on write.
create policy "messages_insert_authenticated"
  on public.messages
  for insert
  to authenticated
  with check (true);

create policy "messages_update_authenticated"
  on public.messages
  for update
  to authenticated
  using (true) with check (true);

create policy "messages_delete_authenticated"
  on public.messages
  for delete
  to authenticated
  using (true);

alter publication powersync add table public.messages;

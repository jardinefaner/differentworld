-- ---------------------------------------------------------------------------
-- Per-guardian read-state on messages.
--
-- Devon persona — divorced parents share a child; both have access to the
-- staff↔family thread. Today messages.read_at is a single timestamp,
-- which can't represent "Mom read this, Dad hasn't yet." Adds a JSONB
-- list of guardian UUIDs who have opened the thread past this message.
--
-- The staff side surfaces "Seen by both" / "Seen by Mom only" / "Unread"
-- badges driven off this list. The existing read_at column stays as the
-- "first read by any party" timestamp for backward compatibility.
-- ---------------------------------------------------------------------------

alter table public.messages
  add column if not exists read_by_guardian_ids jsonb not null default '[]'::jsonb;

create index if not exists messages_read_by_guardian_ids_gin
  on public.messages using gin (read_by_guardian_ids);

-- Touch updated_at so PowerSync's CRUD queue picks up the schema change
-- on next sync. (No data migration needed — default '[]' is sane.)

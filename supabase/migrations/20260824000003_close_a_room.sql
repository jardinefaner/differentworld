-- Closing a room, instead of deleting it (docs/ROOMS.md).
--
-- Same bug as the one that hit children, one level up. A room could be
-- edited or hard-deleted, and nothing in between — so a program that stops
-- running Sparrows had two options: leave it cluttering every picker,
-- schedule tab and roster forever, or press Delete.
--
-- Delete is worse than it looks. `subjects.group_id` is ON DELETE SET NULL,
-- so children genuinely do survive (the dialog was right about that) — but
-- SIX tables cascade: group_members, schedule_blocks, weekly_template_blocks,
-- rotation_rounds, room_events, and the legacy staff `enrollments`. Deleting
-- a room silently takes its ENTIRE SCHEDULE with it, which the dialog never
-- said.
--
-- So: active | closed. A closed room keeps everything and simply stops
-- appearing in the surfaces that describe today.

alter table public.groups
  add column if not exists status text not null default 'active';

create index if not exists groups_status_idx
  on public.groups (space_id, status);

-- ---------------------------------------------------------------------------
-- attachments: unified photo / PDF / audio storage for any entity.
--
-- Per UX_DECISIONS §8 — promotes photo bytes from scattered `photo_url`
-- columns + `entries.details.photos` JSONB arrays to a first-class
-- entity with proper identity (caption, mime_type, sort_order),
-- cross-entity indexability ("every photo uploaded this week"), and a
-- single GC path.
--
-- This first migration:
--   1. Creates the table.
--   2. Backfills from `entries.photo_url` + `entries.details.photos`
--      into rows with entity_kind='entry'. (Subjects / members /
--      vehicles photos backfill in a follow-up migration so the
--      surface area of this commit stays reviewable.)
--   3. Drops the `photos` key from entries.details (preserves the
--      rest of the JSON blob). Leaves `entries.photo_url` populated
--      for one release as a back-compat read fallback; the next
--      attachments-migration commit drops it.
-- ---------------------------------------------------------------------------

create table if not exists public.attachments (
  id              uuid primary key default gen_random_uuid(),
  space_id        uuid not null references public.spaces(id) on delete cascade,

  -- What does this attach to? Strings (not foreign keys) so the
  -- attached entity can be any kind: subject, member, vehicle, entry,
  -- member_certification, future pickup_person, etc. The
  -- (entity_kind, entity_id) lookup is the access pattern; we add a
  -- composite index. Keep entity_kind values lowercase singular
  -- ('entry', 'subject', 'member', 'vehicle', 'certification').
  entity_kind     text not null,
  entity_id       uuid not null,

  -- Public Storage URL today (per CLAUDE.md the v0.1 contract is
  -- public-with-UUID inside the person-photos bucket; the contract
  -- doc tracks the migration to signed URLs). When that lands, this
  -- column stays — the URL just becomes short-lived.
  url             text not null,

  -- 256dp thumbnail variant. Null = none generated yet; readers fall
  -- back to `url` until a thumbnailer fills it in.
  thumb_url       text,

  -- 'image/jpeg', 'application/pdf', 'audio/mpeg', etc. Drives the
  -- right viewer (PhotoViewer for images, future PdfViewer, etc).
  mime_type       text not null default 'image/jpeg',

  -- Optional caption / description for the asset.
  caption         text,

  -- Ordering within an entity's gallery. Lower = earlier. Null →
  -- treated as "after everything ordered"; readers sort by
  -- (sort_order asc nulls last, created_at asc).
  sort_order      int,

  uploaded_by     uuid references public.members(id),
  taken_at        timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists attachments_entity_idx
  on public.attachments(entity_kind, entity_id, sort_order, created_at);
create index if not exists attachments_space_kind_idx
  on public.attachments(space_id, entity_kind, created_at desc);

alter table public.attachments replica identity full;
alter table public.attachments enable row level security;

create policy "attachments_authenticated_all"
  on public.attachments
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.attachments;


-- ---------------------------------------------------------------------------
-- Backfill: every existing entry photo becomes an attachments row.
-- ---------------------------------------------------------------------------

-- 1. entries.photo_url → sort_order = 0 (primary photo).
insert into public.attachments
  (space_id, entity_kind, entity_id, url, sort_order, uploaded_by, taken_at, created_at)
select
  e.space_id,
  'entry',
  e.id,
  e.photo_url,
  0,
  e.recorded_by,
  e.recorded_at,
  e.recorded_at
from public.entries e
where e.photo_url is not null
  and e.photo_url <> ''
  -- Skip rows we already imported (idempotent for repeat runs).
  and not exists (
    select 1 from public.attachments a
    where a.entity_kind = 'entry'
      and a.entity_id = e.id
      and a.url = e.photo_url
  );

-- 2. entries.details.photos array → sort_order 1, 2, …
insert into public.attachments
  (space_id, entity_kind, entity_id, url, sort_order, uploaded_by, taken_at, created_at)
select
  e.space_id,
  'entry',
  e.id,
  a.extra_url,
  -- 1-based because position 0 is the primary photo_url above.
  (a.idx::int) + 1,
  e.recorded_by,
  e.recorded_at,
  e.recorded_at
from public.entries e
cross join lateral jsonb_array_elements_text(
  coalesce(e.details->'photos', '[]'::jsonb)
) with ordinality as a(extra_url, idx)
where a.extra_url is not null
  and a.extra_url <> ''
  and not exists (
    select 1 from public.attachments att
    where att.entity_kind = 'entry'
      and att.entity_id = e.id
      and att.url = a.extra_url
  );

-- 3. Drop the photos key from details (preserve the rest of the JSON).
update public.entries
set details = details - 'photos'
where details ? 'photos';

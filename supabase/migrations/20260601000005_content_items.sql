-- The content bank (docs/CONTENT_BANK.md) — activity content made once and
-- reused forever, so we never call AI on the hot path of a play. Curated
-- content ships in the app (the offline floor); THIS table holds the two
-- dynamic tiers:
--
--   • AI-generated  → GLOBAL rows (space_id IS NULL). Generated once by the
--     brokered Edge Function and synced to EVERY program — generate-once-for-
--     everyone is the whole cost win. Inserted server-side (service role).
--   • Crowd-grown   → per-space rows (space_id = the program). The kids' own
--     creations enrich their program's bank. Inserted client-side via Drift.
--
-- A content item is a SEMANTIC_GRAPH noun: data, generated once, synced,
-- reused. `fingerprint` is the de-dupe key; `payload` is the shape the
-- activity reads (jsonb, shipped as text to the device).

create table if not exists public.content_items (
  id            uuid primary key default gen_random_uuid(),
  -- NULL = shared/global (AI + future global-curated); set = this program's
  -- own (crowd-grown). On delete of a space, its crowd rows go; global stays.
  space_id      uuid references public.spaces(id) on delete cascade,

  kind          text not null,   -- 'this_or_that' | 'riddle' | 'charades' | …
  payload       jsonb not null,  -- {a,b} | {prompt,answer} | {word,category} …
  fingerprint   text not null,   -- de-dupe hash of the normalized payload
  source        text not null default 'curated', -- curated|ai|crowd|local

  created_by    uuid,            -- member/auth id for crowd rows; null for ai
  created_at    timestamptz not null default now()
);

-- Uniqueness is the bank's job (docs/CONTENT_BANK.md §4), enforced here.
-- TWO partial indexes instead of one `unique (kind, space_id, fingerprint)`
-- because Postgres treats NULLs as DISTINCT in a unique constraint — so a
-- single constraint would let duplicate GLOBAL rows (space_id IS NULL)
-- through. Split by space-scope so global de-dupes on (kind, fingerprint)
-- and per-space de-dupes on (kind, space_id, fingerprint).
create unique index if not exists content_items_uniq_space
  on public.content_items (kind, space_id, fingerprint)
  where space_id is not null;
create unique index if not exists content_items_uniq_global
  on public.content_items (kind, fingerprint)
  where space_id is null;

-- Serve-by-kind is the hot read; index it (covers global + per-space).
create index if not exists content_items_kind_idx
  on public.content_items (kind, space_id);

alter table public.content_items replica identity full;

alter table public.content_items enable row level security;

-- Relaxed policy, consistent with the ES256 auth.uid()-null workaround
-- (see CLAUDE.md). The sync rules (per-space `by_space` + the global
-- `global_content` stream) + the GRANT layer are the real gate. Content is
-- non-PII game prompts; broad read is fine. AI rows are written server-side
-- with the service role (bypasses RLS).
create policy "content_items_authenticated_all" on public.content_items
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.content_items;

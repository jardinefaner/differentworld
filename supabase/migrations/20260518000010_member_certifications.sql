-- ---------------------------------------------------------------------------
-- member_certifications: promote certifications from JSONB-on-member to a
-- first-class space-scoped entity (UX_DECISIONS §8).
--
-- Each cert that a staff member holds gets one row. Lifecycle data
-- (issued_at, expires_at) lives on the row, not in a parallel JSONB
-- shape that could desync. Future cert documents (photo of the actual
-- license / MAT card) will reference an attachments row via
-- document_url; that column is plain text for now and will graduate
-- once we promote attachments.
--
-- Cap-gated caps that the cert governs (e.g. MAT → can_administer_medication)
-- continue to live in members.capabilities as boolean flags. The cert is
-- the EVIDENCE; the cap is the PERMISSION. Removing or expiring a cert
-- still cascades the gated cap off — that logic now lives in the
-- client-side CertActions.
-- ---------------------------------------------------------------------------

create table if not exists public.member_certifications (
  id              uuid primary key default gen_random_uuid(),
  space_id        uuid not null references public.spaces(id) on delete cascade,
  member_id       uuid not null references public.members(id) on delete cascade,
  cert_key        text not null,
  issued_at       date,
  expires_at      date,
  notes           text,
  -- Free-form URL today (photo of license, PDF of certificate, etc).
  -- Will migrate to attachment_id once the attachments table lands.
  document_url    text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Each member can hold a given cert_key at most once. Renewing replaces
-- the existing row (we don't currently keep history; if we ever need
-- it, a separate cert_history table is the right shape).
create unique index if not exists member_certifications_member_cert_idx
  on public.member_certifications(member_id, cert_key);

-- Powers the future "Expiring in 30 days" director dashboard. Partial
-- index so it stays small when most rows never expire.
create index if not exists member_certifications_space_expires_idx
  on public.member_certifications(space_id, expires_at)
  where expires_at is not null;

alter table public.member_certifications replica identity full;
alter table public.member_certifications enable row level security;

create policy "member_certifications_authenticated_all"
  on public.member_certifications
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.member_certifications;


-- ---------------------------------------------------------------------------
-- Backfill from JSONB → rows. Runs ONCE on migration apply.
--
-- Source shape (members.capabilities):
--   {"certifications": ["mat", "cpr"],
--    "certification_expirations": {"mat": "2027-06-15"}}
-- ---------------------------------------------------------------------------

insert into public.member_certifications (space_id, member_id, cert_key, expires_at)
select
  m.space_id,
  m.id as member_id,
  cert_key,
  case
    when expires_str is null or expires_str = '' then null
    else expires_str::date
  end as expires_at
from public.members m
cross join lateral jsonb_array_elements_text(
  coalesce(m.capabilities->'certifications', '[]'::jsonb)
) as cert_key
left join lateral (
  select m.capabilities->'certification_expirations'->>cert_key as expires_str
) as e on true
where m.space_id is not null
on conflict (member_id, cert_key) do nothing;


-- ---------------------------------------------------------------------------
-- Drop the JSONB keys we just migrated. Other capability keys
-- (can_observe, can_drive, etc.) stay untouched — the `-` operator
-- removes specific keys, not the whole blob.
-- ---------------------------------------------------------------------------

update public.members
set capabilities = capabilities - 'certifications' - 'certification_expirations'
where capabilities ? 'certifications'
   or capabilities ? 'certification_expirations';

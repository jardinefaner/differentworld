-- ---------------------------------------------------------------------------
-- dismissed_insights: per-member snooze for the derived insights surface.
--
-- Insights are computed on-device from existing data (no insights table).
-- Snoozing one means recording that *this member* doesn't want to see
-- *this exact insight_id* until `until_at`. When until_at passes (or is
-- null = "until I undismiss it manually"), the row reappears in the feed.
--
-- Insight ids are stable strings produced by the on-device derivation
-- (`cert_expired_<member_id>_<cert_key>`, `late_streak_<subject_id>`,
-- etc). Matching is exact-string; we don't try to be smart about
-- "similar" insights — if the underlying pattern changes (different
-- kid, different cert), the new insight has a different id and
-- surfaces fresh.
-- ---------------------------------------------------------------------------

create table if not exists public.dismissed_insights (
  id              uuid primary key default gen_random_uuid(),
  space_id        uuid not null references public.spaces(id) on delete cascade,
  member_id       uuid not null references public.members(id) on delete cascade,
  insight_id      text not null,

  -- When the dismissal expires. Null = manual undismiss only. We don't
  -- have a "permanent" flag because the underlying pattern can recur;
  -- we'd rather the system re-surface it after the snooze window than
  -- silently swallow it forever.
  dismissed_until timestamptz,

  created_at      timestamptz not null default now()
);

-- Each member dismisses a specific insight at most once. Re-dismissing
-- replaces the prior row (the UI calls upsert).
create unique index if not exists dismissed_insights_member_insight_uniq
  on public.dismissed_insights(member_id, insight_id);

create index if not exists dismissed_insights_space_idx
  on public.dismissed_insights(space_id, member_id);

alter table public.dismissed_insights replica identity full;
alter table public.dismissed_insights enable row level security;

create policy "dismissed_insights_authenticated_all"
  on public.dismissed_insights
  for all to authenticated
  using (true) with check (true);

alter publication powersync add table public.dismissed_insights;

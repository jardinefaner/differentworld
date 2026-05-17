-- Different World — Restore default role grants on public schema
--
-- During the early schema-drift recovery in dev (`drop schema public
-- cascade; create schema public; ...`) we only granted defaults for
-- `postgres` and `service_role`. Supabase's stock setup *also* grants
-- the `authenticated` and `anon` roles baseline access — without these,
-- every PowerSync upload returns 42501 ("permission denied for table
-- programs / classrooms / ...") because PostgreSQL's privilege check
-- fires BEFORE RLS evaluation. RLS policies cannot rescue a missing
-- table-level GRANT.
--
-- This migration restores the standard pattern:
--   anon          → SELECT on tables (RLS still gates rows)
--   authenticated → SELECT/INSERT/UPDATE/DELETE on tables (RLS gates rows)
--   service_role  → ALL (already correct)
--
-- Default privileges are also restored so any future tables added to
-- public inherit the same grants automatically.

-- Schema usage (idempotent re-grant).
grant usage on schema public to anon, authenticated, service_role;

-- Existing tables.
grant select on all tables in schema public to anon, authenticated;
grant insert, update, delete on all tables in schema public to authenticated;

-- Future tables added to public inherit the same access.
alter default privileges in schema public
  grant select on tables to anon, authenticated;
alter default privileges in schema public
  grant insert, update, delete on tables to authenticated;

-- Sequences (only matters for SERIAL/BIGSERIAL columns; harmless otherwise).
grant usage, select on all sequences in schema public
  to anon, authenticated;
alter default privileges in schema public
  grant usage, select on sequences to anon, authenticated;

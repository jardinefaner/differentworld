-- ---------------------------------------------------------------------------
-- Expose accept_invite as a PostgREST-callable RPC.
--
-- Why: helper functions live in the `app` schema specifically so that
-- PostgREST does NOT auto-expose them (see CLAUDE.md
-- "Helper functions live in the `app` schema"). But the newcomer
-- onboarding flow needs to call accept_invite from the client over
-- HTTPS — supabase.rpc('accept_invite', ...). That means we need a
-- thin public-schema wrapper that delegates to the real implementation
-- in `app`.
--
-- The wrapper inherits the security_definer behavior of app.accept_invite
-- — the actual privilege escalation and search_path lockdown live in
-- the inner function, so this wrapper stays minimal.
-- ---------------------------------------------------------------------------

create or replace function public.accept_invite(invite_code text default null)
returns void
language sql
security invoker
set search_path = ''
as $$
  select app.accept_invite(invite_code);
$$;

grant execute on function public.accept_invite(text) to authenticated;

comment on function public.accept_invite(text) is
  'RPC wrapper for app.accept_invite. Pass a code, or null to match by '
  'the signed-in user''s email. Used by the newcomer onboarding flow.';

-- Different World — Fix app.accept_invite for guardian-role invites.
--
-- TWO BUGS FIXED IN ONE PASS:
--
-- 1. Type mismatch on is_primary. The function passed integer `0` into
--    `subject_guardians.is_primary` which is a `boolean not null` column.
--    Postgres rejects `int → boolean` in strict typing → the RPC throws
--    at PLAN time (before the WHERE clause even runs to discover the
--    `auth.uid()` NULL). Surfaces in the UI as the generic "Could not
--    redeem that invite. Please try again." string with no clue what
--    actually broke.
--
-- 2. `auth.uid()` returns NULL in REST requests on this ES256-keyed
--    project (the gotcha documented in CLAUDE.md and worked around for
--    INSERT/UPDATE/DELETE via migration 20260517000002, and for SELECT
--    via migrations 20260523000001 + 20260523000002). The accept_invite
--    function reads `auth.uid()` no fewer than FIVE times — without a
--    workaround, every code path inside the function silently produces
--    a useless result: the guardian row never gets `user_id` set, the
--    subject_guardians link is never written, and the next sign-in
--    can't resolve the guardian. The invite IS marked accepted, so
--    the user sees their attempt go through but the app refuses to
--    recognise them.
--
-- The fix: take the auth user id as an EXPLICIT parameter. The Dart
-- client reads `session.user.id` and passes it down. The function
-- falls back to `auth.uid()` only if the parameter is null (legacy
-- callers; once all clients pass the id explicitly we can drop the
-- fallback). Also fixes the `0 → false` literal.
--
-- The public wrapper grows a second optional param. Old wrapper callers
-- (pre-Wave 44 client) still work; the function uses auth.uid() in that
-- legacy path and breaks the way it always did. New clients pass both.

-- Drop the old wrapper FIRST so we can change the signature.
drop function if exists public.accept_invite(text);

-- New definer-side implementation.
create or replace function app.accept_invite(
  invite_code text default null,
  caller_uid uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invite        public.invites%rowtype;
  v_email         text;
  v_uid           uuid;
  v_guardian_id   uuid;
begin
  -- Prefer the explicit param (passed by the client from
  -- session.user.id) over auth.uid() — see header comment.
  v_uid := coalesce(caller_uid, auth.uid());
  if v_uid is null then
    raise exception 'No authenticated user. Sign in and try again.';
  end if;

  select email into v_email from auth.users where id = v_uid;

  select * into v_invite
    from public.invites
   where accepted_at is null
     and (expires_at is null or expires_at > now())
     and (
       (invite_code is not null and code = invite_code)
       or (invite_code is null and email = v_email)
     )
   order by created_at desc
   limit 1;

  if v_invite.id is null then
    raise exception 'No matching active invite';
  end if;

  if v_invite.role = 'guardian' then
    -- Family path. Update an existing guardian row by email match, or
    -- insert a new one if none.
    update public.guardians
       set user_id    = v_uid,
           email      = coalesce(email, v_email),
           updated_at = now()
     where space_id  = v_invite.space_id
       and user_id is null
       and (email = v_email or email = v_invite.email)
     returning id into v_guardian_id;

    if v_guardian_id is null then
      -- No matching guardian; create one and link.
      insert into public.guardians (
        id, space_id, user_id, name, email, created_at, updated_at
      ) values (
        gen_random_uuid(),
        v_invite.space_id,
        v_uid,
        coalesce(v_invite.email, v_email, 'Family member'),
        v_email,
        now(),
        now()
      )
      returning id into v_guardian_id;
    end if;

    -- Link to the subject the director picked when minting the
    -- invite. `false` not `0` — `is_primary` is a boolean. Also gate
    -- the WHERE on the guardian id we just resolved instead of
    -- re-reading auth.uid().
    if v_invite.subject_id is not null then
      insert into public.subject_guardians (
        subject_id, guardian_id, space_id, is_primary, created_at
      ) values (
        v_invite.subject_id,
        v_guardian_id,
        v_invite.space_id,
        false,
        now()
      )
      on conflict (subject_id, guardian_id) do nothing;
    end if;
  else
    -- Staff path. Stamp the existing member row (created by the
    -- handle_new_user trigger on first auth) with the invite's
    -- space_id + role + capabilities.
    update public.members
       set space_id     = v_invite.space_id,
           role         = v_invite.role,
           capabilities = coalesce(capabilities, '{}'::jsonb)
                         || v_invite.capabilities,
           updated_at   = now()
     where id = v_uid;
  end if;

  update public.invites
     set accepted_at = now(),
         accepted_by = v_uid
   where id = v_invite.id;
end;
$$;

grant execute on function app.accept_invite(text, uuid) to authenticated;

-- Public wrapper, security invoker. Delegates to the definer.
create or replace function public.accept_invite(
  invite_code text default null,
  caller_uid  uuid default null
)
returns void
language sql
security invoker
set search_path = ''
as $$
  select app.accept_invite(invite_code, caller_uid);
$$;

grant execute on function public.accept_invite(text, uuid) to authenticated;

comment on function public.accept_invite(text, uuid) is
  'RPC wrapper for app.accept_invite. Pass invite_code (or null to '
  'match by email) and caller_uid (session.user.id from the client) '
  'so the function can resolve the caller without relying on '
  'auth.uid(), which returns null in REST requests on this project.';

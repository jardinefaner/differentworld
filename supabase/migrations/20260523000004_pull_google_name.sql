-- Different World — Pull Google account name into member + guardian rows.
--
-- USER REPORT: a guardian signed up via Google OAuth, redeemed an
-- invite, and saw the drawer show "?-" instead of their name. Three
-- layers of the same root cause:
--
-- 1. `app.handle_new_user` (the on-auth-user-insert trigger) coalesces
--    `display_name → full_name → email-local-part` when seeding the
--    `members.display_name`. Google OAuth's standard claim for a
--    user's full name is `name` — NOT `display_name` (Supabase's
--    own convention) and NOT `full_name` (legacy / inconsistent).
--    Result: the coalesce falls through to `split_part(email, '@', 1)`
--    so a "john.smith@gmail.com" sign-in shows as "john.smith".
--    Worse for a guardian who isn't even staff — that local-part is
--    rendered in the drawer as their identity.
--
-- 2. `app.accept_invite` (guardian branch) sets the guardian's `name`
--    to `coalesce(v_invite.email, v_email, 'Family member')`. ALL
--    three are emails (or the literal string) — never the actual
--    person's name. The director typed the parent's email; the
--    parent signed up with Google; the auth user's name in
--    `raw_user_meta_data` is exactly what we want but nothing
--    consults it.
--
-- 3. (Dart side) the drawer hardcodes `member.display_name` for
--    everyone — for guardians it should resolve through
--    `viewer.displayName` which returns `guardian.name`. Fix lives
--    in the same wave, alongside this migration.
--
-- THIS MIGRATION:
--   - Updates `app.handle_new_user` to ALSO try the `name` claim.
--   - Updates `app.accept_invite` (guardian branch) to prefer the
--     auth user's name from `raw_user_meta_data` when setting /
--     updating the guardian row.
--   - Backfills existing `members` rows whose `display_name` looks
--     like a placeholder (matches the email local-part exactly)
--     by re-running the coalesce against current auth metadata.
--   - Backfills existing `guardians` rows whose `name` looks like an
--     email and whose `user_id` is set, using the same source.

-- 1. Trigger: try `name` first, then existing fallbacks.
create or replace function app.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.members (id, display_name)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data->>'name'), ''),
      nullif(trim(new.raw_user_meta_data->>'display_name'), ''),
      nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
      split_part(new.email, '@', 1)
    )
  );
  return new;
end;
$$;

-- 2. accept_invite: same coalesce shape for guardian.name.
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
  v_user_name     text;
  v_guardian_id   uuid;
begin
  v_uid := coalesce(caller_uid, auth.uid());
  if v_uid is null then
    raise exception 'No authenticated user. Sign in and try again.';
  end if;

  -- Pull both email and the friendliest available name claim in one
  -- round to auth.users. `name` is Google's standard claim; the
  -- other two are alternative provider conventions; fall through to
  -- email-local-part so something always renders.
  select
    u.email,
    coalesce(
      nullif(trim(u.raw_user_meta_data->>'name'), ''),
      nullif(trim(u.raw_user_meta_data->>'display_name'), ''),
      nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
      split_part(u.email, '@', 1)
    )
  into v_email, v_user_name
  from auth.users u
  where u.id = v_uid;

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
    -- Update an existing guardian row by email match. We also UPGRADE
    -- the name to the auth user's real name when the existing row
    -- only had an email-shaped placeholder OR the director typed
    -- something less specific than what Google gave us.
    update public.guardians
       set user_id = v_uid,
           email   = coalesce(email, v_email),
           name    = case
                       when name is null or trim(name) = ''
                            or position('@' in name) > 0
                       then v_user_name
                       else name
                     end,
           updated_at = now()
     where space_id  = v_invite.space_id
       and user_id is null
       and (email = v_email or email = v_invite.email)
     returning id into v_guardian_id;

    if v_guardian_id is null then
      -- No matching guardian; create one with the auth user's name as
      -- the primary identity — preferred over either email.
      insert into public.guardians (
        id, space_id, user_id, name, email, created_at, updated_at
      ) values (
        gen_random_uuid(),
        v_invite.space_id,
        v_uid,
        coalesce(nullif(trim(v_user_name), ''), 'Family member'),
        v_email,
        now(),
        now()
      )
      returning id into v_guardian_id;
    end if;

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
    -- space_id + role + capabilities. Also upgrade display_name if
    -- it's still the email-local-part placeholder.
    update public.members
       set space_id     = v_invite.space_id,
           role         = v_invite.role,
           capabilities = coalesce(capabilities, '{}'::jsonb)
                         || v_invite.capabilities,
           display_name = case
                            when display_name is null
                                 or trim(display_name) = ''
                                 or display_name = split_part(v_email, '@', 1)
                            then v_user_name
                            else display_name
                          end,
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

-- 3. Backfill: members whose display_name looks like a placeholder
-- (matches the email local-part exactly OR is empty). One-shot DML.
update public.members m
   set display_name = sub.fresh_name,
       updated_at = now()
  from (
    select
      u.id,
      coalesce(
        nullif(trim(u.raw_user_meta_data->>'name'), ''),
        nullif(trim(u.raw_user_meta_data->>'display_name'), ''),
        nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
        split_part(u.email, '@', 1)
      ) as fresh_name,
      u.email
    from auth.users u
  ) sub
 where m.id = sub.id
   and sub.fresh_name is not null
   and sub.fresh_name <> ''
   and sub.fresh_name <> m.display_name
   and (
     m.display_name is null
     or trim(m.display_name) = ''
     or m.display_name = split_part(sub.email, '@', 1)
   );

-- 4. Backfill: guardians whose name looks like an email (contains @)
-- and whose user_id is set. Use the linked auth user's name.
update public.guardians g
   set name = sub.fresh_name,
       updated_at = now()
  from (
    select
      u.id,
      coalesce(
        nullif(trim(u.raw_user_meta_data->>'name'), ''),
        nullif(trim(u.raw_user_meta_data->>'display_name'), ''),
        nullif(trim(u.raw_user_meta_data->>'full_name'), ''),
        split_part(u.email, '@', 1)
      ) as fresh_name
    from auth.users u
  ) sub
 where g.user_id = sub.id
   and sub.fresh_name is not null
   and sub.fresh_name <> ''
   and (g.name is null or position('@' in g.name) > 0);

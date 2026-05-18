-- ---------------------------------------------------------------------------
-- Wire the family-login flow.
--
-- 1. guardians.user_id — links a guardian contact row to the
--    auth.users.id of the parent who signs in. Nullable so a director
--    can add a parent's contact info long before that parent is ever
--    invited / signs in.
-- 2. invites.subject_id — for guardian-intent invites, which child
--    they're being invited as a guardian for. Null for staff invites.
-- 3. Rewrites app.accept_invite to branch on role:
--    role = 'guardian' → link the auth user to the existing guardian
--      row by email match; create + link the subject_guardians row.
--    anything else → existing members update path.
-- ---------------------------------------------------------------------------

alter table public.guardians
  add column if not exists user_id uuid references auth.users(id) on delete set null;

create unique index if not exists guardians_user_id_unique
  on public.guardians(user_id) where user_id is not null;

alter table public.invites
  add column if not exists subject_id uuid references public.subjects(id) on delete cascade;

-- Replace app.accept_invite — branches on role.
create or replace function app.accept_invite(invite_code text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invite public.invites%rowtype;
  v_email  text;
  v_uid    uuid;
begin
  v_uid := auth.uid();
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
    -- Family path. The guardian row was created by the director when
    -- they added the parent's contact info to the child. We link by
    -- the email the director typed in matching the signed-in user's
    -- auth.users.email. If no row matches we create one — that means
    -- the director sent a raw code invite without pre-adding the
    -- contact info, which is allowed but rarer.
    update public.guardians
       set user_id = v_uid,
           email = coalesce(email, v_email),
           updated_at = now()
     where space_id = v_invite.space_id
       and user_id is null
       and (email = v_email or email = v_invite.email)
     returning id into v_uid;

    if v_uid is null then
      -- No matching guardian; create one and link.
      v_uid := auth.uid();
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
      returning id into v_uid;
    end if;

    -- Link the freshly-set guardian to the subject (if the invite
    -- specified one — rare to leave it null).
    if v_invite.subject_id is not null then
      insert into public.subject_guardians (
        subject_id, guardian_id, space_id, is_primary, created_at
      )
      select v_invite.subject_id, g.id, v_invite.space_id, 0, now()
        from public.guardians g
       where g.user_id = auth.uid()
       on conflict (subject_id, guardian_id) do nothing;
    end if;
  else
    -- Staff path — original behavior.
    update public.members
       set space_id     = v_invite.space_id,
           role         = v_invite.role,
           capabilities = coalesce(capabilities, '{}'::jsonb) || v_invite.capabilities,
           updated_at   = now()
     where id = auth.uid();
  end if;

  update public.invites
     set accepted_at = now(),
         accepted_by = auth.uid()
   where id = v_invite.id;
end;
$$;

grant execute on function app.accept_invite(text) to authenticated;

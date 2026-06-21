-- Family-safe observation read.
--
-- A staff observation body can name OTHER children ("Sofia and Mateo built a
-- fort"). The family lens reads `entries` over plain PostgREST (RLS is
-- `for select ... using (true)`), so the raw body ships to a guardian's device
-- where another child's name is readable over the wire — the exact class
-- CLAUDE.md says family-facing staff free-text MUST scrub. The guardian device
-- CANNOT fix this client-side: by design it has no roster (only its own
-- children), so it doesn't know which names to remove. So the scrub happens
-- SERVER-SIDE, the same shape as `app.family_incidents_for_subject`.
--
-- TOGGLEABLE, but director-controlled + server-enforced: the program's
-- `spaces.capabilities->>'scrub_family_observations'` gates it (DEFAULT ON — a
-- missing/true cap scrubs). A guardian can never disable their own redaction;
-- only a director flipping the space capability can, and the decision is
-- enforced in Postgres, not on the reading device.
--
-- SECURITY DEFINER + explicit `caller_uid`: on ES256-keyed projects
-- `auth.uid()` is null inside the function (CLAUDE.md / migration
-- 20260523000003), so the Dart client passes `session.user.id`.

-- Replace every OTHER enrolled child's first/last name in `p_body` with
-- "a friend" (whole-word, case-insensitive) — the SQL twin of the Dart
-- `scrubOtherNames`. The subject's own name + all other words stay. Regex
-- metacharacters are stripped from each name first so a stray symbol can never
-- break the pattern (real names are alphabetic, so this is a no-op in practice).
create or replace function app.scrub_other_subject_names(
  p_body text,
  p_subject_id uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_space uuid;
  v_out text := p_body;
  v_name text;
  r record;
begin
  if p_body is null or p_body = '' then
    return p_body;
  end if;
  select space_id into v_space from public.subjects where id = p_subject_id;
  if v_space is null then
    return p_body;
  end if;
  for r in
    select nm from (
      select distinct trim(first_name) as nm
        from public.subjects
        where space_id = v_space and id <> p_subject_id
      union
      select distinct trim(last_name) as nm
        from public.subjects
        where space_id = v_space and id <> p_subject_id
    ) q
    where length(coalesce(nm, '')) >= 2
    order by length(nm) desc  -- longest first: "Sofia Martinez" before "Sofia"
  loop
    v_name := regexp_replace(r.nm, '[.^$*+?()\[\]{}|\\]', '', 'g');
    if length(v_name) >= 2 then
      v_out := regexp_replace(
        v_out,
        '\m' || v_name || '\M',
        'a friend',
        'gi'
      );
    end if;
  end loop;
  return v_out;
end;
$$;

create or replace function app.family_observations_for_subject(
  caller_uid uuid,
  p_subject_id uuid
)
returns table (
  id uuid,
  space_id uuid,
  group_id uuid,
  subject_id uuid,
  kind text,
  "text" text,
  photo_url text,
  details jsonb,
  recorded_by uuid,
  recorded_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = ''
as $$
  select
    e.id,
    e.space_id,
    e.group_id,
    e.subject_id,
    e.kind,
    case
      when coalesce(
             (sp.capabilities->>'scrub_family_observations')::boolean, true)
      then app.scrub_other_subject_names(e."text", e.subject_id)
      else e."text"
    end as "text",
    e.photo_url,
    e.details,
    e.recorded_by,
    e.recorded_at,
    e.updated_at
  from public.entries e
  join public.subjects s on s.id = e.subject_id
  join public.spaces sp on sp.id = s.space_id
  where e.subject_id = p_subject_id
    and e.kind = 'observation'
    -- caller must be a guardian linked to this child
    and exists (
      select 1
      from public.subject_guardians sg
      join public.guardians g on g.id = sg.guardian_id
      where sg.subject_id = e.subject_id
        and g.user_id = coalesce(caller_uid, auth.uid())
    )
  order by e.recorded_at desc
  limit 100;
$$;

grant execute on function app.scrub_other_subject_names(text, uuid)
  to authenticated;
grant execute on function app.family_observations_for_subject(uuid, uuid)
  to authenticated;

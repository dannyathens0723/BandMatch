-- Prevent a signed-in user from applying more than once to the same
-- recruitment post while preserving all historical application rows.
-- Submissions for one post are serialized by locking that post before the
-- existence check. Run after 040_stage_crew_management.sql.

begin;

create or replace function public.get_my_recruitment_application_state(
  p_post_id uuid
)
returns table (
  state text,
  application_id uuid
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
  v_group_id uuid;
  v_group_owner_id uuid;
  v_post_status text;
  v_application_id uuid;
  v_application_status text;
begin
  if v_user_id is null then
    return query select 'none'::text, null::uuid;
    return;
  end if;

  select post.group_id, crew.created_by, post.status
  into v_group_id, v_group_owner_id, v_post_status
  from public.recruitment_posts post
  join public.groups crew on crew.id = post.group_id
  where post.id = p_post_id
    and crew.account_status = 'active';

  if v_group_id is null then
    return query select 'closed'::text, null::uuid;
    return;
  end if;

  if public.is_group_admin(v_group_id) then
    return query select 'own_group'::text, null::uuid;
    return;
  end if;

  select application.id, application.status
  into v_application_id, v_application_status
  from public.recruitment_applications application
  where application.recruitment_post_id = p_post_id
    and application.applicant_user_id = v_user_id
  order by application.created_at desc, application.id desc
  limit 1;

  if v_application_id is not null then
    return query select v_application_status, v_application_id;
    return;
  end if;

  if v_post_status <> 'open' then
    return query select 'closed'::text, null::uuid;
    return;
  end if;

  if exists (
    select 1
    from public.group_members member
    where member.group_id = v_group_id
      and member.user_id = v_user_id
      and member.membership_status = 'active'
  ) then
    return query select 'group_member'::text, null::uuid;
    return;
  end if;

  if public.has_block_relationship(v_user_id, v_group_owner_id) then
    return query select 'blocked'::text, null::uuid;
    return;
  end if;

  return query select 'none'::text, null::uuid;
end;
$$;

create or replace function public.apply_to_recruitment_post(
  p_post_id uuid,
  p_message text default null
)
returns table (
  application_id uuid,
  status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
  v_group_id uuid;
  v_group_owner_id uuid;
  v_note text := nullif(btrim(coalesce(p_message, '')), '');
  v_application_id uuid;
begin
  if v_user_id is null then
    raise exception 'sign in is required';
  end if;

  if not exists (
    select 1
    from public.users profile
    where profile.id = v_user_id
      and profile.account_status = 'active'
  ) then
    raise exception 'active profile is required';
  end if;

  if v_note is not null and char_length(v_note) > 500 then
    raise exception 'application message must be 500 characters or fewer';
  end if;

  select post.group_id, crew.created_by
  into v_group_id, v_group_owner_id
  from public.recruitment_posts post
  join public.groups crew on crew.id = post.group_id
  where post.id = p_post_id
    and post.status = 'open'
    and crew.account_status = 'active'
  for update of post;

  if v_group_id is null then
    raise exception 'open recruitment post not found';
  end if;

  if public.is_group_admin(v_group_id) then
    raise exception 'group admins cannot apply to their own recruitment posts';
  end if;

  if exists (
    select 1
    from public.group_members member
    where member.group_id = v_group_id
      and member.user_id = v_user_id
      and member.membership_status = 'active'
  ) then
    raise exception 'active group members cannot apply to their own group';
  end if;

  if public.has_block_relationship(v_user_id, v_group_owner_id) then
    raise exception 'a block relationship prevents this application';
  end if;

  if exists (
    select 1
    from public.recruitment_applications application
    where application.recruitment_post_id = p_post_id
      and application.applicant_user_id = v_user_id
  ) then
    raise exception 'application already exists for this recruitment post'
      using errcode = '23505';
  end if;

  insert into public.recruitment_applications (
    recruitment_post_id,
    group_id,
    applicant_user_id,
    status,
    note
  )
  values (
    p_post_id,
    v_group_id,
    v_user_id,
    'pending',
    v_note
  )
  returning id into v_application_id;

  return query select v_application_id, 'pending'::text;
end;
$$;

create or replace function public.apply_to_stage_recruitment_post_v1(
  p_post_id uuid,
  p_message text default null
)
returns table (
  application_id uuid,
  status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform 1
  from public.recruitment_posts post
  join public.groups crew
    on crew.id = post.group_id
   and crew.account_status = 'active'
  where post.id = p_post_id
    and post.status = 'open'
    and exists (
      select 1
      from public.recruitment_post_genres link
      join public.genres genre
        on genre.id = link.genre_id
       and genre.domain = 'dance'
       and genre.is_active
      where link.post_id = post.id
    )
  for update of post;

  if not found then
    raise exception 'open Dance recruitment post not found';
  end if;

  return query
  select application.application_id, application.status
  from public.apply_to_recruitment_post(p_post_id, p_message) application;
end;
$$;

revoke all on function public.get_my_recruitment_application_state(uuid)
  from public, anon;
revoke all on function public.apply_to_recruitment_post(uuid, text)
  from public, anon;
revoke all on function public.apply_to_stage_recruitment_post_v1(uuid, text)
  from public, anon;
grant execute on function public.get_my_recruitment_application_state(uuid)
  to authenticated;
grant execute on function public.apply_to_recruitment_post(uuid, text)
  to authenticated;
grant execute on function public.apply_to_stage_recruitment_post_v1(uuid, text)
  to authenticated;

notify pgrst, 'reload schema';

commit;

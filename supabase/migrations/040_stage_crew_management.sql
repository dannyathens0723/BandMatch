-- Complete the authenticated STAGE Crew management loop.
-- Adds secure RPCs for Crew/recruitment administration and applicant review.
-- Existing tables, RLS policies, legacy BandMatch behavior, and migrations
-- 001-039 remain unchanged. Run after 039_stage_my_crew_overview.sql.

begin;

create or replace function public.require_stage_active_user_v1()
returns uuid
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
begin
  if v_user_id is null then
    raise exception 'sign in is required';
  end if;
  if not exists (
    select 1 from public.users profile
    where profile.id = v_user_id and profile.account_status = 'active'
  ) then
    raise exception 'active profile is required';
  end if;
  return v_user_id;
end;
$$;

create or replace function public.assert_stage_dance_genres_v1(p_genre_ids uuid[])
returns void
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_ids uuid[] := coalesce(p_genre_ids, '{}'::uuid[]);
begin
  if cardinality(v_ids) = 0
    or cardinality(v_ids) <> (
      select count(distinct selected.id)
      from unnest(v_ids) as selected(id)
    )
    or cardinality(v_ids) <> (
      select count(*) from public.genres genre
      where genre.id = any(v_ids)
        and genre.domain = 'dance'
        and genre.is_active
    ) then
    raise exception 'one or more active Dance genres are required';
  end if;
end;
$$;

create or replace function public.get_stage_crew_form_options_v1()
returns table (dance_genres jsonb, areas jsonb)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.require_stage_active_user_v1();
  return query select
    coalesce((
      select jsonb_agg(
        jsonb_build_object('id', genre.id, 'name', genre.name)
        order by genre.sort_order, genre.code
      )
      from public.genres genre
      where genre.domain = 'dance' and genre.is_active
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(
        jsonb_build_object('id', area.id, 'name', area.name)
        order by area.sort_order, area.name
      )
      from public.areas area
      where area.is_active
    ), '[]'::jsonb);
end;
$$;

create or replace function public.get_stage_managed_crew_v1(p_crew_id uuid)
returns table (
  crew_id uuid,
  name text,
  bio text,
  activity_frequency text,
  dance_genre_ids jsonb,
  dance_genre_names jsonb,
  area_id uuid,
  area_name text,
  active_member_count bigint
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.require_stage_active_user_v1();
  if p_crew_id is null or not public.is_group_admin(p_crew_id) then
    raise exception 'only active Crew admins can manage this Crew';
  end if;
  return query
  select
    crew.id,
    crew.name,
    crew.bio,
    crew.activity_frequency,
    coalesce((
      select jsonb_agg(genre.id order by genre.sort_order, genre.code)
      from public.group_genres link
      join public.genres genre on genre.id = link.genre_id
      where link.group_id = crew.id
        and genre.domain = 'dance' and genre.is_active
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(genre.name order by genre.sort_order, genre.code)
      from public.group_genres link
      join public.genres genre on genre.id = link.genre_id
      where link.group_id = crew.id
        and genre.domain = 'dance' and genre.is_active
    ), '[]'::jsonb),
    selected_area.area_id,
    selected_area.area_name,
    (
      select count(*) from public.group_members member
      where member.group_id = crew.id
        and member.membership_status = 'active'
    )
  from public.groups crew
  left join lateral (
    select area.id as area_id, area.name as area_name
    from public.group_areas link
    join public.areas area on area.id = link.area_id and area.is_active
    where link.group_id = crew.id
    order by link.is_primary desc, area.sort_order, area.name
    limit 1
  ) selected_area on true
  where crew.id = p_crew_id
    and crew.account_status = 'active'
    and exists (
      select 1 from public.group_genres crew_genre
      join public.genres genre on genre.id = crew_genre.genre_id
      where crew_genre.group_id = crew.id
        and genre.domain = 'dance' and genre.is_active
    );
end;
$$;

create or replace function public.get_stage_managed_recruitments_v1(p_crew_id uuid)
returns table (
  post_id uuid,
  crew_id uuid,
  title text,
  body text,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  dance_genre_ids jsonb,
  dance_genre_names jsonb,
  area_id uuid,
  area_name text,
  pending_application_count bigint
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.require_stage_active_user_v1();
  if p_crew_id is null or not public.is_group_admin(p_crew_id) then
    raise exception 'only active Crew admins can read recruitments';
  end if;
  return query
  select
    post.id,
    post.group_id,
    post.title,
    post.body,
    post.status,
    post.created_at,
    post.updated_at,
    coalesce((
      select jsonb_agg(genre.id order by genre.sort_order, genre.code)
      from public.recruitment_post_genres link
      join public.genres genre on genre.id = link.genre_id
      where link.post_id = post.id
        and genre.domain = 'dance' and genre.is_active
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(genre.name order by genre.sort_order, genre.code)
      from public.recruitment_post_genres link
      join public.genres genre on genre.id = link.genre_id
      where link.post_id = post.id
        and genre.domain = 'dance' and genre.is_active
    ), '[]'::jsonb),
    selected_area.area_id,
    selected_area.area_name,
    (
      select count(*) from public.recruitment_applications application
      where application.recruitment_post_id = post.id
        and application.status = 'pending'
    )
  from public.recruitment_posts post
  join public.groups crew
    on crew.id = post.group_id and crew.account_status = 'active'
  left join lateral (
    select area.id as area_id, area.name as area_name
    from public.recruitment_post_areas link
    join public.areas area on area.id = link.area_id and area.is_active
    where link.post_id = post.id
    order by area.sort_order, area.name
    limit 1
  ) selected_area on true
  where post.group_id = p_crew_id
    and exists (
      select 1 from public.recruitment_post_genres link
      join public.genres genre on genre.id = link.genre_id
      where link.post_id = post.id
        and genre.domain = 'dance' and genre.is_active
    )
  order by post.updated_at desc, post.id;
end;
$$;

create or replace function public.create_stage_crew_v1(
  p_name text,
  p_bio text,
  p_activity_frequency text,
  p_genre_ids uuid[],
  p_area_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.require_stage_active_user_v1();
  v_name text := btrim(coalesce(p_name, ''));
  v_bio text := nullif(btrim(coalesce(p_bio, '')), '');
  v_crew_id uuid;
begin
  if char_length(v_name) not between 1 and 60 then
    raise exception 'Crew name must be between 1 and 60 characters';
  end if;
  if v_bio is not null and char_length(v_bio) > 1000 then
    raise exception 'Crew introduction must be 1000 characters or fewer';
  end if;
  if p_activity_frequency is not null and p_activity_frequency
    not in ('monthly_1_2', 'weekly_1_2', 'daily') then
    raise exception 'invalid activity frequency';
  end if;
  perform public.assert_stage_dance_genres_v1(p_genre_ids);
  if p_area_id is not null and not exists (
    select 1 from public.areas area
    where area.id = p_area_id and area.is_active
  ) then
    raise exception 'active area is required';
  end if;

  insert into public.groups (
    created_by, name, bio, account_status, activity_frequency, is_recruiting
  ) values (
    v_user_id, v_name, v_bio, 'active', p_activity_frequency, false
  ) returning id into v_crew_id;

  insert into public.group_members (
    user_id, group_id, role, membership_status, left_at, removed_by
  ) values (v_user_id, v_crew_id, 'admin', 'active', null, null);

  insert into public.group_genres (group_id, genre_id)
  select v_crew_id, selected.id from unnest(p_genre_ids) selected(id);

  if p_area_id is not null then
    insert into public.group_areas (group_id, area_id, show_on_profile, is_primary)
    values (v_crew_id, p_area_id, true, true);
  end if;
  return v_crew_id;
end;
$$;

create or replace function public.update_stage_crew_v1(
  p_crew_id uuid,
  p_name text,
  p_bio text,
  p_activity_frequency text,
  p_genre_ids uuid[],
  p_area_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_bio text := nullif(btrim(coalesce(p_bio, '')), '');
begin
  perform public.require_stage_active_user_v1();
  if p_crew_id is null or not public.is_group_admin(p_crew_id)
    or not exists (
      select 1 from public.groups crew
      where crew.id = p_crew_id and crew.account_status = 'active'
        and exists (
          select 1 from public.group_genres crew_genre
          join public.genres genre on genre.id = crew_genre.genre_id
          where crew_genre.group_id = crew.id
            and genre.domain = 'dance' and genre.is_active
        )
    ) then
    raise exception 'only active Crew admins can update this Crew';
  end if;
  if char_length(v_name) not between 1 and 60 then
    raise exception 'Crew name must be between 1 and 60 characters';
  end if;
  if v_bio is not null and char_length(v_bio) > 1000 then
    raise exception 'Crew introduction must be 1000 characters or fewer';
  end if;
  if p_activity_frequency is not null and p_activity_frequency
    not in ('monthly_1_2', 'weekly_1_2', 'daily') then
    raise exception 'invalid activity frequency';
  end if;
  perform public.assert_stage_dance_genres_v1(p_genre_ids);
  if p_area_id is not null and not exists (
    select 1 from public.areas area
    where area.id = p_area_id and area.is_active
  ) then
    raise exception 'active area is required';
  end if;

  update public.groups set
    name = v_name,
    bio = v_bio,
    activity_frequency = p_activity_frequency
  where id = p_crew_id;

  delete from public.group_genres link
  using public.genres genre
  where link.group_id = p_crew_id
    and genre.id = link.genre_id and genre.domain = 'dance';
  insert into public.group_genres (group_id, genre_id)
  select p_crew_id, selected.id from unnest(p_genre_ids) selected(id);

  delete from public.group_areas where group_id = p_crew_id;
  if p_area_id is not null then
    insert into public.group_areas (group_id, area_id, show_on_profile, is_primary)
    values (p_crew_id, p_area_id, true, true);
  end if;
  return p_crew_id;
end;
$$;

create or replace function public.create_stage_recruitment_v1(
  p_crew_id uuid,
  p_title text,
  p_body text,
  p_genre_ids uuid[],
  p_area_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_title text := btrim(coalesce(p_title, ''));
  v_body text := btrim(coalesce(p_body, ''));
  v_post_id uuid;
begin
  perform public.require_stage_active_user_v1();
  if p_crew_id is null or not public.is_group_admin(p_crew_id)
    or not exists (
      select 1 from public.groups crew
      where crew.id = p_crew_id and crew.account_status = 'active'
        and exists (
          select 1 from public.group_genres crew_genre
          join public.genres genre on genre.id = crew_genre.genre_id
          where crew_genre.group_id = crew.id
            and genre.domain = 'dance' and genre.is_active
        )
    ) then
    raise exception 'only active Crew admins can publish recruitments';
  end if;
  if char_length(v_title) not between 1 and 80 then
    raise exception 'recruitment title must be between 1 and 80 characters';
  end if;
  if char_length(v_body) not between 1 and 2000 then
    raise exception 'recruitment body must be between 1 and 2000 characters';
  end if;
  perform public.assert_stage_dance_genres_v1(p_genre_ids);
  if p_area_id is not null and not exists (
    select 1 from public.areas area
    where area.id = p_area_id and area.is_active
  ) then
    raise exception 'active area is required';
  end if;

  insert into public.recruitment_posts (group_id, title, body, status)
  values (p_crew_id, v_title, v_body, 'open')
  returning id into v_post_id;
  insert into public.recruitment_post_genres (post_id, genre_id)
  select v_post_id, selected.id from unnest(p_genre_ids) selected(id);
  if p_area_id is not null then
    insert into public.recruitment_post_areas (post_id, area_id)
    values (v_post_id, p_area_id);
  end if;
  return v_post_id;
end;
$$;

create or replace function public.update_stage_recruitment_v1(
  p_post_id uuid,
  p_title text,
  p_body text,
  p_genre_ids uuid[],
  p_area_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_crew_id uuid;
  v_title text := btrim(coalesce(p_title, ''));
  v_body text := btrim(coalesce(p_body, ''));
begin
  perform public.require_stage_active_user_v1();
  select post.group_id into v_crew_id
  from public.recruitment_posts post
  join public.groups crew
    on crew.id = post.group_id and crew.account_status = 'active'
  where post.id = p_post_id
    and exists (
      select 1 from public.recruitment_post_genres post_genre
      join public.genres genre on genre.id = post_genre.genre_id
      where post_genre.post_id = post.id
        and genre.domain = 'dance' and genre.is_active
    );
  if v_crew_id is null or not public.is_group_admin(v_crew_id) then
    raise exception 'only the Crew admin can update this recruitment';
  end if;
  if char_length(v_title) not between 1 and 80 then
    raise exception 'recruitment title must be between 1 and 80 characters';
  end if;
  if char_length(v_body) not between 1 and 2000 then
    raise exception 'recruitment body must be between 1 and 2000 characters';
  end if;
  perform public.assert_stage_dance_genres_v1(p_genre_ids);
  if p_area_id is not null and not exists (
    select 1 from public.areas area
    where area.id = p_area_id and area.is_active
  ) then
    raise exception 'active area is required';
  end if;

  update public.recruitment_posts set title = v_title, body = v_body
  where id = p_post_id;
  delete from public.recruitment_post_genres link
  using public.genres genre
  where link.post_id = p_post_id
    and genre.id = link.genre_id and genre.domain = 'dance';
  insert into public.recruitment_post_genres (post_id, genre_id)
  select p_post_id, selected.id from unnest(p_genre_ids) selected(id);
  delete from public.recruitment_post_areas where post_id = p_post_id;
  if p_area_id is not null then
    insert into public.recruitment_post_areas (post_id, area_id)
    values (p_post_id, p_area_id);
  end if;
  return p_post_id;
end;
$$;

create or replace function public.set_stage_recruitment_status_v1(
  p_post_id uuid,
  p_status text
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_crew_id uuid;
begin
  perform public.require_stage_active_user_v1();
  if p_status not in ('open', 'closed') then
    raise exception 'recruitment status must be open or closed';
  end if;
  select post.group_id into v_crew_id
  from public.recruitment_posts post
  join public.groups crew
    on crew.id = post.group_id and crew.account_status = 'active'
  where post.id = p_post_id
    and exists (
      select 1 from public.recruitment_post_genres post_genre
      join public.genres genre on genre.id = post_genre.genre_id
      where post_genre.post_id = post.id
        and genre.domain = 'dance' and genre.is_active
    );
  if v_crew_id is null or not public.is_group_admin(v_crew_id) then
    raise exception 'only the Crew admin can change recruitment status';
  end if;
  if not exists (
    select 1 from public.recruitment_post_genres link
    join public.genres genre on genre.id = link.genre_id
    where link.post_id = p_post_id
      and genre.domain = 'dance' and genre.is_active
  ) then
    raise exception 'an active Dance genre is required';
  end if;
  update public.recruitment_posts set status = p_status where id = p_post_id;
  return p_status;
end;
$$;

create or replace function public.get_stage_recruitment_applicants_v1(
  p_post_id uuid
)
returns table (
  application_id uuid,
  post_id uuid,
  crew_id uuid,
  applicant_user_id uuid,
  display_name text,
  avatar_url text,
  experience_level text,
  dance_genre_names jsonb,
  performance_role_names jsonb,
  primary_performance_role_name text,
  application_note text,
  application_status text,
  applied_at timestamptz,
  responded_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_crew_id uuid;
begin
  perform public.require_stage_active_user_v1();
  select post.group_id into v_crew_id
  from public.recruitment_posts post
  join public.groups crew
    on crew.id = post.group_id and crew.account_status = 'active'
  where post.id = p_post_id
    and exists (
      select 1 from public.recruitment_post_genres post_genre
      join public.genres genre on genre.id = post_genre.genre_id
      where post_genre.post_id = post.id
        and genre.domain = 'dance' and genre.is_active
    );
  if v_crew_id is null or not public.is_group_admin(v_crew_id) then
    raise exception 'only the Crew admin can review applicants';
  end if;
  return query
  select
    application.id,
    application.recruitment_post_id,
    application.group_id,
    applicant.id,
    applicant.display_name,
    applicant.avatar_url,
    applicant.experience_level,
    coalesce((
      select jsonb_agg(genre.name order by genre.sort_order, genre.code)
      from public.user_genres user_genre
      join public.genres genre on genre.id = user_genre.genre_id
      where user_genre.user_id = applicant.id
        and genre.domain = 'dance' and genre.is_active
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(role.name order by role.sort_order, role.code)
      from public.user_performance_roles user_role
      join public.performance_roles role
        on role.id = user_role.performance_role_id
      where user_role.user_id = applicant.id
        and role.domain = 'dance' and role.is_active
    ), '[]'::jsonb),
    (
      select role.name
      from public.user_performance_roles user_role
      join public.performance_roles role
        on role.id = user_role.performance_role_id
      where user_role.user_id = applicant.id
        and user_role.is_primary
        and role.domain = 'dance' and role.is_active
      limit 1
    ),
    application.note,
    application.status,
    application.created_at,
    application.responded_at
  from public.recruitment_applications application
  join public.users applicant
    on applicant.id = application.applicant_user_id
   and applicant.account_status = 'active'
  where application.recruitment_post_id = p_post_id
    and application.group_id = v_crew_id
  order by
    case application.status
      when 'pending' then 0 when 'accepted' then 1 when 'rejected' then 2 else 3
    end,
    application.created_at desc,
    application.id;
end;
$$;

create or replace function public.decide_stage_recruitment_application_v1(
  p_application_id uuid,
  p_decision text
)
returns table (
  application_id uuid,
  application_status text,
  membership_status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_id uuid := public.require_stage_active_user_v1();
  v_application public.recruitment_applications%rowtype;
  v_crew_owner_id uuid;
  v_existing_membership_status text;
begin
  if p_decision not in ('accepted', 'rejected') then
    raise exception 'decision must be accepted or rejected';
  end if;
  select application.* into v_application
  from public.recruitment_applications application
  join public.recruitment_posts post
    on post.id = application.recruitment_post_id
   and post.group_id = application.group_id
   and post.status in ('open', 'closed')
  join public.groups crew
    on crew.id = application.group_id and crew.account_status = 'active'
  where application.id = p_application_id
    and exists (
      select 1 from public.recruitment_post_genres link
      join public.genres genre on genre.id = link.genre_id
      where link.post_id = post.id
        and genre.domain = 'dance' and genre.is_active
    )
  for update of application;
  if not found then
    raise exception 'valid recruitment application not found';
  end if;
  select crew.created_by into v_crew_owner_id
  from public.groups crew
  join public.recruitment_posts post
    on post.group_id = crew.id
  where crew.id = v_application.group_id
    and crew.account_status = 'active'
    and post.id = v_application.recruitment_post_id
    and post.group_id = v_application.group_id;
  if v_crew_owner_id is null then
    raise exception 'authoritative active Crew owner not found';
  end if;
  if not public.is_group_admin(v_application.group_id) then
    raise exception 'only the Crew admin can process this application';
  end if;
  if v_application.status <> 'pending' then
    raise exception 'application has already been processed';
  end if;
  if not exists (
    select 1 from public.users profile
    where profile.id = v_application.applicant_user_id
      and profile.account_status = 'active'
  ) then
    raise exception 'active applicant profile is required';
  end if;

  if p_decision = 'accepted' then
    if public.has_block_relationship(
      v_application.applicant_user_id,
      v_actor_id
    ) or public.has_block_relationship(
      v_application.applicant_user_id,
      v_crew_owner_id
    ) then
      raise exception 'blocked users cannot be added to a Crew';
    end if;
    insert into public.group_members as existing_member (
      user_id, group_id, role, membership_status, joined_at, left_at, removed_by
    ) values (
      v_application.applicant_user_id,
      v_application.group_id,
      'member',
      'active',
      now(),
      null,
      null
    )
    on conflict (user_id, group_id) do update set
      role = case
        when existing_member.role = 'admin' then 'admin' else 'member'
      end,
      membership_status = 'active',
      joined_at = case
        when existing_member.membership_status = 'active'
          then existing_member.joined_at
        else now()
      end,
      left_at = null,
      removed_by = null;
    v_existing_membership_status := 'active';
  else
    select member.membership_status into v_existing_membership_status
    from public.group_members member
    where member.group_id = v_application.group_id
      and member.user_id = v_application.applicant_user_id;
  end if;

  update public.recruitment_applications set
    status = p_decision,
    responded_at = now(),
    responded_by = v_actor_id
  where id = v_application.id;

  return query select
    v_application.id,
    p_decision,
    v_existing_membership_status;
end;
$$;

revoke all on function public.require_stage_active_user_v1()
  from public, anon, authenticated;
revoke all on function public.assert_stage_dance_genres_v1(uuid[])
  from public, anon, authenticated;
revoke all on function public.get_stage_crew_form_options_v1()
  from public, anon;
revoke all on function public.get_stage_managed_crew_v1(uuid)
  from public, anon;
revoke all on function public.get_stage_managed_recruitments_v1(uuid)
  from public, anon;
revoke all on function public.create_stage_crew_v1(text, text, text, uuid[], uuid)
  from public, anon;
revoke all on function public.update_stage_crew_v1(uuid, text, text, text, uuid[], uuid)
  from public, anon;
revoke all on function public.create_stage_recruitment_v1(uuid, text, text, uuid[], uuid)
  from public, anon;
revoke all on function public.update_stage_recruitment_v1(uuid, text, text, uuid[], uuid)
  from public, anon;
revoke all on function public.set_stage_recruitment_status_v1(uuid, text)
  from public, anon;
revoke all on function public.get_stage_recruitment_applicants_v1(uuid)
  from public, anon;
revoke all on function public.decide_stage_recruitment_application_v1(uuid, text)
  from public, anon;

grant execute on function public.get_stage_crew_form_options_v1()
  to authenticated;
grant execute on function public.get_stage_managed_crew_v1(uuid)
  to authenticated;
grant execute on function public.get_stage_managed_recruitments_v1(uuid)
  to authenticated;
grant execute on function public.create_stage_crew_v1(text, text, text, uuid[], uuid)
  to authenticated;
grant execute on function public.update_stage_crew_v1(uuid, text, text, text, uuid[], uuid)
  to authenticated;
grant execute on function public.create_stage_recruitment_v1(uuid, text, text, uuid[], uuid)
  to authenticated;
grant execute on function public.update_stage_recruitment_v1(uuid, text, text, uuid[], uuid)
  to authenticated;
grant execute on function public.set_stage_recruitment_status_v1(uuid, text)
  to authenticated;
grant execute on function public.get_stage_recruitment_applicants_v1(uuid)
  to authenticated;
grant execute on function public.decide_stage_recruitment_application_v1(uuid, text)
  to authenticated;

notify pgrst, 'reload schema';

commit;

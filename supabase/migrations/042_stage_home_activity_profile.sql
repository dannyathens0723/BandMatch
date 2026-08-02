-- Caller-scoped STAGE profile summary/edit and derived activity feed.
-- This migration adds no tables, persistent notification/read state, or
-- direct client table privileges. Run after 041.

begin;

create or replace function public.get_stage_my_profile_v1()
returns table (
  user_id uuid,
  display_name text,
  avatar_url text,
  bio text,
  experience_level text,
  activity_frequency text,
  area_id uuid,
  area_name text,
  dance_genre_names jsonb,
  performance_role_names jsonb,
  primary_performance_role_name text,
  has_saved_taxonomy boolean,
  profile_completeness integer
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.require_stage_active_user_v1();
begin
  return query
  select
    profile.id,
    profile.display_name,
    profile.avatar_url,
    profile.bio,
    profile.experience_level,
    profile.activity_frequency,
    primary_area.area_id,
    primary_area.area_name,
    taxonomy.dance_genre_names,
    taxonomy.performance_role_names,
    taxonomy.primary_performance_role_name,
    taxonomy.has_saved_taxonomy,
    (
      (case when btrim(profile.display_name) <> '' then 20 else 0 end) +
      (case when nullif(btrim(coalesce(profile.bio, '')), '') is not null then 15 else 0 end) +
      (case when profile.experience_level is not null then 10 else 0 end) +
      (case when profile.activity_frequency is not null then 10 else 0 end) +
      (case when primary_area.area_id is not null then 15 else 0 end) +
      (case when taxonomy.has_saved_taxonomy then 30 else 0 end)
    )::integer
  from public.users profile
  left join lateral (
    select
      user_area.area_id,
      area.name as area_name
    from public.user_areas user_area
    join public.areas area
      on area.id = user_area.area_id
     and area.is_active
     and area.level in ('prefecture', 'city')
    where user_area.user_id = profile.id
      and user_area.show_on_profile
    order by user_area.is_primary desc, area.sort_order, area.name
    limit 1
  ) primary_area on true
  cross join lateral (
    select
      coalesce((
        select jsonb_agg(genre.name order by genre.sort_order, genre.code)
        from public.user_genres user_genre
        join public.genres genre
          on genre.id = user_genre.genre_id
         and genre.domain = 'dance'
         and genre.is_active
        where user_genre.user_id = profile.id
      ), '[]'::jsonb) as dance_genre_names,
      coalesce((
        select jsonb_agg(role.name order by role.sort_order, role.code)
        from public.user_performance_roles user_role
        join public.performance_roles role
          on role.id = user_role.performance_role_id
         and role.domain = 'dance'
         and role.is_active
        where user_role.user_id = profile.id
      ), '[]'::jsonb) as performance_role_names,
      (
        select role.name
        from public.user_performance_roles user_role
        join public.performance_roles role
          on role.id = user_role.performance_role_id
         and role.domain = 'dance'
         and role.is_active
        where user_role.user_id = profile.id
          and user_role.is_primary
        limit 1
      ) as primary_performance_role_name,
      coalesce(
        (
          profile.performance_domain in ('dance', 'multi_domain')
          and exists (
            select 1
            from public.user_genres user_genre
            join public.genres genre
              on genre.id = user_genre.genre_id
             and genre.domain = 'dance'
             and genre.is_active
            where user_genre.user_id = profile.id
          )
          and exists (
            select 1
            from public.user_performance_roles user_role
            join public.performance_roles role
              on role.id = user_role.performance_role_id
             and role.domain = 'dance'
             and role.is_active
            where user_role.user_id = profile.id
              and user_role.is_primary
          )
        ),
        false
      ) as has_saved_taxonomy
  ) taxonomy
  where profile.id = v_user_id
    and profile.account_status = 'active';
end;
$$;

create or replace function public.update_stage_my_profile_v1(
  p_display_name text,
  p_bio text,
  p_experience_level text,
  p_activity_frequency text,
  p_area_id uuid default null
)
returns table (
  user_id uuid,
  display_name text,
  avatar_url text,
  bio text,
  experience_level text,
  activity_frequency text,
  area_id uuid,
  area_name text,
  dance_genre_names jsonb,
  performance_role_names jsonb,
  primary_performance_role_name text,
  has_saved_taxonomy boolean,
  profile_completeness integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.require_stage_active_user_v1();
  v_display_name text := btrim(coalesce(p_display_name, ''));
  v_bio text := nullif(btrim(coalesce(p_bio, '')), '');
begin
  if char_length(v_display_name) not between 1 and 30 then
    raise exception 'display name must be between 1 and 30 characters'
      using errcode = '22023';
  end if;
  if v_bio is not null and char_length(v_bio) > 1000 then
    raise exception 'profile introduction must be 1000 characters or fewer'
      using errcode = '22023';
  end if;
  if p_experience_level is not null and p_experience_level not in (
    'beginner_new', 'beginner', 'experienced', 'pro_oriented'
  ) then
    raise exception 'invalid experience level' using errcode = '22023';
  end if;
  if p_activity_frequency is not null and p_activity_frequency not in (
    'monthly_1_2', 'weekly_1_2', 'daily'
  ) then
    raise exception 'invalid activity frequency' using errcode = '22023';
  end if;
  if p_area_id is not null and not exists (
    select 1
    from public.areas area
    where area.id = p_area_id
      and area.is_active
      and area.level in ('prefecture', 'city')
  ) then
    raise exception 'active public activity area not found'
      using errcode = '22023';
  end if;

  update public.users profile
  set
    display_name = v_display_name,
    bio = v_bio,
    experience_level = p_experience_level,
    activity_frequency = p_activity_frequency
  where profile.id = v_user_id
    and profile.account_status = 'active';

  if not found then
    raise exception 'active profile is required' using errcode = '55000';
  end if;

  if p_area_id is not null then
    update public.user_areas user_area
    set is_primary = false
    where user_area.user_id = v_user_id
      and user_area.is_primary;

    insert into public.user_areas (
      user_id, area_id, show_on_profile, is_primary
    ) values (
      v_user_id, p_area_id, true, true
    )
    on conflict (user_id, area_id) do update
    set
      show_on_profile = true,
      is_primary = true;
  end if;

  return query select * from public.get_stage_my_profile_v1();
end;
$$;

create or replace function public.get_stage_activity_feed_v1()
returns table (
  activity_key text,
  activity_type text,
  activity_status text,
  occurred_at timestamptz,
  crew_id uuid,
  crew_name text,
  post_id uuid,
  post_title text,
  application_id uuid,
  actor_display_name text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.require_stage_active_user_v1();
begin
  return query
  with latest_own_application as (
    select distinct on (application.recruitment_post_id)
      application.id,
      application.recruitment_post_id,
      application.group_id,
      application.status,
      application.created_at,
      application.responded_at
    from public.recruitment_applications application
    where application.applicant_user_id = v_user_id
    order by
      application.recruitment_post_id,
      application.created_at desc,
      application.id desc
  ),
  latest_managed_application as (
    select distinct on (
      application.recruitment_post_id,
      application.applicant_user_id
    )
      application.id,
      application.recruitment_post_id,
      application.group_id,
      application.applicant_user_id,
      application.status,
      application.created_at,
      application.responded_at
    from public.recruitment_applications application
    join public.group_members manager
      on manager.group_id = application.group_id
     and manager.user_id = v_user_id
     and manager.role = 'admin'
     and manager.membership_status = 'active'
    order by
      application.recruitment_post_id,
      application.applicant_user_id,
      application.created_at desc,
      application.id desc
  ),
  activity as (
    select
      'own_application:' || application.id::text as activity_key,
      'own_application'::text as activity_type,
      application.status as activity_status,
      coalesce(application.responded_at, application.created_at) as occurred_at,
      crew.id as crew_id,
      crew.name as crew_name,
      post.id as post_id,
      post.title as post_title,
      application.id as application_id,
      null::text as actor_display_name
    from latest_own_application application
    join public.recruitment_posts post
      on post.id = application.recruitment_post_id
     and post.group_id = application.group_id
    join public.groups crew
      on crew.id = application.group_id
     and crew.account_status = 'active'
    where exists (
      select 1
      from public.recruitment_post_genres post_genre
      join public.genres genre
        on genre.id = post_genre.genre_id
       and genre.domain = 'dance'
       and genre.is_active
      where post_genre.post_id = post.id
    )

    union all

    select
      'managed_application:' || application.id::text,
      'managed_application'::text,
      application.status,
      coalesce(application.responded_at, application.created_at),
      crew.id,
      crew.name,
      post.id,
      post.title,
      application.id,
      applicant.display_name
    from latest_managed_application application
    join public.recruitment_posts post
      on post.id = application.recruitment_post_id
     and post.group_id = application.group_id
    join public.groups crew
      on crew.id = application.group_id
     and crew.account_status = 'active'
    join public.users applicant
      on applicant.id = application.applicant_user_id
     and applicant.account_status = 'active'
    where exists (
      select 1
      from public.recruitment_post_genres post_genre
      join public.genres genre
        on genre.id = post_genre.genre_id
       and genre.domain = 'dance'
       and genre.is_active
      where post_genre.post_id = post.id
    )

    union all

    select
      'crew_membership:' || member.id::text,
      'crew_membership'::text,
      member.membership_status,
      member.joined_at,
      crew.id,
      crew.name,
      null::uuid,
      null::text,
      null::uuid,
      null::text
    from public.group_members member
    join public.groups crew
      on crew.id = member.group_id
     and crew.account_status = 'active'
    where member.user_id = v_user_id
      and member.membership_status = 'active'
      and exists (
        select 1
        from public.group_genres crew_genre
        join public.genres genre
          on genre.id = crew_genre.genre_id
         and genre.domain = 'dance'
         and genre.is_active
        where crew_genre.group_id = crew.id
      )
  )
  select
    activity.activity_key,
    activity.activity_type,
    activity.activity_status,
    activity.occurred_at,
    activity.crew_id,
    activity.crew_name,
    activity.post_id,
    activity.post_title,
    activity.application_id,
    activity.actor_display_name
  from activity
  order by activity.occurred_at desc, activity.activity_key
  limit 80;
end;
$$;

revoke all on function public.get_stage_my_profile_v1()
  from public, anon;
revoke all on function public.update_stage_my_profile_v1(
  text, text, text, text, uuid
) from public, anon;
revoke all on function public.get_stage_activity_feed_v1()
  from public, anon;

grant execute on function public.get_stage_my_profile_v1()
  to authenticated;
grant execute on function public.update_stage_my_profile_v1(
  text, text, text, text, uuid
) to authenticated;
grant execute on function public.get_stage_activity_feed_v1()
  to authenticated;

notify pgrst, 'reload schema';

commit;

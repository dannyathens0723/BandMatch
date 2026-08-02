-- Safe STAGE My Crew overview for the authenticated user.
-- Returns only the caller's active memberships and own recruitment
-- applications. No management, role changes, or private application notes are
-- exposed. Run after 038_stage_studio_discovery.sql.

begin;

create or replace function public.get_stage_my_crews_v1()
returns table (
  crew_id uuid,
  crew_name text,
  crew_avatar_url text,
  crew_bio text,
  membership_role text,
  is_creator boolean,
  joined_at timestamptz,
  active_member_count bigint,
  open_recruitment_count bigint,
  dance_genre_names jsonb,
  area_names jsonb
)
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
    select 1
    from public.users profile
    where profile.id = v_user_id
      and profile.account_status = 'active'
  ) then
    raise exception 'active profile is required';
  end if;

  return query
  select
    crew.id as crew_id,
    crew.name as crew_name,
    crew.avatar_url as crew_avatar_url,
    crew.bio as crew_bio,
    membership.role as membership_role,
    crew.created_by = v_user_id as is_creator,
    membership.joined_at,
    (
      select count(*)
      from public.group_members counted_member
      where counted_member.group_id = crew.id
        and counted_member.membership_status = 'active'
        and counted_member.role in ('admin', 'member')
    ) as active_member_count,
    (
      select count(*)
      from public.recruitment_posts post
      where post.group_id = crew.id
        and post.status = 'open'
        and exists (
          select 1
          from public.recruitment_post_genres post_genre
          join public.genres genre
            on genre.id = post_genre.genre_id
           and genre.domain = 'dance'
           and genre.is_active
          where post_genre.post_id = post.id
        )
    ) as open_recruitment_count,
    coalesce((
      select jsonb_agg(genre.name order by genre.sort_order, genre.code)
      from public.group_genres crew_genre
      join public.genres genre
        on genre.id = crew_genre.genre_id
       and genre.domain = 'dance'
       and genre.is_active
      where crew_genre.group_id = crew.id
    ), '[]'::jsonb) as dance_genre_names,
    coalesce((
      select jsonb_agg(area.name order by area.sort_order, area.name)
      from public.group_areas crew_area
      join public.areas area
        on area.id = crew_area.area_id
       and area.is_active
      where crew_area.group_id = crew.id
    ), '[]'::jsonb) as area_names
  from public.group_members membership
  join public.groups crew on crew.id = membership.group_id
  where membership.user_id = v_user_id
    and membership.membership_status = 'active'
    and membership.role in ('admin', 'member')
    and crew.account_status = 'active'
    and exists (
      select 1
      from public.group_genres crew_genre
      join public.genres genre
        on genre.id = crew_genre.genre_id
       and genre.domain = 'dance'
       and genre.is_active
      where crew_genre.group_id = crew.id
    )
  order by
    case membership.role when 'admin' then 0 else 1 end,
    crew.updated_at desc,
    crew.id;
end;
$$;

create or replace function public.get_stage_my_crew_applications_v1()
returns table (
  application_id uuid,
  post_id uuid,
  crew_id uuid,
  crew_name text,
  crew_avatar_url text,
  title text,
  body text,
  application_status text,
  applied_at timestamptz,
  responded_at timestamptz,
  post_status text,
  dance_genre_names jsonb,
  area_names jsonb
)
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
    select 1
    from public.users profile
    where profile.id = v_user_id
      and profile.account_status = 'active'
  ) then
    raise exception 'active profile is required';
  end if;

  return query
  with latest_applications as (
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
  )
  select
    application.id as application_id,
    post.id as post_id,
    crew.id as crew_id,
    crew.name as crew_name,
    crew.avatar_url as crew_avatar_url,
    post.title,
    post.body,
    application.status as application_status,
    application.created_at as applied_at,
    application.responded_at,
    post.status as post_status,
    coalesce((
      select jsonb_agg(genre.name order by genre.sort_order, genre.code)
      from public.recruitment_post_genres post_genre
      join public.genres genre
        on genre.id = post_genre.genre_id
       and genre.domain = 'dance'
       and genre.is_active
      where post_genre.post_id = post.id
    ), '[]'::jsonb) as dance_genre_names,
    coalesce((
      select jsonb_agg(area.name order by area.sort_order, area.name)
      from public.recruitment_post_areas post_area
      join public.areas area
        on area.id = post_area.area_id
       and area.is_active
      where post_area.post_id = post.id
    ), '[]'::jsonb) as area_names
  from latest_applications application
  join public.recruitment_posts post
    on post.id = application.recruitment_post_id
  join public.groups crew
    on crew.id = application.group_id
   and crew.id = post.group_id
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
  order by
    case application.status
      when 'pending' then 0
      when 'accepted' then 1
      when 'rejected' then 2
      else 3
    end,
    application.created_at desc,
    application.id
  limit 80;
end;
$$;

revoke all on function public.get_stage_my_crews_v1()
  from public, anon;
revoke all on function public.get_stage_my_crew_applications_v1()
  from public, anon;
grant execute on function public.get_stage_my_crews_v1()
  to authenticated;
grant execute on function public.get_stage_my_crew_applications_v1()
  to authenticated;

notify pgrst, 'reload schema';

commit;

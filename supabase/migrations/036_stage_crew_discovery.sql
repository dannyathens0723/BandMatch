-- Safe, read-only STAGE Crew recruitment discovery.
-- The existing groups table remains the technical Crew container, as approved
-- by the STAGE product specification. Only open posts explicitly connected to
-- active Dance genres are returned; legacy Band parts are never projected.
-- Run after 035_stage_taxonomy_persistence.sql.

begin;

create or replace function public.get_stage_crew_recruitments_v1()
returns table (
  post_id uuid,
  crew_id uuid,
  crew_name text,
  crew_avatar_url text,
  title text,
  body text,
  created_at timestamptz,
  updated_at timestamptz,
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
    post.id as post_id,
    crew.id as crew_id,
    crew.name as crew_name,
    crew.avatar_url as crew_avatar_url,
    post.title,
    post.body,
    post.created_at,
    post.updated_at,
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
  from public.recruitment_posts post
  join public.groups crew on crew.id = post.group_id
  where post.status = 'open'
    and crew.account_status = 'active'
    and not public.has_block_relationship(v_user_id, crew.created_by)
    and exists (
      select 1
      from public.recruitment_post_genres post_genre
      join public.genres genre
        on genre.id = post_genre.genre_id
      where post_genre.post_id = post.id
        and genre.domain = 'dance'
        and genre.is_active
    )
  order by post.updated_at desc, post.created_at desc, post.id
  limit 80;
end;
$$;

revoke all on function public.get_stage_crew_recruitments_v1()
  from public, anon;
grant execute on function public.get_stage_crew_recruitments_v1()
  to authenticated;

notify pgrst, 'reload schema';

commit;

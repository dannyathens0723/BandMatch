-- Safe public read-only recruitment-post projection.
-- This exposes only open posts for active groups and does not add application
-- flow, group approval, group chat, notifications, realtime, or read receipts.
-- Run after 021_recruitment_post_foundation.sql.

begin;

create or replace function public.get_public_recruitment_posts()
returns table (
  post_id uuid,
  group_id uuid,
  group_name text,
  title text,
  body text,
  created_at timestamptz,
  updated_at timestamptz,
  wanted_part_names jsonb,
  genre_names jsonb,
  area_names jsonb
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  return query
  select
    post.id as post_id,
    post.group_id,
    g.name as group_name,
    post.title,
    post.body,
    post.created_at,
    post.updated_at,
    coalesce((
      select jsonb_agg(part.name order by part.sort_order)
      from public.recruitment_post_parts rpp
      join public.parts part on part.id = rpp.part_id and part.is_active
      where rpp.post_id = post.id
    ), '[]'::jsonb) as wanted_part_names,
    coalesce((
      select jsonb_agg(genre.name order by genre.sort_order)
      from public.recruitment_post_genres rpg
      join public.genres genre on genre.id = rpg.genre_id and genre.is_active
      where rpg.post_id = post.id
    ), '[]'::jsonb) as genre_names,
    coalesce((
      select jsonb_agg(area.name order by area.sort_order, area.name)
      from public.recruitment_post_areas rpa
      join public.areas area on area.id = rpa.area_id and area.is_active
      where rpa.post_id = post.id
    ), '[]'::jsonb) as area_names
  from public.recruitment_posts post
  join public.groups g on g.id = post.group_id
  where post.status = 'open'
    and g.account_status = 'active'
  order by post.updated_at desc, post.created_at desc
  limit 80;
end;
$$;

revoke all on function public.get_public_recruitment_posts()
  from public, anon;
grant execute on function public.get_public_recruitment_posts()
  to authenticated;

notify pgrst, 'reload schema';

commit;

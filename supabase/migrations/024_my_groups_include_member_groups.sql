-- Include both admin-owned groups and joined member groups in My Groups.
-- The existing group_members table has role only (admin/member), with no
-- membership status or left_at column, so active membership is represented by
-- a row in group_members for an active group.
-- Run after 023_recruitment_applications.sql.

begin;

drop function if exists public.get_my_group_profiles();

create function public.get_my_group_profiles()
returns table (
  id uuid,
  created_by uuid,
  name text,
  bio text,
  activity_frequency text,
  account_status text,
  membership_role text,
  created_at timestamptz,
  updated_at timestamptz,
  genre_ids jsonb,
  genre_names jsonb,
  recruiting_part_ids jsonb,
  recruiting_part_names jsonb,
  area_ids jsonb,
  area_names jsonb
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
begin
  if v_user_id is null then
    raise exception 'sign in is required';
  end if;

  return query
  select
    g.id,
    g.created_by,
    g.name,
    g.bio,
    g.activity_frequency,
    g.account_status,
    gm.role as membership_role,
    g.created_at,
    g.updated_at,
    coalesce((
      select jsonb_agg(gg.genre_id order by genre.sort_order)
      from public.group_genres gg
      join public.genres genre on genre.id = gg.genre_id and genre.is_active
      where gg.group_id = g.id
    ), '[]'::jsonb) as genre_ids,
    coalesce((
      select jsonb_agg(genre.name order by genre.sort_order)
      from public.group_genres gg
      join public.genres genre on genre.id = gg.genre_id and genre.is_active
      where gg.group_id = g.id
    ), '[]'::jsonb) as genre_names,
    coalesce((
      select jsonb_agg(gp.part_id order by part.sort_order)
      from public.group_recruiting_parts gp
      join public.parts part on part.id = gp.part_id and part.is_active
      where gp.group_id = g.id
    ), '[]'::jsonb) as recruiting_part_ids,
    coalesce((
      select jsonb_agg(part.name order by part.sort_order)
      from public.group_recruiting_parts gp
      join public.parts part on part.id = gp.part_id and part.is_active
      where gp.group_id = g.id
    ), '[]'::jsonb) as recruiting_part_names,
    coalesce((
      select jsonb_agg(ga.area_id order by area.sort_order, area.name)
      from public.group_areas ga
      join public.areas area on area.id = ga.area_id and area.is_active
      where ga.group_id = g.id
    ), '[]'::jsonb) as area_ids,
    coalesce((
      select jsonb_agg(area.name order by area.sort_order, area.name)
      from public.group_areas ga
      join public.areas area on area.id = ga.area_id and area.is_active
      where ga.group_id = g.id
    ), '[]'::jsonb) as area_names
  from public.group_members gm
  join public.groups g on g.id = gm.group_id
  where gm.user_id = v_user_id
    and gm.role in ('admin', 'member')
    and g.account_status = 'active'
  order by
    case gm.role when 'admin' then 0 else 1 end,
    g.updated_at desc,
    g.created_at desc;
end;
$$;

revoke all on function public.get_my_group_profiles() from public, anon;
grant execute on function public.get_my_group_profiles() to authenticated;

notify pgrst, 'reload schema';

commit;

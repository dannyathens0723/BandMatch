-- Safe, authenticated member search projection for Flutter clients.
-- The private public.users table remains protected by its existing RLS policies.
-- Run after 004_public_master_data_read_policies.sql.

begin;

create or replace view public.member_search_profiles
with (security_invoker = false)
as
select
  u.id,
  u.display_name,
  u.avatar_url,
  case
    when u.show_age then date_part('year', age(current_date, u.birth_date))::integer
  end as age,
  case when u.show_gender then u.gender end as gender,
  u.experience_level,
  u.bio,
  coalesce((
    select jsonb_agg(up.purpose order by up.purpose)
    from public.user_purposes up
    where up.user_id = u.id
  ), '[]'::jsonb) as purposes,
  coalesce((
    select jsonb_agg(p.name order by p.sort_order)
    from public.user_parts up
    join public.parts p on p.id = up.part_id and p.is_active
    where up.user_id = u.id
  ), '[]'::jsonb) as part_names,
  coalesce((
    select jsonb_agg(g.name order by g.sort_order)
    from public.user_genres ug
    join public.genres g on g.id = ug.genre_id and g.is_active
    where ug.user_id = u.id
  ), '[]'::jsonb) as genre_names,
  coalesce((
    select jsonb_agg(a.name order by a.sort_order, a.name)
    from public.user_areas ua
    join public.areas a on a.id = ua.area_id and a.is_active
    where ua.user_id = u.id
      and (a.level = 'prefecture' or ua.show_on_profile)
  ), '[]'::jsonb) as area_names
from public.users u
where u.account_status = 'active'
  and u.id <> public.current_user_id()
  and not public.has_block_relationship(public.current_user_id(), u.id);

revoke all on public.member_search_profiles from public, anon;
grant select on public.member_search_profiles to authenticated;

commit;

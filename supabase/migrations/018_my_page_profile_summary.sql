-- Safe current-user My Page profile summary for Flutter clients.
-- This exposes only the signed-in user's own public profile summary and no
-- private account fields. Run after 017_member_search_filters.sql.

begin;

create or replace function public.get_my_page_profile()
returns table (
  id uuid,
  display_name text,
  avatar_url text,
  experience_level text,
  part_names jsonb,
  genre_names jsonb,
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
    u.id,
    u.display_name,
    u.avatar_url,
    u.experience_level,
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
  where u.id = v_user_id
    and u.account_status = 'active';
end;
$$;

revoke all on function public.get_my_page_profile() from public, anon;
grant execute on function public.get_my_page_profile() to authenticated;

notify pgrst, 'reload schema';

commit;

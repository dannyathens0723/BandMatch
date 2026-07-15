-- Safe filtered member search for authenticated Flutter clients.
-- The RPC returns the same public projection as member_search_profiles and
-- keeps private user fields hidden. Run after 016_chat_access_control_hardening.sql.

begin;

create or replace function public.search_member_profiles(
  p_part_ids uuid[] default null,
  p_genre_ids uuid[] default null,
  p_area_ids uuid[] default null,
  p_experience_levels text[] default null,
  p_purposes text[] default null,
  p_keyword text default null
)
returns table (
  id uuid,
  display_name text,
  avatar_url text,
  age integer,
  gender text,
  experience_level text,
  bio text,
  purposes jsonb,
  part_names jsonb,
  genre_names jsonb,
  area_names jsonb
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_keyword text := nullif(btrim(coalesce(p_keyword, '')), '');
begin
  return query
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
    and not public.has_block_relationship(public.current_user_id(), u.id)
    and (
      coalesce(array_length(p_part_ids, 1), 0) = 0
      or exists (
        select 1
        from public.user_parts up
        join public.parts p on p.id = up.part_id and p.is_active
        where up.user_id = u.id
          and up.part_id = any(p_part_ids)
      )
    )
    and (
      coalesce(array_length(p_genre_ids, 1), 0) = 0
      or exists (
        select 1
        from public.user_genres ug
        join public.genres g on g.id = ug.genre_id and g.is_active
        where ug.user_id = u.id
          and ug.genre_id = any(p_genre_ids)
      )
    )
    and (
      coalesce(array_length(p_area_ids, 1), 0) = 0
      or exists (
        select 1
        from public.user_areas ua
        join public.areas a on a.id = ua.area_id and a.is_active
        where ua.user_id = u.id
          and ua.area_id = any(p_area_ids)
          and (a.level = 'prefecture' or ua.show_on_profile)
      )
    )
    and (
      coalesce(array_length(p_experience_levels, 1), 0) = 0
      or u.experience_level = any(p_experience_levels)
    )
    and (
      coalesce(array_length(p_purposes, 1), 0) = 0
      or exists (
        select 1
        from public.user_purposes up
        where up.user_id = u.id
          and up.purpose = any(p_purposes)
      )
    )
    and (v_keyword is null or u.display_name ilike '%' || v_keyword || '%')
  order by u.display_name
  limit 60;
end;
$$;

revoke all on function public.search_member_profiles(
  uuid[],
  uuid[],
  uuid[],
  text[],
  text[],
  text
) from public, anon;
grant execute on function public.search_member_profiles(
  uuid[],
  uuid[],
  uuid[],
  text[],
  text[],
  text
) to authenticated;

notify pgrst, 'reload schema';

commit;

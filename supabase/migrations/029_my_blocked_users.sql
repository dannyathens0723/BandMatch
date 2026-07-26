-- Safe blocked-user list for the signed-in user.
-- Reuses public.blocks and the existing unblock_user(uuid) RPC. This exposes
-- only safe profile fields for rows created by the current blocker.
-- Run after 028_active_group_membership_and_reapplication.sql.

begin;

create or replace function public.get_my_blocked_users()
returns table (
  blocked_user_id uuid,
  display_name text,
  avatar_url text,
  experience_level text,
  part_names jsonb,
  genre_names jsonb,
  blocked_at timestamptz
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
    block.blocked_id as blocked_user_id,
    case
      when profile.account_status = 'active' then profile.display_name
      else '利用できないユーザー'::text
    end as display_name,
    case
      when profile.account_status = 'active' then profile.avatar_url
    end as avatar_url,
    case
      when profile.account_status = 'active' then profile.experience_level
    end as experience_level,
    case
      when profile.account_status = 'active' then coalesce((
        select jsonb_agg(part.name order by part.sort_order)
        from public.user_parts user_part
        join public.parts part
          on part.id = user_part.part_id
          and part.is_active
        where user_part.user_id = profile.id
      ), '[]'::jsonb)
      else '[]'::jsonb
    end as part_names,
    case
      when profile.account_status = 'active' then coalesce((
        select jsonb_agg(genre.name order by genre.sort_order)
        from public.user_genres user_genre
        join public.genres genre
          on genre.id = user_genre.genre_id
          and genre.is_active
        where user_genre.user_id = profile.id
      ), '[]'::jsonb)
      else '[]'::jsonb
    end as genre_names,
    block.created_at as blocked_at
  from public.blocks block
  join public.users profile on profile.id = block.blocked_id
  where block.blocker_id = v_user_id
  order by block.created_at desc;
end;
$$;

revoke all on function public.get_my_blocked_users() from public, anon;
grant execute on function public.get_my_blocked_users() to authenticated;

notify pgrst, 'reload schema';

commit;

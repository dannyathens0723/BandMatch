-- Safe read-only group member list for users who belong to the group.
-- This adds no group chat, image upload, member removal, role changes,
-- invitations, notifications, realtime, block/report, or UI redesign.
-- Run after 024_my_groups_include_member_groups.sql.

begin;

create or replace function public.get_group_members(
  p_group_id uuid
)
returns table (
  user_id uuid,
  display_name text,
  avatar_url text,
  experience_level text,
  part_names jsonb,
  genre_names jsonb,
  role text,
  joined_at timestamptz,
  created_at timestamptz
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

  if p_group_id is null
    or not exists (
      select 1
      from public.groups g
      where g.id = p_group_id
        and g.account_status = 'active'
    ) then
    raise exception 'active group not found';
  end if;

  if not exists (
    select 1
    from public.group_members self_member
    where self_member.group_id = p_group_id
      and self_member.user_id = v_user_id
      and self_member.role in ('admin', 'member')
  ) then
    raise exception 'only group members can read the member list';
  end if;

  return query
  select
    member.user_id,
    profile.display_name,
    profile.avatar_url,
    profile.experience_level,
    coalesce((
      select jsonb_agg(part.name order by part.sort_order)
      from public.user_parts up
      join public.parts part on part.id = up.part_id and part.is_active
      where up.user_id = profile.id
    ), '[]'::jsonb) as part_names,
    coalesce((
      select jsonb_agg(genre.name order by genre.sort_order)
      from public.user_genres ug
      join public.genres genre on genre.id = ug.genre_id and genre.is_active
      where ug.user_id = profile.id
    ), '[]'::jsonb) as genre_names,
    member.role,
    member.joined_at,
    member.created_at
  from public.group_members member
  join public.users profile on profile.id = member.user_id
  where member.group_id = p_group_id
    and member.role in ('admin', 'member')
    and profile.account_status = 'active'
  order by
    case member.role when 'admin' then 0 else 1 end,
    member.joined_at asc,
    profile.display_name asc;
end;
$$;

revoke all on function public.get_group_members(uuid) from public, anon;
grant execute on function public.get_group_members(uuid) to authenticated;

notify pgrst, 'reload schema';

commit;

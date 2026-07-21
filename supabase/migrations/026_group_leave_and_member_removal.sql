-- Basic group leave and member removal.
-- The current group_members schema has no status or left_at column, so inactive
-- membership is represented by deleting the group_members row. This migration
-- does not add role changes, owner transfer, invitations, group chat,
-- notifications, realtime, block/report, or UI redesign.
-- Run after 025_group_member_list.sql.

begin;

create or replace function public.leave_group(
  p_group_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
  v_role text;
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

  select member.role into v_role
  from public.group_members member
  where member.group_id = p_group_id
    and member.user_id = v_user_id
  for update;

  if v_role is null then
    raise exception 'group membership not found';
  end if;

  if v_role = 'admin' then
    raise exception 'admin group leave is not supported yet';
  end if;

  delete from public.group_members
  where group_id = p_group_id
    and user_id = v_user_id
    and role = 'member';

  return p_group_id;
end;
$$;

create or replace function public.remove_group_member(
  p_group_id uuid,
  p_member_user_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_id uuid := public.current_user_id();
  v_target_role text;
begin
  if v_actor_id is null then
    raise exception 'sign in is required';
  end if;

  if p_group_id is null
    or p_member_user_id is null
    or not exists (
      select 1
      from public.groups g
      where g.id = p_group_id
        and g.account_status = 'active'
    ) then
    raise exception 'active group or member not found';
  end if;

  if not public.is_group_admin(p_group_id) then
    raise exception 'only group admins can remove members';
  end if;

  select member.role into v_target_role
  from public.group_members member
  where member.group_id = p_group_id
    and member.user_id = p_member_user_id
  for update;

  if v_target_role is null then
    raise exception 'target membership not found';
  end if;

  if v_target_role <> 'member' then
    raise exception 'only regular members can be removed';
  end if;

  delete from public.group_members
  where group_id = p_group_id
    and user_id = p_member_user_id
    and role = 'member';

  return p_member_user_id;
end;
$$;

revoke all on function public.leave_group(uuid) from public, anon;
revoke all on function public.remove_group_member(uuid, uuid) from public, anon;
grant execute on function public.leave_group(uuid) to authenticated;
grant execute on function public.remove_group_member(uuid, uuid)
  to authenticated;

notify pgrst, 'reload schema';

commit;

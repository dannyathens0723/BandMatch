-- Safe, lightweight in-app badge counts for the signed-in user.
-- This adds no email/push notifications, realtime, read receipts, polling,
-- account deactivation, or moderation behavior. Run after
-- 029_my_blocked_users.sql.

begin;

create or replace function public.get_my_badge_counts()
returns table (
  pending_message_request_count integer,
  pending_recruitment_application_count integer
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
    (
      select count(*)::integer
      from public.message_requests request
      join public.users sender
        on sender.id = request.sender_user_id
        and sender.account_status = 'active'
      where request.receiver_user_id = v_user_id
        and request.receiver_group_id is null
        and request.sender_user_id is not null
        and request.sender_group_id is null
        and request.status = 'pending'
        and not public.has_block_relationship(v_user_id, sender.id)
    ) as pending_message_request_count,
    (
      select count(*)::integer
      from public.recruitment_applications application
      join public.groups managed_group
        on managed_group.id = application.group_id
        and managed_group.account_status = 'active'
      join public.group_members admin_membership
        on admin_membership.group_id = managed_group.id
        and admin_membership.user_id = v_user_id
        and admin_membership.role = 'admin'
        and admin_membership.membership_status = 'active'
        and admin_membership.left_at is null
      join public.users applicant
        on applicant.id = application.applicant_user_id
        and applicant.account_status = 'active'
      where application.status = 'pending'
    ) as pending_recruitment_application_count;
end;
$$;

revoke all on function public.get_my_badge_counts() from public, anon;
grant execute on function public.get_my_badge_counts() to authenticated;

notify pgrst, 'reload schema';

commit;

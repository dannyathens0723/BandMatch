-- Minimal room-level unread chat tracking.
-- Existing participants are initialized at migration time so historical
-- messages do not suddenly become unread. This adds no realtime, polling,
-- push/email notifications, per-message read UI, or read checkmarks.
-- Run after 030_in_app_badge_counts.sql.

begin;

alter table public.room_participants
  add column if not exists last_read_at timestamptz;

update public.room_participants
set last_read_at = now()
where last_read_at is null;

alter table public.room_participants
  alter column last_read_at set default now();

create or replace function public.mark_chat_room_read(
  p_room_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
  v_updated_count integer;
begin
  if v_user_id is null then
    raise exception 'sign in is required';
  end if;

  if p_room_id is null
    or not public.is_active_accepted_room_participant(p_room_id) then
    raise exception 'only active participants can mark this room as read';
  end if;

  update public.room_participants participant
  set last_read_at = now()
  where participant.room_id = p_room_id
    and participant.user_id = v_user_id
    and participant.left_at is null;

  get diagnostics v_updated_count = row_count;
  return v_updated_count = 1;
end;
$$;

drop function if exists public.get_my_badge_counts();

create function public.get_my_badge_counts()
returns table (
  pending_message_request_count integer,
  pending_recruitment_application_count integer,
  unread_chat_message_count integer
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
    ) as pending_recruitment_application_count,
    (
      select count(*)::integer
      from public.room_participants participant
      join public.message_rooms room
        on room.id = participant.room_id
      join public.message_requests request
        on request.id = room.request_id
        and request.status = 'accepted'
      join public.users other_chat_user
        on other_chat_user.id = case
          when request.sender_user_id = v_user_id
            then request.receiver_user_id
          else request.sender_user_id
        end
        and other_chat_user.account_status = 'active'
      join public.messages message
        on message.room_id = room.id
      where participant.user_id = v_user_id
        and participant.left_at is null
        and request.sender_user_id is not null
        and request.receiver_user_id is not null
        and request.sender_group_id is null
        and request.receiver_group_id is null
        and not public.has_block_relationship(
          request.sender_user_id,
          request.receiver_user_id
        )
        and message.message_type = 'text'
        and message.sender_user_id <> v_user_id
        and message.created_at >= participant.joined_at
        and message.created_at > coalesce(
          participant.last_read_at,
          participant.joined_at,
          participant.created_at,
          now()
        )
    ) as unread_chat_message_count;
end;
$$;

drop view if exists public.my_chat_rooms;

create view public.my_chat_rooms
with (security_invoker = false)
as
select
  room.id as room_id,
  other_user.id as other_user_id,
  other_user.display_name,
  other_user.avatar_url,
  other_user.experience_level,
  room.last_message_at,
  room.created_at,
  (
    select count(*)::integer
    from public.messages message
    where message.room_id = room.id
      and message.message_type = 'text'
      and message.sender_user_id <> public.current_user_id()
      and message.created_at >= self_participant.joined_at
      and message.created_at > coalesce(
        self_participant.last_read_at,
        self_participant.joined_at,
        self_participant.created_at,
        now()
      )
  ) as unread_count
from public.message_rooms room
join public.message_requests request on request.id = room.request_id
join public.room_participants self_participant
  on self_participant.room_id = room.id
  and self_participant.user_id = public.current_user_id()
  and self_participant.left_at is null
join public.room_participants other_participant
  on other_participant.room_id = room.id
  and other_participant.user_id <> public.current_user_id()
  and other_participant.left_at is null
join public.users other_user
  on other_user.id = other_participant.user_id
  and other_user.account_status = 'active'
where request.status = 'accepted'
  and request.sender_user_id is not null
  and request.receiver_user_id is not null
  and request.sender_group_id is null
  and request.receiver_group_id is null
  and not public.has_block_relationship(
    public.current_user_id(),
    other_user.id
  );

revoke all on function public.mark_chat_room_read(uuid) from public, anon;
revoke all on function public.get_my_badge_counts() from public, anon;
revoke all on public.my_chat_rooms from public, anon;

grant execute on function public.mark_chat_room_read(uuid) to authenticated;
grant execute on function public.get_my_badge_counts() to authenticated;
grant select on public.my_chat_rooms to authenticated;

notify pgrst, 'reload schema';

commit;

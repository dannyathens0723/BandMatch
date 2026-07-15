-- Safe, read-only chat-room list for direct accepted relationships.
-- This migration intentionally does not read or write message bodies and adds
-- no message send/read RPCs. Run after 011_rollback_chat_feature.sql.

begin;

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
  room.created_at
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

revoke all on public.my_chat_rooms from public, anon;
grant select on public.my_chat_rooms to authenticated;

notify pgrst, 'reload schema';

commit;

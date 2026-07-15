-- Normalize received-request display state when an old row already has a room.
-- This adds no public access and preserves existing write policies.
-- Run after 011_chat_rooms_and_messages.sql.

begin;

create or replace view public.received_message_requests_view
with (security_invoker = false)
as
select
  r.id,
  case when room.id is not null then 'accepted' else r.status end as status,
  r.note,
  r.created_at,
  r.responded_at,
  sender.id as sender_user_id,
  sender.display_name,
  sender.avatar_url,
  sender.experience_level,
  sender.part_names,
  sender.genre_names,
  room.id as room_id
from public.message_requests r
left join public.message_rooms room on room.request_id = r.id
join public.member_search_profiles sender on sender.id = r.sender_user_id
where r.receiver_user_id = public.current_user_id()
  and r.receiver_group_id is null
  and r.sender_user_id is not null
  and r.sender_group_id is null
  and r.status in ('pending', 'accepted', 'rejected');

revoke all on public.received_message_requests_view from public, anon;
grant select on public.received_message_requests_view to authenticated;

commit;

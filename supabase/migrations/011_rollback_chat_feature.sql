-- Roll back the application-facing database objects introduced by the
-- experimental chat work (previous local migrations 011 through 014).
--
-- This intentionally preserves message_rooms, room_participants, and messages
-- because those base tables belong to the initial schema and may contain user
-- data. It only removes the chat views/RPCs and restores the inbox view from
-- migration 008.
-- Run this once in Supabase SQL Editor only if migrations 011-014 were applied.

begin;

drop function if exists public.send_room_message_v2(uuid, text);
drop function if exists public.send_room_message_with_result(uuid, text);
drop function if exists public.send_room_message(uuid, text);
drop function if exists public.get_room_messages(uuid);
drop view if exists public.my_chat_rooms;

-- Migration 012 appended room_id and normalized the status column. Drop and
-- recreate the view to restore its exact migration-008 column contract.
drop view if exists public.received_message_requests_view;

create view public.received_message_requests_view
with (security_invoker = false)
as
select
  r.id,
  r.status,
  r.note,
  r.created_at,
  r.responded_at,
  sender.id as sender_user_id,
  sender.display_name,
  sender.avatar_url,
  sender.experience_level,
  sender.part_names,
  sender.genre_names
from public.message_requests r
join public.member_search_profiles sender on sender.id = r.sender_user_id
where r.receiver_user_id = public.current_user_id()
  and r.receiver_group_id is null
  and r.sender_user_id is not null
  and r.sender_group_id is null
  and r.status in ('pending', 'accepted', 'rejected');

revoke all on public.received_message_requests_view from public, anon;
grant select on public.received_message_requests_view to authenticated;

notify pgrst, 'reload schema';

commit;

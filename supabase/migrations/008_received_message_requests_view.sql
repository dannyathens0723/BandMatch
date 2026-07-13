-- Safe, authenticated inbox projection for direct user-to-user requests.
-- This view deliberately returns only the receiver's requests and only sender
-- fields that are already approved for member search. The base tables retain
-- their existing RLS policies and write restrictions.
-- Run after 007_message_request_pending_uniqueness.sql.

begin;

create or replace view public.received_message_requests_view
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

commit;

-- Keep a chat send independent of the shared message_rooms row.
-- Updating last_message_at in the send transaction can serialize every send
-- for one room behind a stalled request. The room-list view below derives the
-- effective timestamp from messages instead.
-- Run after 013_fix_chat_send_refresh_warning.sql.

begin;

create or replace function public.send_room_message_v2(
  p_room_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sender_id uuid := public.current_user_id();
  v_body text := btrim(coalesce(p_body, ''));
  v_message_id uuid;
  v_created_at timestamptz;
begin
  if v_sender_id is null then
    raise exception 'sign in is required';
  end if;
  if char_length(v_body) not between 1 and 1000 then
    raise exception 'message body must be between 1 and 1000 characters';
  end if;
  if not exists (
    select 1
    from public.message_rooms room
    join public.message_requests request on request.id = room.request_id
    where room.id = p_room_id and request.status = 'accepted'
  ) then
    raise exception 'message room is not active';
  end if;
  if not public.is_room_participant(p_room_id) then
    raise exception 'only room participants can send messages';
  end if;

  insert into public.messages (
    room_id,
    sender_user_id,
    message_type,
    body
  )
  values (p_room_id, v_sender_id, 'text', v_body)
  returning id, created_at into v_message_id, v_created_at;

  return jsonb_build_object(
    'id', v_message_id,
    'body', v_body,
    'sender_user_id', v_sender_id,
    'created_at', v_created_at
  );
end;
$$;

create or replace view public.my_chat_rooms
with (security_invoker = false)
as
select
  room.id,
  room.created_at,
  coalesce(latest_message.created_at, room.last_message_at) as last_message_at,
  other_user.display_name as other_display_name,
  other_user.avatar_url as other_avatar_url,
  other_user.experience_level as other_experience_level,
  latest_message.body as last_message_body,
  latest_message.created_at as last_message_created_at
from public.message_rooms room
join public.room_participants self_participant
  on self_participant.room_id = room.id
  and self_participant.user_id = public.current_user_id()
  and self_participant.left_at is null
join lateral (
  select participant.user_id
  from public.room_participants participant
  where participant.room_id = room.id
    and participant.user_id <> public.current_user_id()
    and participant.left_at is null
  order by participant.joined_at
  limit 1
) other_participant on true
join public.users other_user on other_user.id = other_participant.user_id
left join lateral (
  select message.body, message.created_at
  from public.messages message
  where message.room_id = room.id
    and message.message_type = 'text'
  order by message.created_at desc
  limit 1
) latest_message on true;

revoke all on function public.send_room_message_v2(uuid, text) from public, anon;
grant execute on function public.send_room_message_v2(uuid, text) to authenticated;

notify pgrst, 'reload schema';

commit;

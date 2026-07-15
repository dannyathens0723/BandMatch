-- Safe chat projections and RPCs for authenticated room participants.
-- No private user columns are exposed and existing table RLS remains enabled.
-- Run after 010_message_request_relationship_state.sql.

begin;

create or replace view public.my_chat_rooms
with (security_invoker = false)
as
select
  room.id,
  room.created_at,
  room.last_message_at,
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

create or replace function public.get_room_messages(p_room_id uuid)
returns table (
  id uuid,
  body text,
  sender_user_id uuid,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_room_participant(p_room_id) then
    raise exception 'only room participants can read messages';
  end if;

  return query
  select message.id, message.body, message.sender_user_id, message.created_at
  from public.messages message
  where message.room_id = p_room_id
    and message.message_type = 'text'
  order by message.created_at asc;
end;
$$;

create or replace function public.send_room_message(
  p_room_id uuid,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sender_id uuid := public.current_user_id();
  v_body text := btrim(coalesce(p_body, ''));
  v_message_id uuid;
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
  returning id into v_message_id;

  update public.message_rooms
  set last_message_at = now()
  where id = p_room_id;

  return v_message_id;
end;
$$;

revoke all on public.my_chat_rooms from public, anon;
grant select on public.my_chat_rooms to authenticated;
revoke all on function public.get_room_messages(uuid) from public, anon;
revoke all on function public.send_room_message(uuid, text) from public, anon;
grant execute on function public.get_room_messages(uuid) to authenticated;
grant execute on function public.send_room_message(uuid, text) to authenticated;

commit;

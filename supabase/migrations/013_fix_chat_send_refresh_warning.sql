-- Return the newly inserted safe message projection so Flutter can update the
-- chat UI without depending on a full post-send reload.
-- Run after 012_fix_chat_send_and_request_states.sql.

begin;

create or replace function public.send_room_message_with_result(
  p_room_id uuid,
  p_body text
)
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
declare
  v_sender_id uuid := public.current_user_id();
  v_body text := btrim(coalesce(p_body, ''));
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

  return query
  insert into public.messages (
    room_id,
    sender_user_id,
    message_type,
    body
  )
  values (p_room_id, v_sender_id, 'text', v_body)
  returning messages.id, messages.body, messages.sender_user_id, messages.created_at;

  update public.message_rooms
  set last_message_at = now()
  where id = p_room_id;
end;
$$;

revoke all on function public.send_room_message_with_result(uuid, text)
  from public, anon;
grant execute on function public.send_room_message_with_result(uuid, text)
  to authenticated;

commit;

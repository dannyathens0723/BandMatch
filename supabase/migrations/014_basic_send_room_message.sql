-- Safe, basic text-message insert for an active room participant.
-- This migration intentionally does not update room metadata, read receipts,
-- or any realtime/polling configuration. Run after 013_read_only_room_messages.sql.

begin;

create function public.send_room_message(
  p_room_id uuid,
  p_body text
)
returns table (
  message_id uuid,
  room_id uuid,
  sender_user_id uuid,
  body text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sender_user_id uuid := public.current_user_id();
  v_body text := btrim(coalesce(p_body, ''));
  v_message_id uuid;
  v_created_at timestamptz;
begin
  if v_sender_user_id is null then
    raise exception 'sign in is required';
  end if;
  if not exists (
    select 1
    from public.users
    where id = v_sender_user_id
      and account_status = 'active'
  ) then
    raise exception 'active profile is required';
  end if;
  if p_room_id is null or not exists (
    select 1 from public.message_rooms where id = p_room_id
  ) then
    raise exception 'message room not found';
  end if;
  if not public.is_room_participant(p_room_id) then
    raise exception 'only active room participants can send messages';
  end if;
  if char_length(v_body) not between 1 and 1000 then
    raise exception 'message body must be between 1 and 1000 characters';
  end if;

  insert into public.messages (
    room_id,
    sender_user_id,
    message_type,
    body
  )
  values (p_room_id, v_sender_user_id, 'text', v_body)
  returning id, created_at into v_message_id, v_created_at;

  return query
  select v_message_id, p_room_id, v_sender_user_id, v_body, v_created_at;
end;
$$;

revoke all on function public.send_room_message(uuid, text) from public, anon;
grant execute on function public.send_room_message(uuid, text) to authenticated;

notify pgrst, 'reload schema';

commit;

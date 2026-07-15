-- Recreate the basic chat-send RPC with the exact Flutter argument contract.
-- This is self-contained: it is safe to run whether migration 014 was already
-- applied or not. It deliberately adds no realtime, polling, read receipts,
-- or room metadata updates.
-- Run after 013_read_only_room_messages.sql.

begin;

create or replace function public.send_room_message(
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
set search_path = public, pg_temp
as $$
declare
  v_sender_user_id uuid := public.current_user_id();
  v_body text := btrim(coalesce(p_body, ''));
begin
  if v_sender_user_id is null then
    raise exception 'sign in is required';
  end if;

  if not exists (
    select 1
    from public.users profile
    where profile.id = v_sender_user_id
      and profile.account_status = 'active'
  ) then
    raise exception 'active profile is required';
  end if;

  if p_room_id is null or not exists (
    select 1
    from public.message_rooms room
    where room.id = p_room_id
  ) then
    raise exception 'message room not found';
  end if;

  if not exists (
    select 1
    from public.room_participants participant
    where participant.room_id = p_room_id
      and participant.user_id = v_sender_user_id
      and participant.left_at is null
  ) then
    raise exception 'only active room participants can send messages';
  end if;

  if char_length(v_body) not between 1 and 1000 then
    raise exception 'message body must be between 1 and 1000 characters';
  end if;

  return query
  with inserted as (
    insert into public.messages (
      room_id,
      sender_user_id,
      message_type,
      body
    )
    values (p_room_id, v_sender_user_id, 'text', v_body)
    returning
      messages.id as message_id,
      messages.room_id,
      messages.sender_user_id,
      messages.body,
      messages.created_at
  )
  select
    inserted.message_id,
    inserted.room_id,
    inserted.sender_user_id,
    inserted.body,
    inserted.created_at
  from inserted;
end;
$$;

revoke all on function public.send_room_message(uuid, text) from public, anon;
grant execute on function public.send_room_message(uuid, text) to authenticated;

notify pgrst, 'reload schema';

commit;

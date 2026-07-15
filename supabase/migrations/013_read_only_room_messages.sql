-- Safe, read-only message projection for a room participant.
-- This migration deliberately contains no message insert/update/delete logic.
-- Run after 012_chat_room_list.sql.

begin;

create function public.get_room_messages(p_room_id uuid)
returns table (
  message_id uuid,
  room_id uuid,
  sender_user_id uuid,
  body text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_room_id is null or not public.is_room_participant(p_room_id) then
    raise exception 'only room participants can read messages';
  end if;

  return query
  select
    message.id as message_id,
    message.room_id,
    message.sender_user_id,
    message.body,
    message.created_at,
    message.updated_at
  from public.messages message
  where message.room_id = p_room_id
    and message.message_type = 'text'
  order by message.created_at asc, message.id asc;
end;
$$;

revoke all on function public.get_room_messages(uuid) from public, anon;
grant execute on function public.get_room_messages(uuid) to authenticated;

notify pgrst, 'reload schema';

commit;

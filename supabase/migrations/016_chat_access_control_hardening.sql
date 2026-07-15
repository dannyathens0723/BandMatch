-- Restrict chat access to active participants of rooms whose request has been
-- accepted. This migration adds no user-facing features, realtime, polling,
-- read receipts, or room metadata updates. Run after 015.

begin;

create or replace function public.is_active_accepted_room_participant(
  p_room_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.message_rooms room
    join public.message_requests request on request.id = room.request_id
    join public.room_participants participant on participant.room_id = room.id
    where room.id = p_room_id
      and request.status = 'accepted'
      and participant.user_id = public.current_user_id()
      and participant.left_at is null
  );
$$;

-- Direct table access remains subject to RLS. Restrict it to accepted rooms
-- too, so a manually-created pending/rejected room cannot become usable.
drop policy if exists rooms_select_participant on public.message_rooms;
create policy rooms_select_participant on public.message_rooms for select to authenticated
  using (public.is_active_accepted_room_participant(id) or public.is_admin());

drop policy if exists room_participants_select_participant on public.room_participants;
create policy room_participants_select_participant on public.room_participants for select to authenticated
  using (public.is_active_accepted_room_participant(room_id) or public.is_admin());

drop policy if exists messages_select_participant on public.messages;
create policy messages_select_participant on public.messages for select to authenticated
  using (public.is_active_accepted_room_participant(room_id) or public.is_admin());

drop policy if exists messages_insert_participant on public.messages;
create policy messages_insert_participant on public.messages for insert to authenticated
  with check (
    public.is_active_accepted_room_participant(room_id)
    and sender_user_id = public.current_user_id()
    and (acting_group_id is null or public.is_room_group_party(room_id, acting_group_id))
  );

create or replace function public.get_room_messages(p_room_id uuid)
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
set search_path = public, pg_temp
as $$
begin
  if p_room_id is null
    or not public.is_active_accepted_room_participant(p_room_id) then
    raise exception 'only active participants of accepted rooms can read messages';
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
    select 1 from public.message_rooms room where room.id = p_room_id
  ) then
    raise exception 'message room not found';
  end if;

  if not public.is_active_accepted_room_participant(p_room_id) then
    raise exception 'only active participants of accepted rooms can send messages';
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

revoke all on function public.is_active_accepted_room_participant(uuid)
  from public, anon;
revoke all on function public.get_room_messages(uuid) from public, anon;
revoke all on function public.send_room_message(uuid, text) from public, anon;
grant execute on function public.is_active_accepted_room_participant(uuid)
  to authenticated;
grant execute on function public.get_room_messages(uuid) to authenticated;
grant execute on function public.send_room_message(uuid, text) to authenticated;

notify pgrst, 'reload schema';

commit;

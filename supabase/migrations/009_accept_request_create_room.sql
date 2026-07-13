-- Make message-request acceptance idempotent and guarantee that an accepted
-- request has exactly one room. This keeps the existing authenticated-only RPC
-- surface; no client receives write access to rooms or participants.
-- Run after 008_received_message_requests_view.sql.

begin;

create or replace function public.accept_message_request(p_request_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.message_requests%rowtype;
  v_room_id uuid;
  v_actor_id uuid := public.current_user_id();
begin
  select * into r
  from public.message_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'message request not found';
  end if;
  if not public.can_act_for_party(r.receiver_user_id, r.receiver_group_id) then
    raise exception 'only the recipient can accept this request';
  end if;
  if r.status not in ('pending', 'accepted') then
    raise exception 'message request cannot be accepted';
  end if;

  if r.status = 'pending' then
    if not public.is_party_active(r.sender_user_id, r.sender_group_id)
      or not public.is_party_active(r.receiver_user_id, r.receiver_group_id) then
      raise exception 'inactive party cannot start a message room';
    end if;

    update public.message_requests
    set status = 'accepted', responded_at = now(), responded_by = v_actor_id
    where id = r.id;
  end if;

  insert into public.message_rooms (request_id, initial_note, last_message_at)
  values (r.id, r.note, now())
  on conflict (request_id) do nothing
  returning id into v_room_id;

  if v_room_id is null then
    select id into v_room_id
    from public.message_rooms
    where request_id = r.id;
  end if;

  insert into public.room_participants (room_id, user_id, participant_role)
  select v_room_id, r.sender_user_id, 'member'
  where r.sender_user_id is not null
  on conflict (room_id, user_id) do nothing;

  insert into public.room_participants (room_id, user_id, participant_role)
  select v_room_id, gm.user_id, 'group_admin'
  from public.group_members gm
  where gm.group_id = r.sender_group_id and gm.role = 'admin'
  on conflict (room_id, user_id) do nothing;

  insert into public.room_participants (room_id, user_id, participant_role)
  select v_room_id, r.receiver_user_id, 'member'
  where r.receiver_user_id is not null
  on conflict (room_id, user_id) do nothing;

  insert into public.room_participants (room_id, user_id, participant_role)
  select v_room_id, gm.user_id, 'group_admin'
  from public.group_members gm
  where gm.group_id = r.receiver_group_id and gm.role = 'admin'
  on conflict (room_id, user_id) do nothing;

  return v_room_id;
end;
$$;

revoke all on function public.accept_message_request(uuid) from public, anon;
grant execute on function public.accept_message_request(uuid) to authenticated;

commit;

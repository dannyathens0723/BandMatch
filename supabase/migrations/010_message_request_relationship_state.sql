-- Safe relationship state and atomic direct-request creation for Flutter.
-- This migration keeps private profile data hidden and does not broaden table
-- policies. It also prevents a client that bypasses the UI from creating a
-- second open request in the opposite direction.
-- Run after 009_accept_request_create_room.sql.

begin;

create or replace function public.get_member_relationship_state(
  p_target_user_id uuid
)
returns table (
  state text,
  request_id uuid,
  room_id uuid
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_id uuid := public.current_user_id();
  v_request_id uuid;
  v_status text;
  v_room_id uuid;
begin
  if v_actor_id is null
    or p_target_user_id is null
    or p_target_user_id = v_actor_id
    or not exists (
      select 1 from public.users
      where id = p_target_user_id and account_status = 'active'
    )
    or public.has_block_relationship(v_actor_id, p_target_user_id) then
    return query select 'none'::text, null::uuid, null::uuid;
    return;
  end if;

  select r.id, r.status, room.id
  into v_request_id, v_status, v_room_id
  from public.message_requests r
  left join public.message_rooms room on room.request_id = r.id
  where r.sender_group_id is null
    and r.receiver_group_id is null
    and (
      (r.sender_user_id = v_actor_id and r.receiver_user_id = p_target_user_id)
      or (r.sender_user_id = p_target_user_id and r.receiver_user_id = v_actor_id)
    )
  order by
    case
      when room.id is not null then 0
      when r.status = 'accepted' then 1
      when r.status = 'pending' and r.receiver_user_id = v_actor_id then 2
      when r.status = 'pending' then 3
      when r.status = 'rejected' then 4
      else 5
    end,
    r.created_at desc
  limit 1;

  if not found then
    return query select 'none'::text, null::uuid, null::uuid;
  elsif v_room_id is not null then
    return query select 'room_exists'::text, v_request_id, v_room_id;
  elsif v_status = 'accepted' then
    return query select 'accepted'::text, v_request_id, null::uuid;
  elsif v_status = 'pending' then
    if exists (
      select 1 from public.message_requests
      where id = v_request_id and receiver_user_id = v_actor_id
    ) then
      return query select 'incoming_pending'::text, v_request_id, null::uuid;
    end if;
    return query select 'outgoing_pending'::text, v_request_id, null::uuid;
  end if;

  return query select 'rejected'::text, v_request_id, null::uuid;
end;
$$;

create or replace function public.prevent_duplicate_open_direct_message_requests()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_pair_key text;
begin
  if new.sender_user_id is null
    or new.receiver_user_id is null
    or new.sender_group_id is not null
    or new.receiver_group_id is not null
    or new.status not in ('pending', 'accepted') then
    return new;
  end if;

  v_pair_key := case
    when new.sender_user_id::text < new.receiver_user_id::text
      then new.sender_user_id::text || ':' || new.receiver_user_id::text
    else new.receiver_user_id::text || ':' || new.sender_user_id::text
  end;
  perform pg_advisory_xact_lock(hashtextextended(v_pair_key, 0));

  if exists (
    select 1
    from public.message_requests existing
    where existing.id <> new.id
      and existing.sender_group_id is null
      and existing.receiver_group_id is null
      and existing.status in ('pending', 'accepted')
      and (
        (existing.sender_user_id = new.sender_user_id
          and existing.receiver_user_id = new.receiver_user_id)
        or (existing.sender_user_id = new.receiver_user_id
          and existing.receiver_user_id = new.sender_user_id)
      )
  ) then
    raise exception 'an open message request already exists for this relationship'
      using errcode = '23505';
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_duplicate_open_direct_message_requests
  on public.message_requests;
create trigger prevent_duplicate_open_direct_message_requests
before insert or update of sender_user_id, receiver_user_id, sender_group_id,
  receiver_group_id, status on public.message_requests
for each row execute function public.prevent_duplicate_open_direct_message_requests();

create or replace function public.send_message_request(
  p_target_user_id uuid,
  p_note text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sender_id uuid := public.current_user_id();
  v_note text := btrim(coalesce(p_note, ''));
  v_request_id uuid;
begin
  if v_sender_id is null then
    raise exception 'sign in is required';
  end if;
  if p_target_user_id is null or p_target_user_id = v_sender_id then
    raise exception 'cannot send a message request to yourself';
  end if;
  if char_length(v_note) not between 1 and 300 then
    raise exception 'message request note must be between 1 and 300 characters';
  end if;
  if not public.is_party_active(v_sender_id, null)
    or not public.is_party_active(p_target_user_id, null) then
    raise exception 'inactive users cannot send message requests';
  end if;
  if public.has_block_relationship(v_sender_id, p_target_user_id) then
    raise exception 'a block relationship prevents this message request';
  end if;

  insert into public.message_requests (
    sender_user_id,
    receiver_user_id,
    status,
    note
  )
  values (v_sender_id, p_target_user_id, 'pending', v_note)
  returning id into v_request_id;

  return v_request_id;
end;
$$;

revoke all on function public.get_member_relationship_state(uuid) from public, anon;
revoke all on function public.send_message_request(uuid, text) from public, anon;
grant execute on function public.get_member_relationship_state(uuid) to authenticated;
grant execute on function public.send_message_request(uuid, text) to authenticated;

commit;

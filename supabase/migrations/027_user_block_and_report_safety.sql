-- MVP user blocking and reporting safety controls.
-- Reuses the existing blocks/reports tables and the bidirectional
-- has_block_relationship helper. This migration adds no moderation dashboard,
-- automatic sanctions, notifications, realtime, or read receipts.
-- Run after 026_group_leave_and_member_removal.sql.

begin;

create or replace function public.get_user_safety_state(
  p_target_user_id uuid
)
returns table (
  state text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
begin
  if v_user_id is null then
    raise exception 'sign in is required';
  end if;

  if p_target_user_id is null
    or p_target_user_id = v_user_id
    or not exists (
      select 1
      from public.users target
      where target.id = p_target_user_id
        and target.account_status = 'active'
    ) then
    return query select 'unavailable'::text;
    return;
  end if;

  if exists (
    select 1
    from public.blocks block
    where block.blocker_id = v_user_id
      and block.blocked_id = p_target_user_id
  ) then
    return query select 'blocked_by_me'::text;
    return;
  end if;

  if exists (
    select 1
    from public.blocks block
    where block.blocker_id = p_target_user_id
      and block.blocked_id = v_user_id
  ) then
    return query select 'blocked_me'::text;
    return;
  end if;

  return query select 'none'::text;
end;
$$;

create or replace function public.block_user(
  p_blocked_user_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
  v_block_id uuid;
begin
  if v_user_id is null then
    raise exception 'sign in is required';
  end if;

  if not exists (
    select 1
    from public.users profile
    where profile.id = v_user_id
      and profile.account_status = 'active'
  ) then
    raise exception 'active profile is required';
  end if;

  if p_blocked_user_id is null or p_blocked_user_id = v_user_id then
    raise exception 'cannot block yourself';
  end if;

  if not exists (
    select 1
    from public.users target
    where target.id = p_blocked_user_id
      and target.account_status = 'active'
  ) then
    raise exception 'active target profile not found';
  end if;

  insert into public.blocks (
    blocker_id,
    blocked_id
  )
  values (
    v_user_id,
    p_blocked_user_id
  )
  on conflict (blocker_id, blocked_id) do nothing
  returning id into v_block_id;

  if v_block_id is null then
    select block.id into v_block_id
    from public.blocks block
    where block.blocker_id = v_user_id
      and block.blocked_id = p_blocked_user_id;
  end if;

  return v_block_id;
end;
$$;

create or replace function public.unblock_user(
  p_blocked_user_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
  v_deleted_count integer;
begin
  if v_user_id is null then
    raise exception 'sign in is required';
  end if;

  if p_blocked_user_id is null or p_blocked_user_id = v_user_id then
    raise exception 'invalid blocked user';
  end if;

  delete from public.blocks block
  where block.blocker_id = v_user_id
    and block.blocked_id = p_blocked_user_id;

  get diagnostics v_deleted_count = row_count;
  return v_deleted_count > 0;
end;
$$;

create or replace function public.report_user(
  p_reported_user_id uuid,
  p_reason text,
  p_note text default null
)
returns table (
  report_id uuid,
  status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
  v_reason text := btrim(coalesce(p_reason, ''));
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if v_user_id is null then
    raise exception 'sign in is required';
  end if;

  if not exists (
    select 1
    from public.users profile
    where profile.id = v_user_id
      and profile.account_status = 'active'
  ) then
    raise exception 'active profile is required';
  end if;

  if p_reported_user_id is null or p_reported_user_id = v_user_id then
    raise exception 'cannot report yourself';
  end if;

  if not exists (
    select 1
    from public.users target
    where target.id = p_reported_user_id
      and target.account_status = 'active'
  ) then
    raise exception 'active target profile not found';
  end if;

  if v_reason not in (
    'harassment',
    'inappropriate_profile',
    'impersonation',
    'other'
  ) then
    raise exception 'invalid report reason';
  end if;

  if v_note is not null and char_length(v_note) > 1000 then
    raise exception 'report note must be 1000 characters or fewer';
  end if;

  return query
  with inserted as (
    insert into public.reports (
      reporter_id,
      target_user_id,
      reason,
      details,
      status
    )
    values (
      v_user_id,
      p_reported_user_id,
      v_reason,
      v_note,
      'open'
    )
    returning
      reports.id,
      reports.status,
      reports.created_at
  )
  select inserted.id, inserted.status, inserted.created_at
  from inserted;
end;
$$;

create or replace function public.room_has_block_relationship(
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
    where room.id = p_room_id
      and request.sender_user_id is not null
      and request.receiver_user_id is not null
      and request.sender_group_id is null
      and request.receiver_group_id is null
      and public.has_block_relationship(
        request.sender_user_id,
        request.receiver_user_id
      )
  );
$$;

drop policy if exists messages_insert_participant on public.messages;
create policy messages_insert_participant on public.messages
  for insert to authenticated
  with check (
    public.is_active_accepted_room_participant(room_id)
    and not public.room_has_block_relationship(room_id)
    and sender_user_id = public.current_user_id()
    and (
      acting_group_id is null
      or public.is_room_group_party(room_id, acting_group_id)
    )
  );

drop policy if exists reports_insert_reporter on public.reports;
create policy reports_insert_reporter on public.reports
  for insert to authenticated
  with check (
    reporter_id = public.current_user_id()
    and status = 'open'
    and (
      target_user_id is null
      or target_user_id <> public.current_user_id()
    )
    and admin_note is null
    and resolved_at is null
    and resolved_by is null
  );

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

  if not public.is_active_accepted_room_participant(p_room_id) then
    raise exception 'only active participants of accepted rooms can send messages';
  end if;

  if public.room_has_block_relationship(p_room_id) then
    raise exception 'a block relationship prevents sending messages';
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
    values (
      p_room_id,
      v_sender_user_id,
      'text',
      v_body
    )
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

revoke all on function public.get_user_safety_state(uuid) from public, anon;
revoke all on function public.block_user(uuid) from public, anon;
revoke all on function public.unblock_user(uuid) from public, anon;
revoke all on function public.report_user(uuid, text, text)
  from public, anon;
revoke all on function public.room_has_block_relationship(uuid)
  from public, anon;
revoke all on function public.send_room_message(uuid, text)
  from public, anon;

grant execute on function public.get_user_safety_state(uuid)
  to authenticated;
grant execute on function public.block_user(uuid) to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;
grant execute on function public.report_user(uuid, text, text)
  to authenticated;
grant execute on function public.room_has_block_relationship(uuid)
  to authenticated;
grant execute on function public.send_room_message(uuid, text)
  to authenticated;

notify pgrst, 'reload schema';

commit;

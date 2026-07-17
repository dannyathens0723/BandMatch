-- Basic recruitment application flow.
-- Users can apply to open recruitment posts. Group admins can accept/reject
-- applications; accepted applicants are added to group_members as members.
-- This migration does not add group chat, invitations, notifications,
-- realtime, read receipts, block/report, or group image upload.
-- Run after 022_public_recruitment_posts.sql.

begin;

create table if not exists public.recruitment_applications (
  id uuid primary key default gen_random_uuid(),
  recruitment_post_id uuid not null
    references public.recruitment_posts(id) on delete cascade,
  group_id uuid not null references public.groups(id) on delete cascade,
  applicant_user_id uuid not null references public.users(id) on delete restrict,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected')),
  note text check (note is null or char_length(note) <= 500),
  responded_at timestamptz,
  responded_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (recruitment_post_id, applicant_user_id)
);

create index if not exists recruitment_applications_group_status_idx
  on public.recruitment_applications (group_id, status, created_at desc);
create index if not exists recruitment_applications_applicant_idx
  on public.recruitment_applications (applicant_user_id, created_at desc);

alter table public.recruitment_applications enable row level security;

drop trigger if exists set_updated_at on public.recruitment_applications;
create trigger set_updated_at
before update on public.recruitment_applications
for each row execute function public.set_updated_at();

drop policy if exists recruitment_applications_read_parties
  on public.recruitment_applications;
create policy recruitment_applications_read_parties
  on public.recruitment_applications
  for select to authenticated
  using (
    applicant_user_id = public.current_user_id()
    or public.is_group_admin(group_id)
    or public.is_admin()
  );

create or replace function public.get_my_recruitment_application_state(
  p_post_id uuid
)
returns table (
  state text,
  application_id uuid
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
  v_group_id uuid;
  v_status text;
  v_application_id uuid;
begin
  if v_user_id is null then
    return query select 'none'::text, null::uuid;
    return;
  end if;

  select post.group_id into v_group_id
  from public.recruitment_posts post
  join public.groups g on g.id = post.group_id
  where post.id = p_post_id
    and post.status = 'open'
    and g.account_status = 'active';

  if v_group_id is null then
    return query select 'closed'::text, null::uuid;
    return;
  end if;

  if public.is_group_admin(v_group_id) then
    return query select 'own_group'::text, null::uuid;
    return;
  end if;

  if exists (
    select 1
    from public.group_members gm
    where gm.group_id = v_group_id
      and gm.user_id = v_user_id
  ) then
    return query select 'group_member'::text, null::uuid;
    return;
  end if;

  select app.id, app.status
  into v_application_id, v_status
  from public.recruitment_applications app
  where app.recruitment_post_id = p_post_id
    and app.applicant_user_id = v_user_id
  order by app.created_at desc
  limit 1;

  if v_application_id is null then
    return query select 'none'::text, null::uuid;
    return;
  end if;

  return query select v_status, v_application_id;
end;
$$;

create or replace function public.apply_to_recruitment_post(
  p_post_id uuid,
  p_message text default null
)
returns table (
  application_id uuid,
  status text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
  v_group_id uuid;
  v_note text := nullif(btrim(coalesce(p_message, '')), '');
  v_application_id uuid;
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

  if v_note is not null and char_length(v_note) > 500 then
    raise exception 'application message must be 500 characters or fewer';
  end if;

  select post.group_id into v_group_id
  from public.recruitment_posts post
  join public.groups g on g.id = post.group_id
  where post.id = p_post_id
    and post.status = 'open'
    and g.account_status = 'active';

  if v_group_id is null then
    raise exception 'open recruitment post not found';
  end if;

  if public.is_group_admin(v_group_id) then
    raise exception 'group admins cannot apply to their own recruitment posts';
  end if;

  if exists (
    select 1
    from public.group_members gm
    where gm.group_id = v_group_id
      and gm.user_id = v_user_id
  ) then
    raise exception 'group members cannot apply to their own group';
  end if;

  if exists (
    select 1
    from public.recruitment_applications app
    where app.recruitment_post_id = p_post_id
      and app.applicant_user_id = v_user_id
  ) then
    raise exception 'application already exists';
  end if;

  insert into public.recruitment_applications (
    recruitment_post_id,
    group_id,
    applicant_user_id,
    status,
    note
  )
  values (
    p_post_id,
    v_group_id,
    v_user_id,
    'pending',
    v_note
  )
  returning id into v_application_id;

  return query select v_application_id, 'pending'::text;
end;
$$;

create or replace function public.get_my_group_recruitment_applications(
  p_group_id uuid
)
returns table (
  id uuid,
  recruitment_post_id uuid,
  group_id uuid,
  post_title text,
  applicant_user_id uuid,
  applicant_display_name text,
  applicant_avatar_url text,
  applicant_experience_level text,
  applicant_part_names jsonb,
  applicant_genre_names jsonb,
  note text,
  status text,
  created_at timestamptz,
  responded_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_group_id is null
    or not exists (
      select 1
      from public.groups g
      where g.id = p_group_id
        and g.account_status = 'active'
    ) then
    raise exception 'active group not found';
  end if;

  if not public.is_group_admin(p_group_id) then
    raise exception 'only group admins can read recruitment applications';
  end if;

  return query
  select
    app.id,
    app.recruitment_post_id,
    app.group_id,
    post.title as post_title,
    applicant.id as applicant_user_id,
    applicant.display_name as applicant_display_name,
    applicant.avatar_url as applicant_avatar_url,
    applicant.experience_level as applicant_experience_level,
    coalesce((
      select jsonb_agg(part.name order by part.sort_order)
      from public.user_parts up
      join public.parts part on part.id = up.part_id and part.is_active
      where up.user_id = applicant.id
    ), '[]'::jsonb) as applicant_part_names,
    coalesce((
      select jsonb_agg(genre.name order by genre.sort_order)
      from public.user_genres ug
      join public.genres genre on genre.id = ug.genre_id and genre.is_active
      where ug.user_id = applicant.id
    ), '[]'::jsonb) as applicant_genre_names,
    app.note,
    app.status,
    app.created_at,
    app.responded_at
  from public.recruitment_applications app
  join public.recruitment_posts post on post.id = app.recruitment_post_id
  join public.users applicant on applicant.id = app.applicant_user_id
  where app.group_id = p_group_id
    and applicant.account_status = 'active'
  order by
    case app.status
      when 'pending' then 0
      when 'accepted' then 1
      when 'rejected' then 2
      else 3
    end,
    app.created_at desc;
end;
$$;

create or replace function public.accept_recruitment_application(
  p_application_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_id uuid := public.current_user_id();
  v_application public.recruitment_applications%rowtype;
begin
  if v_actor_id is null then
    raise exception 'sign in is required';
  end if;

  select * into v_application
  from public.recruitment_applications
  where id = p_application_id
  for update;

  if not found then
    raise exception 'recruitment application not found';
  end if;

  if not public.is_group_admin(v_application.group_id) then
    raise exception 'only group admins can accept recruitment applications';
  end if;

  if v_application.status <> 'pending' then
    raise exception 'only pending applications can be accepted';
  end if;

  if not exists (
    select 1
    from public.users profile
    where profile.id = v_application.applicant_user_id
      and profile.account_status = 'active'
  ) then
    raise exception 'active applicant profile is required';
  end if;

  update public.recruitment_applications
  set
    status = 'accepted',
    responded_at = now(),
    responded_by = v_actor_id
  where id = v_application.id;

  insert into public.group_members (
    user_id,
    group_id,
    role
  )
  values (
    v_application.applicant_user_id,
    v_application.group_id,
    'member'
  )
  on conflict (user_id, group_id) do nothing;

  return v_application.id;
end;
$$;

create or replace function public.reject_recruitment_application(
  p_application_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_id uuid := public.current_user_id();
  v_application public.recruitment_applications%rowtype;
begin
  if v_actor_id is null then
    raise exception 'sign in is required';
  end if;

  select * into v_application
  from public.recruitment_applications
  where id = p_application_id
  for update;

  if not found then
    raise exception 'recruitment application not found';
  end if;

  if not public.is_group_admin(v_application.group_id) then
    raise exception 'only group admins can reject recruitment applications';
  end if;

  if v_application.status <> 'pending' then
    raise exception 'only pending applications can be rejected';
  end if;

  update public.recruitment_applications
  set
    status = 'rejected',
    responded_at = now(),
    responded_by = v_actor_id
  where id = v_application.id;

  return v_application.id;
end;
$$;

revoke all on function public.get_my_recruitment_application_state(uuid)
  from public, anon;
revoke all on function public.apply_to_recruitment_post(uuid, text)
  from public, anon;
revoke all on function public.get_my_group_recruitment_applications(uuid)
  from public, anon;
revoke all on function public.accept_recruitment_application(uuid)
  from public, anon;
revoke all on function public.reject_recruitment_application(uuid)
  from public, anon;

grant execute on function public.get_my_recruitment_application_state(uuid)
  to authenticated;
grant execute on function public.apply_to_recruitment_post(uuid, text)
  to authenticated;
grant execute on function public.get_my_group_recruitment_applications(uuid)
  to authenticated;
grant execute on function public.accept_recruitment_application(uuid)
  to authenticated;
grant execute on function public.reject_recruitment_application(uuid)
  to authenticated;

notify pgrst, 'reload schema';

commit;

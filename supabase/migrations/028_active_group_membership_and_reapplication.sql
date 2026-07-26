-- Preserve group membership history and allow recruitment reapplication after
-- a member leaves or is removed. Only active memberships count as joined.
-- Historical applications remain intact; only duplicate pending applications
-- are prevented. Run after 027_user_block_and_report_safety.sql.

begin;

alter table public.group_members
  add column if not exists membership_status text;
alter table public.group_members
  add column if not exists left_at timestamptz;
alter table public.group_members
  add column if not exists removed_by uuid
    references public.users(id) on delete set null;

update public.group_members
set membership_status = 'active'
where membership_status is null;

alter table public.group_members
  alter column membership_status set default 'active';
alter table public.group_members
  alter column membership_status set not null;

alter table public.group_members
  drop constraint if exists group_members_membership_status_check;
alter table public.group_members
  add constraint group_members_membership_status_check
  check (membership_status in ('active', 'left', 'removed'));

create index if not exists group_members_active_group_idx
  on public.group_members (group_id, role, user_id)
  where membership_status = 'active';

do $migration$
declare
  v_constraint_name text;
begin
  select constraint_row.conname into v_constraint_name
  from pg_constraint constraint_row
  where constraint_row.conrelid =
      'public.recruitment_applications'::regclass
    and constraint_row.contype = 'u'
    and pg_get_constraintdef(constraint_row.oid) =
      'UNIQUE (recruitment_post_id, applicant_user_id)'
  limit 1;

  if v_constraint_name is not null then
    execute format(
      'alter table public.recruitment_applications drop constraint %I',
      v_constraint_name
    );
  end if;
end;
$migration$;

create unique index if not exists
  recruitment_applications_one_pending_per_post_user
  on public.recruitment_applications (
    recruitment_post_id,
    applicant_user_id
  )
  where status = 'pending';

create or replace function public.is_group_admin(
  p_group_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.group_members member
    where member.group_id = p_group_id
      and member.user_id = public.current_user_id()
      and member.role = 'admin'
      and member.membership_status = 'active'
  );
$$;

drop policy if exists group_members_read on public.group_members;
create policy group_members_read on public.group_members
  for select to authenticated
  using (
    (
      membership_status = 'active'
      and exists (
        select 1
        from public.groups g
        where g.id = group_id
          and g.account_status = 'active'
      )
    )
    or user_id = public.current_user_id()
    or public.is_group_admin(group_id)
    or public.is_admin()
  );

drop policy if exists group_members_insert_admin on public.group_members;
create policy group_members_insert_admin on public.group_members
  for insert to authenticated
  with check (
    membership_status = 'active'
    and left_at is null
    and removed_by is null
    and (
      public.is_group_admin(group_id)
      or public.can_initialize_group_member(group_id, user_id, role)
    )
  );

drop policy if exists group_members_delete_member_or_admin
  on public.group_members;

create or replace function public.leave_group(
  p_group_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
  v_role text;
begin
  if v_user_id is null then
    raise exception 'sign in is required';
  end if;

  if p_group_id is null
    or not exists (
      select 1
      from public.groups g
      where g.id = p_group_id
        and g.account_status = 'active'
    ) then
    raise exception 'active group not found';
  end if;

  select member.role into v_role
  from public.group_members member
  where member.group_id = p_group_id
    and member.user_id = v_user_id
    and member.membership_status = 'active'
  for update;

  if v_role is null then
    raise exception 'active group membership not found';
  end if;

  if v_role = 'admin' then
    raise exception 'admin group leave is not supported yet';
  end if;

  update public.group_members
  set
    membership_status = 'left',
    left_at = now(),
    removed_by = null
  where group_id = p_group_id
    and user_id = v_user_id
    and role = 'member'
    and membership_status = 'active';

  return p_group_id;
end;
$$;

create or replace function public.remove_group_member(
  p_group_id uuid,
  p_member_user_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_id uuid := public.current_user_id();
  v_target_role text;
begin
  if v_actor_id is null then
    raise exception 'sign in is required';
  end if;

  if p_group_id is null
    or p_member_user_id is null
    or not exists (
      select 1
      from public.groups g
      where g.id = p_group_id
        and g.account_status = 'active'
    ) then
    raise exception 'active group or member not found';
  end if;

  if not public.is_group_admin(p_group_id) then
    raise exception 'only group admins can remove members';
  end if;

  select member.role into v_target_role
  from public.group_members member
  where member.group_id = p_group_id
    and member.user_id = p_member_user_id
    and member.membership_status = 'active'
  for update;

  if v_target_role is null then
    raise exception 'active target membership not found';
  end if;

  if v_target_role <> 'member' then
    raise exception 'only regular members can be removed';
  end if;

  update public.group_members
  set
    membership_status = 'removed',
    left_at = now(),
    removed_by = v_actor_id
  where group_id = p_group_id
    and user_id = p_member_user_id
    and role = 'member'
    and membership_status = 'active';

  return p_member_user_id;
end;
$$;

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
  v_group_owner_id uuid;
  v_application_id uuid;
begin
  if v_user_id is null then
    return query select 'none'::text, null::uuid;
    return;
  end if;

  select post.group_id, g.created_by
  into v_group_id, v_group_owner_id
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
    from public.group_members member
    where member.group_id = v_group_id
      and member.user_id = v_user_id
      and member.membership_status = 'active'
  ) then
    return query select 'group_member'::text, null::uuid;
    return;
  end if;

  if public.has_block_relationship(v_user_id, v_group_owner_id) then
    return query select 'blocked'::text, null::uuid;
    return;
  end if;

  select application.id into v_application_id
  from public.recruitment_applications application
  where application.recruitment_post_id = p_post_id
    and application.applicant_user_id = v_user_id
    and application.status = 'pending'
  order by application.created_at desc
  limit 1;

  if v_application_id is not null then
    return query select 'pending'::text, v_application_id;
    return;
  end if;

  return query select 'none'::text, null::uuid;
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
  v_group_owner_id uuid;
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

  select post.group_id, g.created_by
  into v_group_id, v_group_owner_id
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
    from public.group_members member
    where member.group_id = v_group_id
      and member.user_id = v_user_id
      and member.membership_status = 'active'
  ) then
    raise exception 'active group members cannot apply to their own group';
  end if;

  if public.has_block_relationship(v_user_id, v_group_owner_id) then
    raise exception 'a block relationship prevents this application';
  end if;

  if exists (
    select 1
    from public.recruitment_applications application
    where application.recruitment_post_id = p_post_id
      and application.applicant_user_id = v_user_id
      and application.status = 'pending'
  ) then
    raise exception 'pending application already exists'
      using errcode = '23505';
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
  v_group_owner_id uuid;
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

  select g.created_by into v_group_owner_id
  from public.groups g
  where g.id = v_application.group_id
    and g.account_status = 'active';

  if v_group_owner_id is null then
    raise exception 'active group not found';
  end if;

  if public.has_block_relationship(
    v_application.applicant_user_id,
    v_group_owner_id
  ) then
    raise exception 'a block relationship prevents accepting this application';
  end if;

  if exists (
    select 1
    from public.group_members member
    where member.group_id = v_application.group_id
      and member.user_id = v_application.applicant_user_id
      and member.membership_status = 'active'
  ) then
    raise exception 'applicant is already an active group member';
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
    role,
    membership_status,
    joined_at,
    left_at,
    removed_by
  )
  values (
    v_application.applicant_user_id,
    v_application.group_id,
    'member',
    'active',
    now(),
    null,
    null
  )
  on conflict (user_id, group_id) do update
  set
    role = 'member',
    membership_status = 'active',
    joined_at = now(),
    left_at = null,
    removed_by = null
  where group_members.role = 'member';

  return v_application.id;
end;
$$;

create or replace function public.get_my_group_profiles()
returns table (
  id uuid,
  created_by uuid,
  name text,
  bio text,
  activity_frequency text,
  account_status text,
  membership_role text,
  created_at timestamptz,
  updated_at timestamptz,
  genre_ids jsonb,
  genre_names jsonb,
  recruiting_part_ids jsonb,
  recruiting_part_names jsonb,
  area_ids jsonb,
  area_names jsonb
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

  return query
  select
    g.id,
    g.created_by,
    g.name,
    g.bio,
    g.activity_frequency,
    g.account_status,
    member.role as membership_role,
    g.created_at,
    g.updated_at,
    coalesce((
      select jsonb_agg(gg.genre_id order by genre.sort_order)
      from public.group_genres gg
      join public.genres genre on genre.id = gg.genre_id and genre.is_active
      where gg.group_id = g.id
    ), '[]'::jsonb) as genre_ids,
    coalesce((
      select jsonb_agg(genre.name order by genre.sort_order)
      from public.group_genres gg
      join public.genres genre on genre.id = gg.genre_id and genre.is_active
      where gg.group_id = g.id
    ), '[]'::jsonb) as genre_names,
    coalesce((
      select jsonb_agg(gp.part_id order by part.sort_order)
      from public.group_recruiting_parts gp
      join public.parts part on part.id = gp.part_id and part.is_active
      where gp.group_id = g.id
    ), '[]'::jsonb) as recruiting_part_ids,
    coalesce((
      select jsonb_agg(part.name order by part.sort_order)
      from public.group_recruiting_parts gp
      join public.parts part on part.id = gp.part_id and part.is_active
      where gp.group_id = g.id
    ), '[]'::jsonb) as recruiting_part_names,
    coalesce((
      select jsonb_agg(ga.area_id order by area.sort_order, area.name)
      from public.group_areas ga
      join public.areas area on area.id = ga.area_id and area.is_active
      where ga.group_id = g.id
    ), '[]'::jsonb) as area_ids,
    coalesce((
      select jsonb_agg(area.name order by area.sort_order, area.name)
      from public.group_areas ga
      join public.areas area on area.id = ga.area_id and area.is_active
      where ga.group_id = g.id
    ), '[]'::jsonb) as area_names
  from public.group_members member
  join public.groups g on g.id = member.group_id
  where member.user_id = v_user_id
    and member.role in ('admin', 'member')
    and member.membership_status = 'active'
    and g.account_status = 'active'
  order by
    case member.role when 'admin' then 0 else 1 end,
    g.updated_at desc,
    g.created_at desc;
end;
$$;

create or replace function public.get_group_members(
  p_group_id uuid
)
returns table (
  user_id uuid,
  display_name text,
  avatar_url text,
  experience_level text,
  part_names jsonb,
  genre_names jsonb,
  role text,
  joined_at timestamptz,
  created_at timestamptz
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

  if p_group_id is null
    or not exists (
      select 1
      from public.groups g
      where g.id = p_group_id
        and g.account_status = 'active'
    ) then
    raise exception 'active group not found';
  end if;

  if not exists (
    select 1
    from public.group_members self_member
    where self_member.group_id = p_group_id
      and self_member.user_id = v_user_id
      and self_member.role in ('admin', 'member')
      and self_member.membership_status = 'active'
  ) then
    raise exception 'only active group members can read the member list';
  end if;

  return query
  select
    member.user_id,
    profile.display_name,
    profile.avatar_url,
    profile.experience_level,
    coalesce((
      select jsonb_agg(part.name order by part.sort_order)
      from public.user_parts up
      join public.parts part on part.id = up.part_id and part.is_active
      where up.user_id = profile.id
    ), '[]'::jsonb) as part_names,
    coalesce((
      select jsonb_agg(genre.name order by genre.sort_order)
      from public.user_genres ug
      join public.genres genre on genre.id = ug.genre_id and genre.is_active
      where ug.user_id = profile.id
    ), '[]'::jsonb) as genre_names,
    member.role,
    member.joined_at,
    member.created_at
  from public.group_members member
  join public.users profile on profile.id = member.user_id
  where member.group_id = p_group_id
    and member.role in ('admin', 'member')
    and member.membership_status = 'active'
    and profile.account_status = 'active'
  order by
    case member.role when 'admin' then 0 else 1 end,
    member.joined_at asc,
    profile.display_name asc;
end;
$$;

revoke all on function public.is_group_admin(uuid) from public, anon;
revoke all on function public.leave_group(uuid) from public, anon;
revoke all on function public.remove_group_member(uuid, uuid)
  from public, anon;
revoke all on function public.get_my_recruitment_application_state(uuid)
  from public, anon;
revoke all on function public.apply_to_recruitment_post(uuid, text)
  from public, anon;
revoke all on function public.accept_recruitment_application(uuid)
  from public, anon;
revoke all on function public.get_my_group_profiles() from public, anon;
revoke all on function public.get_group_members(uuid) from public, anon;

grant execute on function public.is_group_admin(uuid) to authenticated;
grant execute on function public.leave_group(uuid) to authenticated;
grant execute on function public.remove_group_member(uuid, uuid)
  to authenticated;
grant execute on function public.get_my_recruitment_application_state(uuid)
  to authenticated;
grant execute on function public.apply_to_recruitment_post(uuid, text)
  to authenticated;
grant execute on function public.accept_recruitment_application(uuid)
  to authenticated;
grant execute on function public.get_my_group_profiles() to authenticated;
grant execute on function public.get_group_members(uuid) to authenticated;

notify pgrst, 'reload schema';

commit;

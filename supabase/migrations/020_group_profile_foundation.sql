-- Basic signed-in user's group/band profile foundation.
-- Reuses existing groups, group_members, group_genres, and
-- group_recruiting_parts tables. Adds a minimal group_areas join table for
-- the group's activity areas. This migration does not add group search,
-- group chat, invitations, recruitment posts, or group image upload.
-- Run after 019_profile_avatar_storage.sql.

begin;

create table if not exists public.group_areas (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  area_id uuid not null references public.areas(id) on delete restrict,
  show_on_profile boolean not null default true,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (group_id, area_id)
);

create unique index if not exists group_areas_one_primary_per_group
  on public.group_areas (group_id)
  where is_primary;
create index if not exists group_areas_area_idx
  on public.group_areas (area_id, group_id);

alter table public.group_areas enable row level security;

drop trigger if exists set_updated_at on public.group_areas;
create trigger set_updated_at
before update on public.group_areas
for each row execute function public.set_updated_at();

drop policy if exists group_areas_read on public.group_areas;
create policy group_areas_read on public.group_areas
  for select to authenticated
  using (
    exists (
      select 1
      from public.groups g
      where g.id = group_id and g.account_status = 'active'
    )
    or public.is_group_admin(group_id)
    or public.is_admin()
  );

drop policy if exists group_areas_write on public.group_areas;
create policy group_areas_write on public.group_areas
  for all to authenticated
  using (public.is_group_admin(group_id) or public.is_admin())
  with check (public.is_group_admin(group_id) or public.is_admin());

create or replace function public.assert_active_master_ids(
  p_table_name text,
  p_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_expected_count integer := coalesce(array_length(p_ids, 1), 0);
  v_actual_count integer;
begin
  if v_expected_count = 0 then
    return;
  end if;

  if p_table_name = 'parts' then
    select count(*) into v_actual_count
    from public.parts
    where id = any(p_ids) and is_active;
  elsif p_table_name = 'genres' then
    select count(*) into v_actual_count
    from public.genres
    where id = any(p_ids) and is_active;
  elsif p_table_name = 'areas' then
    select count(*) into v_actual_count
    from public.areas
    where id = any(p_ids) and is_active;
  else
    raise exception 'unsupported master table';
  end if;

  if v_actual_count <> v_expected_count then
    raise exception 'inactive or invalid master data id';
  end if;
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
  from public.groups g
  join public.group_members gm on gm.group_id = g.id
  where gm.user_id = v_user_id
    and gm.role = 'admin'
    and g.account_status = 'active'
  order by g.updated_at desc, g.created_at desc;
end;
$$;

create or replace function public.create_my_group_profile(
  p_name text,
  p_bio text default null,
  p_genre_ids uuid[] default '{}',
  p_recruiting_part_ids uuid[] default '{}',
  p_area_ids uuid[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
  v_name text := btrim(coalesce(p_name, ''));
  v_bio text := nullif(btrim(coalesce(p_bio, '')), '');
  v_group_id uuid;
  v_genre_ids uuid[] := coalesce(p_genre_ids, '{}');
  v_part_ids uuid[] := coalesce(p_recruiting_part_ids, '{}');
  v_area_ids uuid[] := coalesce(p_area_ids, '{}');
begin
  if v_user_id is null then
    raise exception 'sign in is required';
  end if;
  if not exists (
    select 1 from public.users
    where id = v_user_id and account_status = 'active'
  ) then
    raise exception 'active profile is required';
  end if;
  if char_length(v_name) not between 1 and 60 then
    raise exception 'group name must be between 1 and 60 characters';
  end if;
  if v_bio is not null and char_length(v_bio) > 1000 then
    raise exception 'group bio must be 1000 characters or fewer';
  end if;

  perform public.assert_active_master_ids('genres', v_genre_ids);
  perform public.assert_active_master_ids('parts', v_part_ids);
  perform public.assert_active_master_ids('areas', v_area_ids);

  insert into public.groups (
    created_by,
    name,
    bio,
    account_status,
    premium_boost,
    is_recruiting
  )
  values (
    v_user_id,
    v_name,
    v_bio,
    'active',
    1.00,
    coalesce(array_length(v_part_ids, 1), 0) > 0
  )
  returning id into v_group_id;

  insert into public.group_members (user_id, group_id, role)
  values (v_user_id, v_group_id, 'admin');

  insert into public.group_genres (group_id, genre_id)
  select v_group_id, unnest(v_genre_ids);

  insert into public.group_recruiting_parts (group_id, part_id)
  select v_group_id, unnest(v_part_ids);

  insert into public.group_areas (group_id, area_id, is_primary)
  select v_group_id, selected.area_id, selected.ordinal = 1
  from unnest(v_area_ids) with ordinality as selected(area_id, ordinal);

  return v_group_id;
end;
$$;

create or replace function public.update_my_group_profile(
  p_group_id uuid,
  p_name text,
  p_bio text default null,
  p_genre_ids uuid[] default '{}',
  p_recruiting_part_ids uuid[] default '{}',
  p_area_ids uuid[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
  v_name text := btrim(coalesce(p_name, ''));
  v_bio text := nullif(btrim(coalesce(p_bio, '')), '');
  v_genre_ids uuid[] := coalesce(p_genre_ids, '{}');
  v_part_ids uuid[] := coalesce(p_recruiting_part_ids, '{}');
  v_area_ids uuid[] := coalesce(p_area_ids, '{}');
begin
  if v_user_id is null then
    raise exception 'sign in is required';
  end if;
  if p_group_id is null
    or not exists (
      select 1 from public.groups
      where id = p_group_id and account_status = 'active'
    ) then
    raise exception 'active group not found';
  end if;
  if not public.is_group_admin(p_group_id) then
    raise exception 'only group admins can update this group';
  end if;
  if char_length(v_name) not between 1 and 60 then
    raise exception 'group name must be between 1 and 60 characters';
  end if;
  if v_bio is not null and char_length(v_bio) > 1000 then
    raise exception 'group bio must be 1000 characters or fewer';
  end if;

  perform public.assert_active_master_ids('genres', v_genre_ids);
  perform public.assert_active_master_ids('parts', v_part_ids);
  perform public.assert_active_master_ids('areas', v_area_ids);

  update public.groups
  set
    name = v_name,
    bio = v_bio,
    is_recruiting = coalesce(array_length(v_part_ids, 1), 0) > 0
  where id = p_group_id;

  delete from public.group_genres where group_id = p_group_id;
  insert into public.group_genres (group_id, genre_id)
  select p_group_id, unnest(v_genre_ids);

  delete from public.group_recruiting_parts where group_id = p_group_id;
  insert into public.group_recruiting_parts (group_id, part_id)
  select p_group_id, unnest(v_part_ids);

  delete from public.group_areas where group_id = p_group_id;
  insert into public.group_areas (group_id, area_id, is_primary)
  select p_group_id, selected.area_id, selected.ordinal = 1
  from unnest(v_area_ids) with ordinality as selected(area_id, ordinal);

  return p_group_id;
end;
$$;

revoke all on function public.assert_active_master_ids(text, uuid[])
  from public, anon;
revoke all on function public.get_my_group_profiles() from public, anon;
revoke all on function public.create_my_group_profile(
  text, text, uuid[], uuid[], uuid[]
) from public, anon;
revoke all on function public.update_my_group_profile(
  uuid, text, text, uuid[], uuid[], uuid[]
) from public, anon;

grant execute on function public.get_my_group_profiles() to authenticated;
grant execute on function public.create_my_group_profile(
  text, text, uuid[], uuid[], uuid[]
) to authenticated;
grant execute on function public.update_my_group_profile(
  uuid, text, text, uuid[], uuid[], uuid[]
) to authenticated;

notify pgrst, 'reload schema';

commit;

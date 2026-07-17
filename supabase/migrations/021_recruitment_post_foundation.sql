-- Basic recruitment-post foundation for signed-in group admins.
-- This migration adds private owner/admin management of recruitment posts
-- attached to groups. It does not add public recruitment search,
-- application flow, group chat, notifications, realtime, or read receipts.
-- Run after 020_group_profile_foundation.sql.

begin;

create table if not exists public.recruitment_posts (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  body text not null check (char_length(body) between 1 and 2000),
  status text not null default 'open'
    check (status in ('draft', 'open', 'closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.recruitment_post_parts (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.recruitment_posts(id)
    on delete cascade,
  part_id uuid not null references public.parts(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (post_id, part_id)
);

create table if not exists public.recruitment_post_genres (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.recruitment_posts(id)
    on delete cascade,
  genre_id uuid not null references public.genres(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (post_id, genre_id)
);

create table if not exists public.recruitment_post_areas (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.recruitment_posts(id)
    on delete cascade,
  area_id uuid not null references public.areas(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (post_id, area_id)
);

create index if not exists recruitment_posts_group_status_idx
  on public.recruitment_posts (group_id, status, updated_at desc);
create index if not exists recruitment_post_parts_part_idx
  on public.recruitment_post_parts (part_id, post_id);
create index if not exists recruitment_post_genres_genre_idx
  on public.recruitment_post_genres (genre_id, post_id);
create index if not exists recruitment_post_areas_area_idx
  on public.recruitment_post_areas (area_id, post_id);

alter table public.recruitment_posts enable row level security;
alter table public.recruitment_post_parts enable row level security;
alter table public.recruitment_post_genres enable row level security;
alter table public.recruitment_post_areas enable row level security;

drop trigger if exists set_updated_at on public.recruitment_posts;
create trigger set_updated_at
before update on public.recruitment_posts
for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at on public.recruitment_post_parts;
create trigger set_updated_at
before update on public.recruitment_post_parts
for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at on public.recruitment_post_genres;
create trigger set_updated_at
before update on public.recruitment_post_genres
for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at on public.recruitment_post_areas;
create trigger set_updated_at
before update on public.recruitment_post_areas
for each row execute function public.set_updated_at();

drop policy if exists recruitment_posts_admin_manage
  on public.recruitment_posts;
create policy recruitment_posts_admin_manage on public.recruitment_posts
  for all to authenticated
  using (public.is_group_admin(group_id) or public.is_admin())
  with check (public.is_group_admin(group_id) or public.is_admin());

drop policy if exists recruitment_post_parts_admin_manage
  on public.recruitment_post_parts;
create policy recruitment_post_parts_admin_manage
  on public.recruitment_post_parts
  for all to authenticated
  using (
    exists (
      select 1
      from public.recruitment_posts post
      where post.id = post_id
        and (public.is_group_admin(post.group_id) or public.is_admin())
    )
  )
  with check (
    exists (
      select 1
      from public.recruitment_posts post
      where post.id = post_id
        and (public.is_group_admin(post.group_id) or public.is_admin())
    )
  );

drop policy if exists recruitment_post_genres_admin_manage
  on public.recruitment_post_genres;
create policy recruitment_post_genres_admin_manage
  on public.recruitment_post_genres
  for all to authenticated
  using (
    exists (
      select 1
      from public.recruitment_posts post
      where post.id = post_id
        and (public.is_group_admin(post.group_id) or public.is_admin())
    )
  )
  with check (
    exists (
      select 1
      from public.recruitment_posts post
      where post.id = post_id
        and (public.is_group_admin(post.group_id) or public.is_admin())
    )
  );

drop policy if exists recruitment_post_areas_admin_manage
  on public.recruitment_post_areas;
create policy recruitment_post_areas_admin_manage
  on public.recruitment_post_areas
  for all to authenticated
  using (
    exists (
      select 1
      from public.recruitment_posts post
      where post.id = post_id
        and (public.is_group_admin(post.group_id) or public.is_admin())
    )
  )
  with check (
    exists (
      select 1
      from public.recruitment_posts post
      where post.id = post_id
        and (public.is_group_admin(post.group_id) or public.is_admin())
    )
  );

create or replace function public.get_my_group_recruitment_posts(
  p_group_id uuid
)
returns table (
  id uuid,
  group_id uuid,
  title text,
  body text,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  wanted_part_ids jsonb,
  wanted_part_names jsonb,
  genre_ids jsonb,
  genre_names jsonb,
  area_ids jsonb,
  area_names jsonb
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
      where g.id = p_group_id and g.account_status = 'active'
    ) then
    raise exception 'active group not found';
  end if;

  if not public.is_group_admin(p_group_id) then
    raise exception 'only group admins can read recruitment posts';
  end if;

  return query
  select
    post.id,
    post.group_id,
    post.title,
    post.body,
    post.status,
    post.created_at,
    post.updated_at,
    coalesce((
      select jsonb_agg(rpp.part_id order by part.sort_order)
      from public.recruitment_post_parts rpp
      join public.parts part on part.id = rpp.part_id and part.is_active
      where rpp.post_id = post.id
    ), '[]'::jsonb) as wanted_part_ids,
    coalesce((
      select jsonb_agg(part.name order by part.sort_order)
      from public.recruitment_post_parts rpp
      join public.parts part on part.id = rpp.part_id and part.is_active
      where rpp.post_id = post.id
    ), '[]'::jsonb) as wanted_part_names,
    coalesce((
      select jsonb_agg(rpg.genre_id order by genre.sort_order)
      from public.recruitment_post_genres rpg
      join public.genres genre on genre.id = rpg.genre_id and genre.is_active
      where rpg.post_id = post.id
    ), '[]'::jsonb) as genre_ids,
    coalesce((
      select jsonb_agg(genre.name order by genre.sort_order)
      from public.recruitment_post_genres rpg
      join public.genres genre on genre.id = rpg.genre_id and genre.is_active
      where rpg.post_id = post.id
    ), '[]'::jsonb) as genre_names,
    coalesce((
      select jsonb_agg(rpa.area_id order by area.sort_order, area.name)
      from public.recruitment_post_areas rpa
      join public.areas area on area.id = rpa.area_id and area.is_active
      where rpa.post_id = post.id
    ), '[]'::jsonb) as area_ids,
    coalesce((
      select jsonb_agg(area.name order by area.sort_order, area.name)
      from public.recruitment_post_areas rpa
      join public.areas area on area.id = rpa.area_id and area.is_active
      where rpa.post_id = post.id
    ), '[]'::jsonb) as area_names
  from public.recruitment_posts post
  where post.group_id = p_group_id
  order by post.updated_at desc, post.created_at desc;
end;
$$;

create or replace function public.create_my_group_recruitment_post(
  p_group_id uuid,
  p_title text,
  p_body text,
  p_status text default 'open',
  p_wanted_part_ids uuid[] default '{}',
  p_genre_ids uuid[] default '{}',
  p_area_ids uuid[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_title text := btrim(coalesce(p_title, ''));
  v_body text := btrim(coalesce(p_body, ''));
  v_status text := coalesce(nullif(btrim(coalesce(p_status, '')), ''), 'open');
  v_part_ids uuid[] := coalesce(p_wanted_part_ids, '{}');
  v_genre_ids uuid[] := coalesce(p_genre_ids, '{}');
  v_area_ids uuid[] := coalesce(p_area_ids, '{}');
  v_post_id uuid;
begin
  if p_group_id is null
    or not exists (
      select 1
      from public.groups g
      where g.id = p_group_id and g.account_status = 'active'
    ) then
    raise exception 'active group not found';
  end if;
  if not public.is_group_admin(p_group_id) then
    raise exception 'only group admins can create recruitment posts';
  end if;
  if char_length(v_title) not between 1 and 80 then
    raise exception 'title must be between 1 and 80 characters';
  end if;
  if char_length(v_body) not between 1 and 2000 then
    raise exception 'body must be between 1 and 2000 characters';
  end if;
  if v_status not in ('draft', 'open', 'closed') then
    raise exception 'invalid recruitment post status';
  end if;

  perform public.assert_active_master_ids('parts', v_part_ids);
  perform public.assert_active_master_ids('genres', v_genre_ids);
  perform public.assert_active_master_ids('areas', v_area_ids);

  insert into public.recruitment_posts (
    group_id,
    title,
    body,
    status
  )
  values (
    p_group_id,
    v_title,
    v_body,
    v_status
  )
  returning id into v_post_id;

  insert into public.recruitment_post_parts (post_id, part_id)
  select v_post_id, unnest(v_part_ids);

  insert into public.recruitment_post_genres (post_id, genre_id)
  select v_post_id, unnest(v_genre_ids);

  insert into public.recruitment_post_areas (post_id, area_id)
  select v_post_id, unnest(v_area_ids);

  return v_post_id;
end;
$$;

create or replace function public.update_my_group_recruitment_post(
  p_post_id uuid,
  p_title text,
  p_body text,
  p_status text default 'open',
  p_wanted_part_ids uuid[] default '{}',
  p_genre_ids uuid[] default '{}',
  p_area_ids uuid[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_group_id uuid;
  v_title text := btrim(coalesce(p_title, ''));
  v_body text := btrim(coalesce(p_body, ''));
  v_status text := coalesce(nullif(btrim(coalesce(p_status, '')), ''), 'open');
  v_part_ids uuid[] := coalesce(p_wanted_part_ids, '{}');
  v_genre_ids uuid[] := coalesce(p_genre_ids, '{}');
  v_area_ids uuid[] := coalesce(p_area_ids, '{}');
begin
  select post.group_id into v_group_id
  from public.recruitment_posts post
  join public.groups g on g.id = post.group_id
  where post.id = p_post_id
    and g.account_status = 'active';

  if v_group_id is null then
    raise exception 'active recruitment post not found';
  end if;
  if not public.is_group_admin(v_group_id) then
    raise exception 'only group admins can update recruitment posts';
  end if;
  if char_length(v_title) not between 1 and 80 then
    raise exception 'title must be between 1 and 80 characters';
  end if;
  if char_length(v_body) not between 1 and 2000 then
    raise exception 'body must be between 1 and 2000 characters';
  end if;
  if v_status not in ('draft', 'open', 'closed') then
    raise exception 'invalid recruitment post status';
  end if;

  perform public.assert_active_master_ids('parts', v_part_ids);
  perform public.assert_active_master_ids('genres', v_genre_ids);
  perform public.assert_active_master_ids('areas', v_area_ids);

  update public.recruitment_posts
  set
    title = v_title,
    body = v_body,
    status = v_status
  where id = p_post_id;

  delete from public.recruitment_post_parts where post_id = p_post_id;
  insert into public.recruitment_post_parts (post_id, part_id)
  select p_post_id, unnest(v_part_ids);

  delete from public.recruitment_post_genres where post_id = p_post_id;
  insert into public.recruitment_post_genres (post_id, genre_id)
  select p_post_id, unnest(v_genre_ids);

  delete from public.recruitment_post_areas where post_id = p_post_id;
  insert into public.recruitment_post_areas (post_id, area_id)
  select p_post_id, unnest(v_area_ids);

  return p_post_id;
end;
$$;

revoke all on function public.get_my_group_recruitment_posts(uuid)
  from public, anon;
revoke all on function public.create_my_group_recruitment_post(
  uuid, text, text, text, uuid[], uuid[], uuid[]
) from public, anon;
revoke all on function public.update_my_group_recruitment_post(
  uuid, text, text, text, uuid[], uuid[], uuid[]
) from public, anon;

grant execute on function public.get_my_group_recruitment_posts(uuid)
  to authenticated;
grant execute on function public.create_my_group_recruitment_post(
  uuid, text, text, text, uuid[], uuid[], uuid[]
) to authenticated;
grant execute on function public.update_my_group_recruitment_post(
  uuid, text, text, text, uuid[], uuid[], uuid[]
) to authenticated;

notify pgrst, 'reload schema';

commit;

-- Safe STAGE dance-studio discovery foundation.
-- Only authenticated active profiles can read verified, published, active
-- studios through the two versioned RPCs below. Direct client table access,
-- recommendations, maps, route calculation, booking, and payment are out of
-- scope. Run after 037_stage_event_discovery.sql.

begin;

create table public.stage_studios (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 120),
  area_id uuid references public.areas(id) on delete restrict,
  address_display text not null
    check (char_length(btrim(address_display)) between 1 and 300),
  latitude numeric(9, 6),
  longitude numeric(9, 6),
  nearest_station_name text
    check (nearest_station_name is null or char_length(btrim(nearest_station_name)) between 1 and 120),
  walking_minutes smallint
    check (walking_minutes is null or walking_minutes between 0 and 120),
  access_note text check (access_note is null or char_length(access_note) <= 300),
  opening_hours_summary text
    check (opening_hours_summary is null or char_length(opening_hours_summary) <= 300),
  minimum_hourly_price_yen integer
    check (minimum_hourly_price_yen is null or minimum_hourly_price_yen >= 0),
  website_url text check (
    website_url is null
    or (
      char_length(website_url) <= 2000
      and website_url ~* '^https://[^[:space:]]+$'
    )
  ),
  booking_url text check (
    booking_url is null
    or (
      char_length(booking_url) <= 2000
      and booking_url ~* '^https://[^[:space:]]+$'
    )
  ),
  review_summary text
    check (review_summary is null or char_length(review_summary) <= 500),
  rating numeric(2, 1) check (rating is null or rating between 0 and 5),
  rating_count integer not null default 0 check (rating_count >= 0),
  source_label text not null
    check (char_length(btrim(source_label)) between 1 and 120),
  source_url text not null check (
    char_length(source_url) <= 2000
    and source_url ~* '^https://[^[:space:]]+$'
  ),
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified', 'verified')),
  publication_status text not null default 'draft'
    check (publication_status in ('draft', 'published', 'archived')),
  operational_status text not null default 'active'
    check (operational_status in ('active', 'temporarily_closed', 'closed')),
  last_verified_at timestamptz not null,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stage_studios_coordinates_together check (
    (latitude is null and longitude is null)
    or (latitude is not null and longitude is not null)
  ),
  constraint stage_studios_latitude_range check (
    latitude is null or latitude between -90 and 90
  ),
  constraint stage_studios_longitude_range check (
    longitude is null or longitude between -180 and 180
  ),
  constraint stage_studios_published_state check (
    publication_status <> 'published'
    or (
      published_at is not null
      and (booking_url is not null or website_url is not null)
    )
  )
);

create table public.stage_studio_rooms (
  id uuid primary key default gen_random_uuid(),
  studio_id uuid not null
    references public.stage_studios(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  capacity integer check (capacity is null or capacity between 1 and 500),
  size_sqm numeric(8, 2) check (size_sqm is null or size_sqm > 0),
  hourly_price_yen integer
    check (hourly_price_yen is null or hourly_price_yen >= 0),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (studio_id, name)
);

create table public.stage_studio_facilities (
  id uuid primary key default gen_random_uuid(),
  code text not null unique
    check (code ~ '^[a-z][a-z0-9_]{0,49}$'),
  name text not null unique
    check (char_length(btrim(name)) between 1 and 80),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.stage_studio_room_facilities (
  room_id uuid not null
    references public.stage_studio_rooms(id) on delete cascade,
  facility_id uuid not null
    references public.stage_studio_facilities(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (room_id, facility_id)
);

create index stage_studios_discovery_idx
  on public.stage_studios (
    publication_status,
    verification_status,
    operational_status,
    area_id,
    name,
    id
  );
create index stage_studio_rooms_studio_idx
  on public.stage_studio_rooms (studio_id, is_active, sort_order, id);
create index stage_studio_room_facilities_facility_idx
  on public.stage_studio_room_facilities (facility_id, room_id);

create trigger set_updated_at
before update on public.stage_studios
for each row execute function public.set_updated_at();

create trigger set_updated_at
before update on public.stage_studio_rooms
for each row execute function public.set_updated_at();

create trigger set_updated_at
before update on public.stage_studio_facilities
for each row execute function public.set_updated_at();

alter table public.stage_studios enable row level security;
alter table public.stage_studio_rooms enable row level security;
alter table public.stage_studio_facilities enable row level security;
alter table public.stage_studio_room_facilities enable row level security;

create policy stage_studios_admin_all
  on public.stage_studios
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy stage_studio_rooms_admin_all
  on public.stage_studio_rooms
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy stage_studio_facilities_admin_all
  on public.stage_studio_facilities
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy stage_studio_room_facilities_admin_all
  on public.stage_studio_room_facilities
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create or replace function public.get_stage_studios_v1()
returns table (
  studio_id uuid,
  name text,
  area_id uuid,
  area_name text,
  address_display text,
  latitude numeric,
  longitude numeric,
  nearest_station_name text,
  walking_minutes smallint,
  access_note text,
  opening_hours_summary text,
  minimum_hourly_price_yen integer,
  website_url text,
  booking_url text,
  review_summary text,
  rating numeric,
  rating_count integer,
  source_label text,
  source_url text,
  last_verified_at timestamptz,
  room_count bigint,
  max_capacity integer,
  largest_room_size_sqm numeric,
  facility_names jsonb,
  room_summaries jsonb
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
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

  return query
  select
    studio.id as studio_id,
    studio.name,
    studio.area_id,
    area.name as area_name,
    studio.address_display,
    studio.latitude,
    studio.longitude,
    studio.nearest_station_name,
    studio.walking_minutes,
    studio.access_note,
    studio.opening_hours_summary,
    studio.minimum_hourly_price_yen,
    studio.website_url,
    studio.booking_url,
    studio.review_summary,
    studio.rating,
    studio.rating_count,
    studio.source_label,
    studio.source_url,
    studio.last_verified_at,
    (
      select count(*)
      from public.stage_studio_rooms room
      where room.studio_id = studio.id
        and room.is_active
    ) as room_count,
    (
      select max(room.capacity)
      from public.stage_studio_rooms room
      where room.studio_id = studio.id
        and room.is_active
    ) as max_capacity,
    (
      select max(room.size_sqm)
      from public.stage_studio_rooms room
      where room.studio_id = studio.id
        and room.is_active
    ) as largest_room_size_sqm,
    coalesce((
      select jsonb_agg(distinct facility.name order by facility.name)
      from public.stage_studio_rooms room
      join public.stage_studio_room_facilities room_facility
        on room_facility.room_id = room.id
      join public.stage_studio_facilities facility
        on facility.id = room_facility.facility_id
       and facility.is_active
      where room.studio_id = studio.id
        and room.is_active
    ), '[]'::jsonb) as facility_names,
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'room_id', room.id,
          'name', room.name,
          'capacity', room.capacity,
          'size_sqm', room.size_sqm,
          'hourly_price_yen', room.hourly_price_yen,
          'facility_names', coalesce((
            select jsonb_agg(facility.name order by facility.sort_order, facility.name)
            from public.stage_studio_room_facilities room_facility
            join public.stage_studio_facilities facility
              on facility.id = room_facility.facility_id
             and facility.is_active
            where room_facility.room_id = room.id
          ), '[]'::jsonb)
        )
        order by room.sort_order, room.name, room.id
      )
      from public.stage_studio_rooms room
      where room.studio_id = studio.id
        and room.is_active
    ), '[]'::jsonb) as room_summaries
  from public.stage_studios studio
  left join public.areas area
    on area.id = studio.area_id
   and area.is_active
  where studio.publication_status = 'published'
    and studio.published_at <= now()
    and studio.verification_status = 'verified'
    and studio.operational_status = 'active'
    and (studio.area_id is null or area.id is not null)
  order by area.sort_order nulls last, studio.name, studio.id
  limit 80;
end;
$$;

create or replace function public.get_stage_studio_detail_v1(
  p_studio_id uuid
)
returns table (
  studio_id uuid,
  name text,
  area_id uuid,
  area_name text,
  address_display text,
  latitude numeric,
  longitude numeric,
  nearest_station_name text,
  walking_minutes smallint,
  access_note text,
  opening_hours_summary text,
  minimum_hourly_price_yen integer,
  website_url text,
  booking_url text,
  review_summary text,
  rating numeric,
  rating_count integer,
  source_label text,
  source_url text,
  last_verified_at timestamptz,
  room_count bigint,
  max_capacity integer,
  largest_room_size_sqm numeric,
  facility_names jsonb,
  room_summaries jsonb
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
begin
  if v_user_id is null then
    raise exception 'sign in is required';
  end if;

  if p_studio_id is null then
    raise exception 'studio id is required';
  end if;

  if not exists (
    select 1
    from public.users profile
    where profile.id = v_user_id
      and profile.account_status = 'active'
  ) then
    raise exception 'active profile is required';
  end if;

  return query
  select *
  from public.get_stage_studios_v1() listed_studio
  where listed_studio.studio_id = p_studio_id;
end;
$$;

revoke all on public.stage_studios from public, anon, authenticated;
revoke all on public.stage_studio_rooms from public, anon, authenticated;
revoke all on public.stage_studio_facilities from public, anon, authenticated;
revoke all on public.stage_studio_room_facilities
  from public, anon, authenticated;

revoke all on function public.get_stage_studios_v1() from public, anon;
revoke all on function public.get_stage_studio_detail_v1(uuid)
  from public, anon;
grant execute on function public.get_stage_studios_v1() to authenticated;
grant execute on function public.get_stage_studio_detail_v1(uuid)
  to authenticated;

notify pgrst, 'reload schema';

commit;

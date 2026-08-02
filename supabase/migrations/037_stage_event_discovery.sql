-- Safe STAGE event/competition discovery foundation.
-- Only authenticated active profiles can read verified, published, current
-- Dance events through the two versioned RPCs below. Direct client table
-- access, event administration, lessons, booking, and payment are out of scope.
-- Run after 036_stage_crew_discovery.sql.

begin;

create table public.stage_event_organizers (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 120),
  official_url text check (
    official_url is null
    or (
      char_length(official_url) <= 2000
      and official_url ~* '^https://'
    )
  ),
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified', 'verified')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.stage_events (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null
    references public.stage_event_organizers(id) on delete restrict,
  title text not null check (char_length(btrim(title)) between 1 and 160),
  category text not null
    check (category in ('event', 'competition', 'showcase')),
  summary text not null check (char_length(btrim(summary)) between 1 and 3000),
  eligibility_summary text check (char_length(eligibility_summary) <= 500),
  venue_name text not null
    check (char_length(btrim(venue_name)) between 1 and 160),
  starts_at timestamptz not null,
  ends_at timestamptz,
  application_deadline timestamptz,
  fee_summary text check (char_length(fee_summary) <= 120),
  official_url text check (
    official_url is null
    or (
      char_length(official_url) <= 2000
      and official_url ~* '^https://'
    )
  ),
  source_url text not null check (
    char_length(source_url) <= 2000
    and source_url ~* '^https://'
  ),
  source_type text not null
    check (source_type in (
      'official_site',
      'organizer_submission',
      'operator_verified'
    )),
  last_verified_at timestamptz not null,
  event_status text not null default 'scheduled'
    check (event_status in (
      'scheduled',
      'applications_open',
      'applications_closed',
      'cancelled',
      'completed'
    )),
  publication_status text not null default 'draft'
    check (publication_status in ('draft', 'published', 'archived')),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stage_events_time_range check (
    ends_at is null or ends_at >= starts_at
  ),
  constraint stage_events_published_state check (
    publication_status <> 'published' or published_at is not null
  )
);

create table public.stage_event_genres (
  event_id uuid not null references public.stage_events(id) on delete cascade,
  genre_id uuid not null references public.genres(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (event_id, genre_id)
);

create table public.stage_event_areas (
  event_id uuid not null references public.stage_events(id) on delete cascade,
  area_id uuid not null references public.areas(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (event_id, area_id)
);

create index stage_events_discovery_idx
  on public.stage_events (publication_status, event_status, starts_at, id);
create index stage_event_genres_genre_idx
  on public.stage_event_genres (genre_id, event_id);
create index stage_event_areas_area_idx
  on public.stage_event_areas (area_id, event_id);

create trigger set_updated_at
before update on public.stage_event_organizers
for each row execute function public.set_updated_at();

create trigger set_updated_at
before update on public.stage_events
for each row execute function public.set_updated_at();

alter table public.stage_event_organizers enable row level security;
alter table public.stage_events enable row level security;
alter table public.stage_event_genres enable row level security;
alter table public.stage_event_areas enable row level security;

create policy stage_event_organizers_admin_all
  on public.stage_event_organizers
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy stage_events_admin_all
  on public.stage_events
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy stage_event_genres_admin_all
  on public.stage_event_genres
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy stage_event_areas_admin_all
  on public.stage_event_areas
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create or replace function public.get_stage_events_v1()
returns table (
  event_id uuid,
  organizer_id uuid,
  organizer_name text,
  organizer_official_url text,
  title text,
  category text,
  summary text,
  eligibility_summary text,
  venue_name text,
  starts_at timestamptz,
  ends_at timestamptz,
  application_deadline timestamptz,
  fee_summary text,
  official_url text,
  source_url text,
  source_type text,
  last_verified_at timestamptz,
  event_status text,
  dance_genre_names jsonb,
  area_names jsonb
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
    event.id as event_id,
    organizer.id as organizer_id,
    organizer.name as organizer_name,
    organizer.official_url as organizer_official_url,
    event.title,
    event.category,
    event.summary,
    event.eligibility_summary,
    event.venue_name,
    event.starts_at,
    event.ends_at,
    event.application_deadline,
    event.fee_summary,
    event.official_url,
    event.source_url,
    event.source_type,
    event.last_verified_at,
    event.event_status,
    coalesce((
      select jsonb_agg(genre.name order by genre.sort_order, genre.code)
      from public.stage_event_genres event_genre
      join public.genres genre
        on genre.id = event_genre.genre_id
       and genre.domain = 'dance'
       and genre.is_active
      where event_genre.event_id = event.id
    ), '[]'::jsonb) as dance_genre_names,
    coalesce((
      select jsonb_agg(area.name order by area.sort_order, area.name)
      from public.stage_event_areas event_area
      join public.areas area
        on area.id = event_area.area_id
       and area.is_active
      where event_area.event_id = event.id
    ), '[]'::jsonb) as area_names
  from public.stage_events event
  join public.stage_event_organizers organizer
    on organizer.id = event.organizer_id
   and organizer.verification_status = 'verified'
  where event.publication_status = 'published'
    and event.published_at <= now()
    and event.event_status in (
      'scheduled',
      'applications_open',
      'applications_closed'
    )
    and coalesce(event.ends_at, event.starts_at) >= now()
    and exists (
      select 1
      from public.stage_event_genres event_genre
      join public.genres genre on genre.id = event_genre.genre_id
      where event_genre.event_id = event.id
        and genre.domain = 'dance'
        and genre.is_active
    )
  order by event.starts_at, event.title, event.id
  limit 80;
end;
$$;

create or replace function public.get_stage_event_detail_v1(
  p_event_id uuid
)
returns table (
  event_id uuid,
  organizer_id uuid,
  organizer_name text,
  organizer_official_url text,
  title text,
  category text,
  summary text,
  eligibility_summary text,
  venue_name text,
  starts_at timestamptz,
  ends_at timestamptz,
  application_deadline timestamptz,
  fee_summary text,
  official_url text,
  source_url text,
  source_type text,
  last_verified_at timestamptz,
  event_status text,
  dance_genre_names jsonb,
  area_names jsonb
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

  if p_event_id is null then
    raise exception 'event id is required';
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
  from public.get_stage_events_v1() listed_event
  where listed_event.event_id = p_event_id;
end;
$$;

revoke all on public.stage_event_organizers
  from public, anon, authenticated;
revoke all on public.stage_events from public, anon, authenticated;
revoke all on public.stage_event_genres from public, anon, authenticated;
revoke all on public.stage_event_areas from public, anon, authenticated;

revoke all on function public.get_stage_events_v1() from public, anon;
revoke all on function public.get_stage_event_detail_v1(uuid)
  from public, anon;
grant execute on function public.get_stage_events_v1() to authenticated;
grant execute on function public.get_stage_event_detail_v1(uuid)
  to authenticated;

notify pgrst, 'reload schema';

commit;

-- Private, caller-scoped STAGE Crew operating loop.
-- Adds practices/attendance, schedule polls, announcements, HTTPS resources,
-- target-event history, and activity projections without changing legacy
-- BandMatch tables or direct client privileges. Run after Migration 042.

begin;

create table public.stage_crew_practices (
  id uuid primary key default gen_random_uuid(),
  crew_id uuid not null references public.groups(id) on delete cascade,
  created_by uuid not null references public.users(id) on delete restrict,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  area_id uuid references public.areas(id) on delete restrict,
  location_name text
    check (location_name is null or char_length(location_name) <= 160),
  meeting_note text
    check (meeting_note is null or char_length(meeting_note) <= 500),
  description text
    check (description is null or char_length(description) <= 2000),
  attendance_deadline timestamptz,
  status text not null default 'scheduled'
    check (status in ('scheduled', 'cancelled', 'completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stage_crew_practices_time_check check (ends_at > starts_at),
  constraint stage_crew_practices_deadline_check check (
    attendance_deadline is null or attendance_deadline <= starts_at
  )
);

create table public.stage_crew_attendance (
  practice_id uuid not null
    references public.stage_crew_practices(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete restrict,
  response text not null
    check (response in ('attending', 'maybe', 'not_attending')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (practice_id, user_id)
);

create table public.stage_crew_schedule_polls (
  id uuid primary key default gen_random_uuid(),
  crew_id uuid not null references public.groups(id) on delete cascade,
  created_by uuid not null references public.users(id) on delete restrict,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  status text not null default 'open'
    check (status in ('open', 'finalized', 'cancelled')),
  finalized_option_id uuid,
  resulting_practice_id uuid
    references public.stage_crew_practices(id)
    on delete no action deferrable initially deferred,
  finalized_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stage_crew_poll_final_state_check check (
    (status = 'finalized' and finalized_option_id is not null
      and finalized_at is not null)
    or (status <> 'finalized' and finalized_option_id is null
      and finalized_at is null)
  )
);

create table public.stage_crew_schedule_poll_options (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null
    references public.stage_crew_schedule_polls(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  sort_order smallint not null check (sort_order > 0),
  created_at timestamptz not null default now(),
  unique (poll_id, id),
  unique (poll_id, sort_order),
  unique (poll_id, starts_at, ends_at),
  constraint stage_crew_poll_options_time_check check (ends_at > starts_at)
);

alter table public.stage_crew_schedule_polls
  add constraint stage_crew_polls_finalized_option_fk
  foreign key (id, finalized_option_id)
  references public.stage_crew_schedule_poll_options(poll_id, id)
  on delete no action deferrable initially deferred;

create table public.stage_crew_schedule_poll_responses (
  option_id uuid not null
    references public.stage_crew_schedule_poll_options(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete restrict,
  response text not null
    check (response in ('available', 'maybe', 'unavailable')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (option_id, user_id)
);

create table public.stage_crew_announcements (
  id uuid primary key default gen_random_uuid(),
  crew_id uuid not null references public.groups(id) on delete cascade,
  created_by uuid not null references public.users(id) on delete restrict,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  body text not null check (char_length(btrim(body)) between 1 and 4000),
  status text not null default 'published'
    check (status in ('draft', 'published', 'archived')),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stage_crew_announcements_publish_check check (
    status <> 'published' or published_at is not null
  )
);

create table public.stage_crew_resources (
  id uuid primary key default gen_random_uuid(),
  crew_id uuid not null references public.groups(id) on delete cascade,
  created_by uuid not null references public.users(id) on delete restrict,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  resource_type text not null check (resource_type in (
    'choreography', 'practice_video', 'music', 'document', 'other'
  )),
  external_url text not null check (
    char_length(external_url) <= 2000
    and external_url ~ '^https://[^[:space:]]+$'
  ),
  description text
    check (description is null or char_length(description) <= 1000),
  status text not null default 'active'
    check (status in ('active', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.stage_crew_event_targets (
  id uuid primary key default gen_random_uuid(),
  crew_id uuid not null references public.groups(id) on delete cascade,
  event_id uuid not null references public.stage_events(id) on delete restrict,
  created_by uuid not null references public.users(id) on delete restrict,
  status text not null default 'active'
    check (status in ('active', 'completed', 'archived')),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stage_crew_event_targets_end_check check (
    (status = 'active' and ended_at is null)
    or (status <> 'active' and ended_at is not null)
  )
);

create unique index stage_crew_event_targets_one_active_idx
  on public.stage_crew_event_targets (crew_id) where status = 'active';
create index stage_crew_practices_list_idx
  on public.stage_crew_practices (crew_id, starts_at desc, id);
create index stage_crew_attendance_user_idx
  on public.stage_crew_attendance (user_id, practice_id);
create index stage_crew_polls_list_idx
  on public.stage_crew_schedule_polls (crew_id, created_at desc, id);
create index stage_crew_poll_options_list_idx
  on public.stage_crew_schedule_poll_options (poll_id, sort_order, id);
create index stage_crew_poll_responses_user_idx
  on public.stage_crew_schedule_poll_responses (user_id, option_id);
create index stage_crew_announcements_list_idx
  on public.stage_crew_announcements (crew_id, published_at desc, id);
create index stage_crew_resources_list_idx
  on public.stage_crew_resources (crew_id, created_at desc, id);
create index stage_crew_event_targets_list_idx
  on public.stage_crew_event_targets (crew_id, started_at desc, id);

create trigger set_updated_at before update on public.stage_crew_practices
for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.stage_crew_attendance
for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.stage_crew_schedule_polls
for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.stage_crew_schedule_poll_responses
for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.stage_crew_announcements
for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.stage_crew_resources
for each row execute function public.set_updated_at();
create trigger set_updated_at before update on public.stage_crew_event_targets
for each row execute function public.set_updated_at();

alter table public.stage_crew_practices enable row level security;
alter table public.stage_crew_attendance enable row level security;
alter table public.stage_crew_schedule_polls enable row level security;
alter table public.stage_crew_schedule_poll_options enable row level security;
alter table public.stage_crew_schedule_poll_responses enable row level security;
alter table public.stage_crew_announcements enable row level security;
alter table public.stage_crew_resources enable row level security;
alter table public.stage_crew_event_targets enable row level security;

-- Direct client table access is intentionally unavailable. All reads and
-- writes go through the caller-scoped functions below.
revoke all on table public.stage_crew_practices
  from public, anon, authenticated;
revoke all on table public.stage_crew_attendance
  from public, anon, authenticated;
revoke all on table public.stage_crew_schedule_polls
  from public, anon, authenticated;
revoke all on table public.stage_crew_schedule_poll_options
  from public, anon, authenticated;
revoke all on table public.stage_crew_schedule_poll_responses
  from public, anon, authenticated;
revoke all on table public.stage_crew_announcements
  from public, anon, authenticated;
revoke all on table public.stage_crew_resources
  from public, anon, authenticated;
revoke all on table public.stage_crew_event_targets
  from public, anon, authenticated;

create or replace function public.require_stage_active_crew_member_v1(
  p_crew_id uuid,
  p_require_admin boolean default false
)
returns table (user_id uuid, membership_role text)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.require_stage_active_user_v1();
begin
  return query
  select v_user_id, member.role
  from public.groups crew
  join public.group_members member on member.group_id = crew.id
  where crew.id = p_crew_id
    and crew.account_status = 'active'
    and member.user_id = v_user_id
    and member.membership_status = 'active'
    and member.role in ('admin', 'member')
    and (not p_require_admin or member.role = 'admin');

  if not found then
    raise exception 'active Crew membership is required'
      using errcode = '42501';
  end if;
end;
$$;

create or replace function public.get_stage_crew_home_v1(p_crew_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
  v_role text;
  v_result jsonb;
begin
  select member.user_id, member.membership_role
  into v_user_id, v_role
  from public.require_stage_active_crew_member_v1(p_crew_id) member;

  select jsonb_build_object(
    'crew_id', crew.id,
    'crew_name', crew.name,
    'crew_avatar_url', crew.avatar_url,
    'crew_bio', crew.bio,
    'membership_role', v_role,
    'target_event', (
      select jsonb_build_object(
        'target_id', target.id,
        'event_id', event.id,
        'title', event.title,
        'starts_at', event.starts_at,
        'venue_name', event.venue_name
      )
      from public.stage_crew_event_targets target
      join public.stage_events event on event.id = target.event_id
      join public.stage_event_organizers organizer
        on organizer.id = event.organizer_id
       and organizer.verification_status = 'verified'
      where target.crew_id = crew.id
        and target.status = 'active'
        and event.publication_status = 'published'
        and event.published_at <= now()
        and event.event_status not in ('cancelled', 'completed')
        and exists (
          select 1
          from public.stage_event_genres event_genre
          join public.genres genre
            on genre.id = event_genre.genre_id
           and genre.domain = 'dance'
           and genre.is_active
          where event_genre.event_id = event.id
        )
      limit 1
    ),
    'next_practice', (
      select jsonb_build_object(
        'practice_id', practice.id,
        'title', practice.title,
        'starts_at', practice.starts_at,
        'ends_at', practice.ends_at,
        'location_name', practice.location_name,
        'status', practice.status,
        'my_attendance', (
          select attendance.response
          from public.stage_crew_attendance attendance
          where attendance.practice_id = practice.id
            and attendance.user_id = v_user_id
        ),
        'attendance_counts', (
          select jsonb_build_object(
            'attending', count(*) filter (
              where attendance.response = 'attending'
            ),
            'maybe', count(*) filter (
              where attendance.response = 'maybe'
            ),
            'not_attending', count(*) filter (
              where attendance.response = 'not_attending'
            )
          )
          from public.stage_crew_attendance attendance
          where attendance.practice_id = practice.id
        )
      )
      from public.stage_crew_practices practice
      where practice.crew_id = crew.id
        and practice.status = 'scheduled'
        and practice.ends_at >= now()
      order by practice.starts_at, practice.id
      limit 1
    ),
    'open_poll', (
      select jsonb_build_object(
        'poll_id', poll.id,
        'title', poll.title,
        'status', poll.status
      )
      from public.stage_crew_schedule_polls poll
      where poll.crew_id = crew.id and poll.status = 'open'
      order by poll.created_at desc, poll.id
      limit 1
    ),
    'latest_announcement', (
      select jsonb_build_object(
        'announcement_id', announcement.id,
        'title', announcement.title,
        'published_at', announcement.published_at
      )
      from public.stage_crew_announcements announcement
      where announcement.crew_id = crew.id
        and announcement.status = 'published'
      order by announcement.published_at desc, announcement.id
      limit 1
    ),
    'latest_resource', (
      select jsonb_build_object(
        'resource_id', resource.id,
        'title', resource.title,
        'resource_type', resource.resource_type,
        'created_at', resource.created_at
      )
      from public.stage_crew_resources resource
      where resource.crew_id = crew.id and resource.status = 'active'
      order by resource.created_at desc, resource.id
      limit 1
    )
  ) into v_result
  from public.groups crew
  where crew.id = p_crew_id and crew.account_status = 'active';

  if v_result is null then
    raise exception 'active Crew not found' using errcode = '55000';
  end if;
  return v_result;
end;
$$;

create or replace function public.get_stage_crew_activity_v1(p_crew_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
  v_role text;
begin
  select member.user_id, member.membership_role
  into v_user_id, v_role
  from public.require_stage_active_crew_member_v1(p_crew_id) member;

  return jsonb_build_object(
    'is_admin', v_role = 'admin',
    'practices', coalesce((
      select jsonb_agg(jsonb_build_object(
        'practice_id', practice.id,
        'title', practice.title,
        'starts_at', practice.starts_at,
        'ends_at', practice.ends_at,
        'area_id', practice.area_id,
        'location_name', practice.location_name,
        'meeting_note', practice.meeting_note,
        'description', practice.description,
        'attendance_deadline', practice.attendance_deadline,
        'status', practice.status,
        'my_attendance', (
          select attendance.response
          from public.stage_crew_attendance attendance
          where attendance.practice_id = practice.id
            and attendance.user_id = v_user_id
        ),
        'attendance_counts', (
          select jsonb_build_object(
            'attending', count(*) filter (
              where attendance.response = 'attending'
            ),
            'maybe', count(*) filter (
              where attendance.response = 'maybe'
            ),
            'not_attending', count(*) filter (
              where attendance.response = 'not_attending'
            )
          )
          from public.stage_crew_attendance attendance
          where attendance.practice_id = practice.id
        )
      ) order by practice.starts_at desc, practice.id)
      from public.stage_crew_practices practice
      where practice.crew_id = p_crew_id
    ), '[]'::jsonb),
    'polls', coalesce((
      select jsonb_agg(jsonb_build_object(
        'poll_id', poll.id,
        'title', poll.title,
        'status', poll.status,
        'finalized_option_id', poll.finalized_option_id,
        'resulting_practice_id', poll.resulting_practice_id,
        'options', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'option_id', option.id,
            'starts_at', option.starts_at,
            'ends_at', option.ends_at,
            'sort_order', option.sort_order,
            'my_response', (
              select response.response
              from public.stage_crew_schedule_poll_responses response
              where response.option_id = option.id
                and response.user_id = v_user_id
            ),
            'counts', (
              select jsonb_build_object(
                'available', count(*) filter (
                  where response.response = 'available'
                ),
                'maybe', count(*) filter (
                  where response.response = 'maybe'
                ),
                'unavailable', count(*) filter (
                  where response.response = 'unavailable'
                )
              )
              from public.stage_crew_schedule_poll_responses response
              where response.option_id = option.id
            )
          ) order by option.sort_order, option.id), '[]'::jsonb)
          from public.stage_crew_schedule_poll_options option
          where option.poll_id = poll.id
        )
      ) order by poll.created_at desc, poll.id)
      from public.stage_crew_schedule_polls poll
      where poll.crew_id = p_crew_id
    ), '[]'::jsonb),
    'announcements', coalesce((
      select jsonb_agg(jsonb_build_object(
        'announcement_id', announcement.id,
        'title', announcement.title,
        'body', announcement.body,
        'status', announcement.status,
        'published_at', announcement.published_at,
        'created_at', announcement.created_at,
        'author_display_name', author_profile.display_name
      ) order by coalesce(announcement.published_at,
        announcement.created_at) desc, announcement.id)
      from public.stage_crew_announcements announcement
      join public.users author_profile
        on author_profile.id = announcement.created_by
      where announcement.crew_id = p_crew_id
        and (announcement.status = 'published' or v_role = 'admin')
    ), '[]'::jsonb),
    'resources', coalesce((
      select jsonb_agg(jsonb_build_object(
        'resource_id', resource.id,
        'title', resource.title,
        'resource_type', resource.resource_type,
        'external_url', resource.external_url,
        'description', resource.description,
        'status', resource.status,
        'created_at', resource.created_at
      ) order by resource.created_at desc, resource.id)
      from public.stage_crew_resources resource
      where resource.crew_id = p_crew_id
        and (resource.status = 'active' or v_role = 'admin')
    ), '[]'::jsonb),
    'targets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'target_id', target.id,
        'event_id', event.id,
        'title', event.title,
        'starts_at', event.starts_at,
        'venue_name', event.venue_name,
        'status', target.status,
        'started_at', target.started_at,
        'ended_at', target.ended_at
      ) order by target.started_at desc, target.id)
      from public.stage_crew_event_targets target
      join public.stage_events event on event.id = target.event_id
      join public.stage_event_organizers organizer
        on organizer.id = event.organizer_id
       and organizer.verification_status = 'verified'
      where target.crew_id = p_crew_id
        and event.publication_status = 'published'
        and event.published_at <= now()
        and exists (
          select 1
          from public.stage_event_genres event_genre
          join public.genres genre
            on genre.id = event_genre.genre_id
           and genre.domain = 'dance'
           and genre.is_active
          where event_genre.event_id = event.id
        )
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.upsert_stage_crew_practice_v1(
  p_crew_id uuid,
  p_practice_id uuid,
  p_title text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_area_id uuid default null,
  p_location_name text default null,
  p_meeting_note text default null,
  p_description text default null,
  p_attendance_deadline timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
  v_practice_id uuid;
  v_title text := btrim(coalesce(p_title, ''));
begin
  select member.user_id into v_user_id
  from public.require_stage_active_crew_member_v1(p_crew_id, true) member;
  if char_length(v_title) not between 1 and 120
    or p_starts_at is null
    or p_ends_at is null
    or p_ends_at <= p_starts_at
    or (p_attendance_deadline is not null
      and p_attendance_deadline > p_starts_at) then
    raise exception 'invalid practice input' using errcode = '22023';
  end if;
  if p_area_id is not null and not exists (
    select 1 from public.areas area
    where area.id = p_area_id and area.is_active
      and area.level in ('prefecture', 'city')
  ) then
    raise exception 'active public area not found' using errcode = '22023';
  end if;

  if p_practice_id is null then
    insert into public.stage_crew_practices (
      crew_id, created_by, title, starts_at, ends_at, area_id,
      location_name, meeting_note, description, attendance_deadline
    ) values (
      p_crew_id, v_user_id, v_title, p_starts_at, p_ends_at, p_area_id,
      nullif(btrim(coalesce(p_location_name, '')), ''),
      nullif(btrim(coalesce(p_meeting_note, '')), ''),
      nullif(btrim(coalesce(p_description, '')), ''),
      p_attendance_deadline
    ) returning id into v_practice_id;
  else
    update public.stage_crew_practices practice
    set title = v_title,
        starts_at = p_starts_at,
        ends_at = p_ends_at,
        area_id = p_area_id,
        location_name = nullif(btrim(coalesce(p_location_name, '')), ''),
        meeting_note = nullif(btrim(coalesce(p_meeting_note, '')), ''),
        description = nullif(btrim(coalesce(p_description, '')), ''),
        attendance_deadline = p_attendance_deadline
    where practice.id = p_practice_id
      and practice.crew_id = p_crew_id
      and practice.status = 'scheduled'
    returning practice.id into v_practice_id;
  end if;
  if v_practice_id is null then
    raise exception 'editable practice not found' using errcode = '55000';
  end if;
  return v_practice_id;
end;
$$;

create or replace function public.set_stage_crew_practice_status_v1(
  p_crew_id uuid,
  p_practice_id uuid,
  p_status text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.require_stage_active_crew_member_v1(p_crew_id, true);
  if p_status not in ('cancelled', 'completed') then
    raise exception 'invalid practice status' using errcode = '22023';
  end if;
  update public.stage_crew_practices practice
  set status = p_status
  where practice.id = p_practice_id
    and practice.crew_id = p_crew_id
    and practice.status = 'scheduled';
  if not found then
    raise exception 'scheduled practice not found' using errcode = '55000';
  end if;
  return p_practice_id;
end;
$$;

create or replace function public.respond_stage_crew_attendance_v1(
  p_crew_id uuid,
  p_practice_id uuid,
  p_response text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
begin
  select member.user_id into v_user_id
  from public.require_stage_active_crew_member_v1(p_crew_id) member;
  if p_response not in ('attending', 'maybe', 'not_attending') then
    raise exception 'invalid attendance response' using errcode = '22023';
  end if;
  perform 1
  from public.stage_crew_practices practice
  where practice.id = p_practice_id
    and practice.crew_id = p_crew_id
    and practice.status = 'scheduled'
    and practice.ends_at >= now()
    and (practice.attendance_deadline is null
      or practice.attendance_deadline >= now())
  for update;
  if not found then
    raise exception 'practice is not accepting attendance'
      using errcode = '55000';
  end if;
  insert into public.stage_crew_attendance (
    practice_id, user_id, response
  ) values (
    p_practice_id, v_user_id, p_response
  ) on conflict (practice_id, user_id) do update
  set response = excluded.response;
  return jsonb_build_object(
    'practice_id', p_practice_id,
    'user_id', v_user_id,
    'response', p_response
  );
end;
$$;

create or replace function public.create_stage_crew_poll_v1(
  p_crew_id uuid,
  p_title text,
  p_options jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
  v_poll_id uuid;
  v_title text := btrim(coalesce(p_title, ''));
begin
  select member.user_id into v_user_id
  from public.require_stage_active_crew_member_v1(p_crew_id, true) member;
  if p_options is null
    or char_length(v_title) not between 1 and 120
    or jsonb_typeof(p_options) <> 'array'
    or jsonb_array_length(p_options) < 2
    or jsonb_array_length(p_options) > 20 then
    raise exception 'invalid schedule poll input' using errcode = '22023';
  end if;
  if exists (
    select 1
    from jsonb_array_elements(p_options) option(value)
    where not (option.value ? 'starts_at')
      or not (option.value ? 'ends_at')
      or (option.value ->> 'ends_at')::timestamptz
        <= (option.value ->> 'starts_at')::timestamptz
  ) then
    raise exception 'invalid schedule poll option' using errcode = '22023';
  end if;

  insert into public.stage_crew_schedule_polls (
    crew_id, created_by, title
  ) values (
    p_crew_id, v_user_id, v_title
  ) returning id into v_poll_id;

  insert into public.stage_crew_schedule_poll_options (
    poll_id, starts_at, ends_at, sort_order
  )
  select
    v_poll_id,
    (option.value ->> 'starts_at')::timestamptz,
    (option.value ->> 'ends_at')::timestamptz,
    option.ordinality::smallint
  from jsonb_array_elements(p_options)
    with ordinality option(value, ordinality);

  return v_poll_id;
end;
$$;

create or replace function public.respond_stage_crew_poll_v1(
  p_crew_id uuid,
  p_poll_id uuid,
  p_responses jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
begin
  select member.user_id into v_user_id
  from public.require_stage_active_crew_member_v1(p_crew_id) member;
  if p_responses is null
    or jsonb_typeof(p_responses) <> 'array'
    or jsonb_array_length(p_responses) = 0 then
    raise exception 'poll responses are required' using errcode = '22023';
  end if;
  perform 1
  from public.stage_crew_schedule_polls poll
  where poll.id = p_poll_id
    and poll.crew_id = p_crew_id
    and poll.status = 'open'
  for update;
  if not found then
    raise exception 'open poll not found' using errcode = '55000';
  end if;
  if exists (
    select 1
    from jsonb_to_recordset(p_responses)
      as response(option_id uuid, response text)
    left join public.stage_crew_schedule_poll_options option
      on option.id = response.option_id and option.poll_id = p_poll_id
    where option.id is null
      or response.response not in ('available', 'maybe', 'unavailable')
  ) or (
    select count(*) from jsonb_to_recordset(p_responses)
      as response(option_id uuid, response text)
  ) <> (
    select count(distinct response.option_id)
    from jsonb_to_recordset(p_responses)
      as response(option_id uuid, response text)
  ) then
    raise exception 'invalid poll response' using errcode = '22023';
  end if;

  insert into public.stage_crew_schedule_poll_responses (
    option_id, user_id, response
  )
  select response.option_id, v_user_id, response.response
  from jsonb_to_recordset(p_responses)
    as response(option_id uuid, response text)
  on conflict (option_id, user_id) do update
  set response = excluded.response;
  return p_poll_id;
end;
$$;

create or replace function public.cancel_stage_crew_poll_v1(
  p_crew_id uuid,
  p_poll_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public.require_stage_active_crew_member_v1(p_crew_id, true);
  update public.stage_crew_schedule_polls poll
  set status = 'cancelled'
  where poll.id = p_poll_id
    and poll.crew_id = p_crew_id
    and poll.status = 'open';
  if not found then
    raise exception 'open poll not found' using errcode = '55000';
  end if;
  return p_poll_id;
end;
$$;

create or replace function public.finalize_stage_crew_poll_v1(
  p_crew_id uuid,
  p_poll_id uuid,
  p_option_id uuid,
  p_create_practice boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
  v_poll public.stage_crew_schedule_polls%rowtype;
  v_option public.stage_crew_schedule_poll_options%rowtype;
  v_practice_id uuid;
begin
  select member.user_id into v_user_id
  from public.require_stage_active_crew_member_v1(p_crew_id, true) member;
  select poll.* into v_poll
  from public.stage_crew_schedule_polls poll
  where poll.id = p_poll_id and poll.crew_id = p_crew_id
  for update;
  if not found or v_poll.status <> 'open' then
    raise exception 'open poll not found' using errcode = '55000';
  end if;
  select option.* into v_option
  from public.stage_crew_schedule_poll_options option
  where option.id = p_option_id and option.poll_id = p_poll_id;
  if not found then
    raise exception 'poll option not found' using errcode = '22023';
  end if;

  if p_create_practice then
    insert into public.stage_crew_practices (
      crew_id, created_by, title, starts_at, ends_at
    ) values (
      p_crew_id, v_user_id, v_poll.title,
      v_option.starts_at, v_option.ends_at
    ) returning id into v_practice_id;
  end if;
  update public.stage_crew_schedule_polls poll
  set status = 'finalized',
      finalized_option_id = p_option_id,
      resulting_practice_id = v_practice_id,
      finalized_at = now()
  where poll.id = p_poll_id;
  return jsonb_build_object(
    'poll_id', p_poll_id,
    'status', 'finalized',
    'finalized_option_id', p_option_id,
    'resulting_practice_id', v_practice_id
  );
end;
$$;

create or replace function public.upsert_stage_crew_announcement_v1(
  p_crew_id uuid,
  p_announcement_id uuid,
  p_title text,
  p_body text,
  p_status text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
  v_id uuid;
  v_title text := btrim(coalesce(p_title, ''));
  v_body text := btrim(coalesce(p_body, ''));
begin
  select member.user_id into v_user_id
  from public.require_stage_active_crew_member_v1(p_crew_id, true) member;
  if char_length(v_title) not between 1 and 120
    or char_length(v_body) not between 1 and 4000
    or p_status not in ('draft', 'published', 'archived') then
    raise exception 'invalid announcement input' using errcode = '22023';
  end if;
  if p_announcement_id is null then
    insert into public.stage_crew_announcements (
      crew_id, created_by, title, body, status, published_at
    ) values (
      p_crew_id, v_user_id, v_title, v_body, p_status,
      case when p_status = 'published' then now() end
    ) returning id into v_id;
  else
    update public.stage_crew_announcements announcement
    set title = v_title,
        body = v_body,
        status = p_status,
        published_at = case
          when p_status = 'published'
            then coalesce(announcement.published_at, now())
          else announcement.published_at
        end
    where announcement.id = p_announcement_id
      and announcement.crew_id = p_crew_id
    returning announcement.id into v_id;
  end if;
  if v_id is null then
    raise exception 'announcement not found' using errcode = '55000';
  end if;
  return v_id;
end;
$$;

create or replace function public.upsert_stage_crew_resource_v1(
  p_crew_id uuid,
  p_resource_id uuid,
  p_title text,
  p_resource_type text,
  p_external_url text,
  p_description text,
  p_status text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
  v_id uuid;
  v_title text := btrim(coalesce(p_title, ''));
  v_url text := btrim(coalesce(p_external_url, ''));
begin
  select member.user_id into v_user_id
  from public.require_stage_active_crew_member_v1(p_crew_id, true) member;
  if char_length(v_title) not between 1 and 120
    or p_resource_type not in (
      'choreography', 'practice_video', 'music', 'document', 'other'
    )
    or p_status not in ('active', 'archived')
    or char_length(v_url) > 2000
    or v_url !~ '^https://[^[:space:]]+$' then
    raise exception 'invalid Crew resource' using errcode = '22023';
  end if;
  if p_resource_id is null then
    insert into public.stage_crew_resources (
      crew_id, created_by, title, resource_type,
      external_url, description, status
    ) values (
      p_crew_id, v_user_id, v_title, p_resource_type, v_url,
      nullif(btrim(coalesce(p_description, '')), ''), p_status
    ) returning id into v_id;
  else
    update public.stage_crew_resources resource
    set title = v_title,
        resource_type = p_resource_type,
        external_url = v_url,
        description = nullif(btrim(coalesce(p_description, '')), ''),
        status = p_status
    where resource.id = p_resource_id
      and resource.crew_id = p_crew_id
    returning resource.id into v_id;
  end if;
  if v_id is null then
    raise exception 'resource not found' using errcode = '55000';
  end if;
  return v_id;
end;
$$;

create or replace function public.set_stage_crew_target_event_v1(
  p_crew_id uuid,
  p_event_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
  v_target_id uuid;
begin
  select member.user_id into v_user_id
  from public.require_stage_active_crew_member_v1(p_crew_id, true) member;

  -- Serialize target replacement per Crew so two concurrent admin requests
  -- cannot race the one-active-target invariant.
  perform 1
  from public.groups crew
  where crew.id = p_crew_id
  for update;

  if not exists (
    select 1
    from public.stage_events event
    join public.stage_event_organizers organizer
      on organizer.id = event.organizer_id
     and organizer.verification_status = 'verified'
    where event.id = p_event_id
      and event.publication_status = 'published'
      and event.published_at <= now()
      and event.event_status not in ('cancelled', 'completed')
      and event.starts_at >= now()
      and exists (
        select 1
        from public.stage_event_genres event_genre
        join public.genres genre
          on genre.id = event_genre.genre_id
         and genre.domain = 'dance'
         and genre.is_active
        where event_genre.event_id = event.id
      )
  ) then
    raise exception 'eligible Dance event not found' using errcode = '22023';
  end if;

  select target.id into v_target_id
  from public.stage_crew_event_targets target
  where target.crew_id = p_crew_id
    and target.event_id = p_event_id
    and target.status = 'active';
  if found then
    return v_target_id;
  end if;

  update public.stage_crew_event_targets target
  set status = 'archived', ended_at = now()
  where target.crew_id = p_crew_id and target.status = 'active';
  insert into public.stage_crew_event_targets (
    crew_id, event_id, created_by
  ) values (
    p_crew_id, p_event_id, v_user_id
  ) returning id into v_target_id;
  return v_target_id;
end;
$$;

create or replace function public.get_stage_crew_activity_feed_v1()
returns table (
  activity_key text,
  activity_type text,
  activity_status text,
  occurred_at timestamptz,
  crew_id uuid,
  crew_name text,
  post_id uuid,
  post_title text,
  application_id uuid,
  actor_display_name text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.require_stage_active_user_v1();
begin
  return query
  with active_crews as (
    select crew.id, crew.name, membership.role
    from public.group_members membership
    join public.groups crew
      on crew.id = membership.group_id
     and crew.account_status = 'active'
    where membership.user_id = v_user_id
      and membership.membership_status = 'active'
      and membership.role in ('admin', 'member')
  ), activity as (
    select
      'crew_practice:' || practice.id::text as activity_key,
      'crew_practice'::text as activity_type,
      practice.status as activity_status,
      practice.updated_at as occurred_at,
      crew.id as crew_id,
      crew.name as crew_name,
      null::uuid as post_id,
      practice.title as post_title,
      null::uuid as application_id,
      null::text as actor_display_name
    from active_crews crew
    join public.stage_crew_practices practice on practice.crew_id = crew.id
    where practice.starts_at >= now() - interval '30 days'

    union all

    select
      'crew_poll:' || poll.id::text,
      'crew_poll'::text,
      poll.status,
      poll.updated_at,
      crew.id,
      crew.name,
      null::uuid,
      poll.title,
      null::uuid,
      null::text
    from active_crews crew
    join public.stage_crew_schedule_polls poll on poll.crew_id = crew.id

    union all

    select
      'crew_announcement:' || announcement.id::text,
      'crew_announcement'::text,
      announcement.status,
      coalesce(announcement.published_at, announcement.updated_at),
      crew.id,
      crew.name,
      null::uuid,
      announcement.title,
      null::uuid,
      null::text
    from active_crews crew
    join public.stage_crew_announcements announcement
      on announcement.crew_id = crew.id
    where announcement.status = 'published'

    union all

    select
      'crew_resource:' || resource.id::text,
      'crew_resource'::text,
      resource.status,
      resource.updated_at,
      crew.id,
      crew.name,
      null::uuid,
      resource.title,
      null::uuid,
      null::text
    from active_crews crew
    join public.stage_crew_resources resource on resource.crew_id = crew.id
    where resource.status = 'active'
  )
  select
    activity.activity_key,
    activity.activity_type,
    activity.activity_status,
    activity.occurred_at,
    activity.crew_id,
    activity.crew_name,
    activity.post_id,
    activity.post_title,
    activity.application_id,
    activity.actor_display_name
  from activity
  order by activity.occurred_at desc, activity.activity_key
  limit 80;
end;
$$;

revoke all on function public.require_stage_active_crew_member_v1(uuid, boolean)
  from public, anon, authenticated;
revoke all on function public.get_stage_crew_home_v1(uuid)
  from public, anon;
revoke all on function public.get_stage_crew_activity_v1(uuid)
  from public, anon;
revoke all on function public.upsert_stage_crew_practice_v1(
  uuid, uuid, text, timestamptz, timestamptz, uuid,
  text, text, text, timestamptz
) from public, anon;
revoke all on function public.set_stage_crew_practice_status_v1(
  uuid, uuid, text
) from public, anon;
revoke all on function public.respond_stage_crew_attendance_v1(
  uuid, uuid, text
) from public, anon;
revoke all on function public.create_stage_crew_poll_v1(
  uuid, text, jsonb
) from public, anon;
revoke all on function public.respond_stage_crew_poll_v1(
  uuid, uuid, jsonb
) from public, anon;
revoke all on function public.cancel_stage_crew_poll_v1(uuid, uuid)
  from public, anon;
revoke all on function public.finalize_stage_crew_poll_v1(
  uuid, uuid, uuid, boolean
) from public, anon;
revoke all on function public.upsert_stage_crew_announcement_v1(
  uuid, uuid, text, text, text
) from public, anon;
revoke all on function public.upsert_stage_crew_resource_v1(
  uuid, uuid, text, text, text, text, text
) from public, anon;
revoke all on function public.set_stage_crew_target_event_v1(uuid, uuid)
  from public, anon;
revoke all on function public.get_stage_crew_activity_feed_v1()
  from public, anon;

grant execute on function public.get_stage_crew_home_v1(uuid)
  to authenticated;
grant execute on function public.get_stage_crew_activity_v1(uuid)
  to authenticated;
grant execute on function public.upsert_stage_crew_practice_v1(
  uuid, uuid, text, timestamptz, timestamptz, uuid,
  text, text, text, timestamptz
) to authenticated;
grant execute on function public.set_stage_crew_practice_status_v1(
  uuid, uuid, text
) to authenticated;
grant execute on function public.respond_stage_crew_attendance_v1(
  uuid, uuid, text
) to authenticated;
grant execute on function public.create_stage_crew_poll_v1(
  uuid, text, jsonb
) to authenticated;
grant execute on function public.respond_stage_crew_poll_v1(
  uuid, uuid, jsonb
) to authenticated;
grant execute on function public.cancel_stage_crew_poll_v1(uuid, uuid)
  to authenticated;
grant execute on function public.finalize_stage_crew_poll_v1(
  uuid, uuid, uuid, boolean
) to authenticated;
grant execute on function public.upsert_stage_crew_announcement_v1(
  uuid, uuid, text, text, text
) to authenticated;
grant execute on function public.upsert_stage_crew_resource_v1(
  uuid, uuid, text, text, text, text, text
) to authenticated;
grant execute on function public.set_stage_crew_target_event_v1(uuid, uuid)
  to authenticated;
grant execute on function public.get_stage_crew_activity_feed_v1()
  to authenticated;

notify pgrst, 'reload schema';

commit;

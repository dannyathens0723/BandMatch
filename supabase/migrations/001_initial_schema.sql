-- BandMatch Phase 1 initial schema
-- Run first in Supabase SQL Editor. This migration intentionally contains no keys or secrets.

begin;

create extension if not exists pgcrypto;

-- All status-like fields are text + CHECK constraints.  This is easier to bind in FlutterFlow
-- than PostgreSQL enum arrays, while selection data is normalized into join tables below.

create table public.users (
  id uuid primary key default gen_random_uuid(),
  auth_uid uuid not null unique references auth.users(id) on delete restrict,
  email text not null unique,
  phone text,
  phone_verified boolean not null default false,
  sns_providers text,
  account_status text not null default 'active'
    check (account_status in ('active', 'suspended', 'withdrawn')),
  withdrawn_at timestamptz,
  display_name text not null check (char_length(display_name) between 1 and 30),
  avatar_url text,
  birth_date date not null,
  gender text check (gender in ('male', 'female', 'non_binary', 'no_answer')),
  show_age boolean not null default false,
  show_gender boolean not null default false,
  last_login_at timestamptz,
  premium_boost numeric(5,2) not null default 1.00 check (premium_boost >= 1.00),
  referral_source text,
  invited_by uuid references public.users(id) on delete set null,

  -- Profile block B: 自分の属性
  experience_level text check (experience_level in ('beginner_new', 'beginner', 'experienced', 'pro_oriented')),
  activity_frequency text check (activity_frequency in ('monthly_1_2', 'weekly_1_2', 'daily')),
  activity_days text,
  plays_instrument text check (plays_instrument in ('plays', 'music_lover')),
  employment text check (employment in ('student', 'worker')),
  favorite_artists text,
  gear text,
  bio text check (char_length(bio) <= 1000),

  -- Profile block C: 目指すスタイル
  style_orientation text check (style_orientation in ('copy', 'original')),

  -- Profile block D: 募集条件
  is_recruiting boolean not null default false,
  recruit_gender text check (recruit_gender in ('any', 'male', 'female')),
  recruit_age_min smallint check (recruit_age_min between 13 and 100),
  recruit_age_max smallint check (recruit_age_max between 13 and 100),
  recruit_purpose text check (recruit_purpose in ('light_session', 'songwriting', 'join_member')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint users_recruit_age_range check (
    recruit_age_min is null or recruit_age_max is null or recruit_age_min <= recruit_age_max
  ),
  constraint users_withdrawn_at check (
    (account_status = 'withdrawn' and withdrawn_at is not null)
    or (account_status <> 'withdrawn')
  )
);

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.users(id) on delete restrict,
  name text not null check (char_length(name) between 1 and 60),
  avatar_url text,
  bio text check (char_length(bio) <= 1000),
  account_status text not null default 'active'
    check (account_status in ('active', 'suspended', 'withdrawn')),
  last_active_at timestamptz,
  premium_boost numeric(5,2) not null default 1.00 check (premium_boost >= 1.00),
  style_orientation text check (style_orientation in ('copy', 'original')),
  activity_frequency text check (activity_frequency in ('monthly_1_2', 'weekly_1_2', 'daily')),
  is_recruiting boolean not null default false,
  recruit_gender text check (recruit_gender in ('any', 'male', 'female')),
  recruit_age_min smallint check (recruit_age_min between 13 and 100),
  recruit_age_max smallint check (recruit_age_max between 13 and 100),
  recruit_purpose text check (recruit_purpose in ('light_session', 'songwriting', 'join_member')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint groups_recruit_age_range check (
    recruit_age_min is null or recruit_age_max is null or recruit_age_min <= recruit_age_max
  )
);

create table public.areas (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.areas(id) on delete restrict,
  code text not null unique,
  name text not null,
  level text not null check (level in ('prefecture', 'city', 'station')),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.parts (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null unique,
  sort_order smallint not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.genres (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null unique,
  sort_order smallint not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- FlutterFlow note: these join tables replace enum[] / UUID[] profile columns.
create table public.user_purposes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  purpose text not null check (purpose in ('recruit', 'join', 'practice')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, purpose)
);

create table public.user_parts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  part_id uuid not null references public.parts(id) on delete restrict,
  other_part_text text check (char_length(other_part_text) <= 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, part_id)
);

create table public.user_genres (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  genre_id uuid not null references public.genres(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, genre_id)
);

create table public.user_target_parts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  part_id uuid not null references public.parts(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, part_id)
);

create table public.user_recruiting_parts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  part_id uuid not null references public.parts(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, part_id)
);

create table public.user_areas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  area_id uuid not null references public.areas(id) on delete restrict,
  -- Prefecture is always searchable. City/station visibility is controlled here.
  show_on_profile boolean not null default true,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, area_id)
);
create unique index user_areas_one_primary_per_user on public.user_areas (user_id) where is_primary;

create table public.group_genres (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  genre_id uuid not null references public.genres(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (group_id, genre_id)
);

create table public.group_target_parts (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  part_id uuid not null references public.parts(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (group_id, part_id)
);

create table public.group_recruiting_parts (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  part_id uuid not null references public.parts(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (group_id, part_id)
);

create table public.group_members (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete restrict,
  group_id uuid not null references public.groups(id) on delete cascade,
  part_id uuid references public.parts(id) on delete set null,
  other_part_text text check (char_length(other_part_text) <= 100),
  role text not null default 'member' check (role in ('admin', 'member')),
  joined_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, group_id)
);

create table public.media_portfolios (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  group_id uuid references public.groups(id) on delete cascade,
  platform text not null check (platform in ('youtube', 'soundcloud')),
  embed_url text not null,
  title text,
  description text check (char_length(description) <= 500),
  thumbnail_url text,
  sort_order smallint not null default 0,
  is_public boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint media_portfolios_one_owner check ((user_id is not null)::integer + (group_id is not null)::integer = 1)
);

create table public.blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references public.users(id) on delete cascade,
  blocked_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint blocks_not_self check (blocker_id <> blocked_id),
  unique (blocker_id, blocked_id)
);

create table public.message_requests (
  id uuid primary key default gen_random_uuid(),
  sender_user_id uuid references public.users(id) on delete restrict,
  sender_group_id uuid references public.groups(id) on delete restrict,
  receiver_user_id uuid references public.users(id) on delete restrict,
  receiver_group_id uuid references public.groups(id) on delete restrict,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  note text check (char_length(note) <= 300),
  responded_at timestamptz,
  responded_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint message_requests_one_sender check ((sender_user_id is not null)::integer + (sender_group_id is not null)::integer = 1),
  constraint message_requests_one_receiver check ((receiver_user_id is not null)::integer + (receiver_group_id is not null)::integer = 1),
  constraint message_requests_not_same_user check (sender_user_id is null or receiver_user_id is null or sender_user_id <> receiver_user_id),
  constraint message_requests_not_same_group check (sender_group_id is null or receiver_group_id is null or sender_group_id <> receiver_group_id)
);

create table public.message_rooms (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique references public.message_requests(id) on delete restrict,
  initial_note text check (char_length(initial_note) <= 300),
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.room_participants (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.message_rooms(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete restrict,
  participant_role text not null default 'member' check (participant_role in ('member', 'group_admin')),
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (room_id, user_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.message_rooms(id) on delete cascade,
  sender_user_id uuid not null references public.users(id) on delete restrict,
  acting_group_id uuid references public.groups(id) on delete set null,
  message_type text not null default 'text' check (message_type in ('text', 'stamp')),
  body text,
  stamp_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint messages_payload check (
    (message_type = 'text' and char_length(body) between 1 and 2000 and stamp_code is null)
    or (message_type = 'stamp' and stamp_code is not null and body is null)
  )
);

create table public.message_reads (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  read_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (message_id, user_id)
);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.message_rooms(id) on delete restrict,
  reviewer_user_id uuid references public.users(id) on delete restrict,
  reviewer_group_id uuid references public.groups(id) on delete restrict,
  reviewee_user_id uuid references public.users(id) on delete restrict,
  reviewee_group_id uuid references public.groups(id) on delete restrict,
  rating smallint not null check (rating between 1 and 5),
  comment text check (char_length(comment) <= 1000),
  submitted_at timestamptz not null default now(),
  blind_until timestamptz not null default (now() + interval '14 days'),
  is_published boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reviews_one_reviewer check ((reviewer_user_id is not null)::integer + (reviewer_group_id is not null)::integer = 1),
  constraint reviews_one_reviewee check ((reviewee_user_id is not null)::integer + (reviewee_group_id is not null)::integer = 1)
);
create unique index reviews_one_per_party_per_room on public.reviews (
  room_id,
  coalesce(reviewer_user_id, reviewer_group_id),
  (reviewer_user_id is not null)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users(id) on delete restrict,
  target_user_id uuid references public.users(id) on delete set null,
  target_message_id uuid references public.messages(id) on delete set null,
  reason text not null check (char_length(reason) between 1 and 100),
  details text check (char_length(details) <= 2000),
  status text not null default 'open' check (status in ('open', 'reviewing', 'closed')),
  admin_note text,
  resolved_at timestamptz,
  resolved_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reports_target check ((target_user_id is not null)::integer + (target_message_id is not null)::integer >= 1)
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  notification_type text not null check (notification_type in ('message_request', 'request_accepted', 'message', 'review_published', 'invitation')),
  title text not null,
  body text,
  reference_type text,
  reference_id uuid,
  is_read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.legal_documents (
  id uuid primary key default gen_random_uuid(),
  document_type text not null check (document_type in ('terms', 'privacy', 'content_policy', 'disclaimer')),
  version text not null,
  title text not null,
  body text not null,
  effective_at timestamptz not null,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (document_type, version)
);

create table public.user_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  legal_document_id uuid not null references public.legal_documents(id) on delete restrict,
  consented_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, legal_document_id)
);

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  inviter_id uuid not null references public.users(id) on delete restrict,
  invite_type text not null check (invite_type in ('friend', 'band')),
  code text not null unique check (char_length(code) between 8 and 64),
  target_group_id uuid references public.groups(id) on delete cascade,
  target_part_id uuid references public.parts(id) on delete set null,
  invitee_email text,
  status text not null default 'sent' check (status in ('sent', 'registered', 'expired')),
  registered_user_id uuid references public.users(id) on delete set null,
  registered_at timestamptz,
  reward_status text not null default 'none' check (reward_status in ('none', 'pending', 'granted')),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint invitations_band_target check (invite_type = 'friend' or target_group_id is not null)
);

create table public.admin_users (
  id uuid primary key default gen_random_uuid(),
  auth_uid uuid not null unique references auth.users(id) on delete restrict,
  email text not null unique,
  role text not null check (role in ('admin', 'moderator')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.admin_actions (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references public.admin_users(id) on delete restrict,
  action_type text not null check (action_type in ('suspend_user', 'unsuspend_user', 'force_withdraw_user', 'close_report', 'update_report')),
  target_type text not null,
  target_id uuid not null,
  reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.reports
  add constraint reports_resolved_by_admin_fkey
  foreign key (resolved_by) references public.admin_users(id) on delete set null;

create table public.ads (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text check (char_length(description) <= 500),
  image_url text,
  link_url text not null,
  advertiser text not null,
  area_target_id uuid references public.areas(id) on delete set null,
  is_active boolean not null default false,
  priority integer not null default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ads_schedule check (starts_at is null or ends_at is null or starts_at <= ends_at)
);

create table public.waitlist (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  area_text text,
  referral_source text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Phase 2 containers. No payment provider secret or payment operation is stored here.
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete restrict,
  provider text not null default 'stripe',
  provider_customer_id text,
  provider_subscription_id text unique,
  plan_code text,
  status text not null default 'inactive' check (status in ('inactive', 'trialing', 'active', 'past_due', 'canceled')),
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.payment_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete restrict,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  provider text not null default 'stripe',
  provider_payment_id text unique,
  amount_minor integer not null check (amount_minor >= 0),
  currency text not null default 'jpy',
  status text not null check (status in ('pending', 'succeeded', 'failed', 'refunded')),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Query indexes used by FlutterFlow list filters and RLS checks.
create index users_active_last_login_idx on public.users (last_login_at desc) where account_status = 'active';
create index groups_active_last_active_idx on public.groups (last_active_at desc) where account_status = 'active';
create index user_purposes_purpose_idx on public.user_purposes (purpose, user_id);
create index user_parts_part_idx on public.user_parts (part_id, user_id);
create index user_genres_genre_idx on public.user_genres (genre_id, user_id);
create index user_areas_area_idx on public.user_areas (area_id, user_id);
create index group_members_group_idx on public.group_members (group_id, role, user_id);
create index message_requests_receiver_idx on public.message_requests (receiver_user_id, receiver_group_id, status, created_at desc);
create index room_participants_user_idx on public.room_participants (user_id, room_id);
create index messages_room_created_idx on public.messages (room_id, created_at);
create index notifications_user_unread_idx on public.notifications (user_id, is_read, created_at desc);
create index ads_active_target_idx on public.ads (area_target_id, priority desc) where is_active;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- RLS controls rows, not individual columns. This trigger prevents a normal app user from
-- changing fields that must be sourced from Auth, billing, invitation redemption, or admin tools.
create or replace function public.protect_user_system_fields()
returns trigger
language plpgsql
as $$
begin
  if current_user not in ('postgres', 'service_role', 'supabase_admin')
    and not exists (
      select 1 from public.admin_users where auth_uid = auth.uid() and is_active
    ) then
    if new.auth_uid is distinct from old.auth_uid
      or new.email is distinct from old.email
      or new.phone is distinct from old.phone
      or new.phone_verified is distinct from old.phone_verified
      or new.sns_providers is distinct from old.sns_providers
      or new.account_status is distinct from old.account_status
      or new.withdrawn_at is distinct from old.withdrawn_at
      or new.last_login_at is distinct from old.last_login_at
      or new.premium_boost is distinct from old.premium_boost
      or new.referral_source is distinct from old.referral_source
      or new.invited_by is distinct from old.invited_by then
      raise exception 'system-managed user fields cannot be updated from the client';
    end if;
  end if;
  return new;
end;
$$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'users', 'groups', 'areas', 'parts', 'genres', 'user_purposes', 'user_parts',
    'user_genres', 'user_target_parts', 'user_recruiting_parts', 'user_areas',
    'group_genres', 'group_target_parts', 'group_recruiting_parts', 'group_members',
    'media_portfolios', 'blocks', 'message_requests', 'message_rooms',
    'room_participants', 'messages', 'message_reads', 'reviews', 'reports',
    'notifications', 'legal_documents', 'user_consents', 'invitations', 'admin_users',
    'admin_actions', 'ads', 'waitlist', 'subscriptions', 'payment_history'
  ]
  loop
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.set_updated_at()', table_name);
  end loop;
end;
$$;

create trigger protect_user_system_fields
before update on public.users
for each row execute function public.protect_user_system_fields();

-- Helpers are SECURITY DEFINER so RLS policies can ask membership questions without recursive RLS.
create or replace function public.current_user_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.users where auth_uid = auth.uid() limit 1;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_users
    where auth_uid = auth.uid() and is_active
  );
$$;

create or replace function public.is_group_admin(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.group_members
    where group_id = p_group_id and user_id = public.current_user_id() and role = 'admin'
  );
$$;

create or replace function public.can_initialize_group_member(
  p_group_id uuid,
  p_member_user_id uuid,
  p_member_role text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_member_user_id = public.current_user_id()
    and p_member_role = 'admin'
    and exists (
      select 1 from public.groups
      where id = p_group_id and created_by = public.current_user_id()
    )
    and not exists (
      select 1 from public.group_members where group_id = p_group_id
    );
$$;

create or replace function public.can_act_for_party(p_user_id uuid, p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select (p_user_id is not null and p_user_id = public.current_user_id())
      or (p_group_id is not null and public.is_group_admin(p_group_id));
$$;

create or replace function public.is_party_active(p_user_id uuid, p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select (p_user_id is not null and exists (
            select 1 from public.users where id = p_user_id and account_status = 'active'
          ))
      or (p_group_id is not null and exists (
            select 1 from public.groups where id = p_group_id and account_status = 'active'
          ));
$$;

create or replace function public.has_block_relationship(p_left_user_id uuid, p_right_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_left_user_id is not null and p_right_user_id is not null and exists (
    select 1 from public.blocks
    where (blocker_id = p_left_user_id and blocked_id = p_right_user_id)
       or (blocker_id = p_right_user_id and blocked_id = p_left_user_id)
  );
$$;

create or replace function public.is_public_profile_visible(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.users
    where id = p_user_id
      and account_status = 'active'
      and not public.has_block_relationship(public.current_user_id(), p_user_id)
  );
$$;

create or replace function public.is_valid_review_parties(
  p_room_id uuid,
  p_reviewer_user_id uuid,
  p_reviewer_group_id uuid,
  p_reviewee_user_id uuid,
  p_reviewee_group_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.message_rooms room
    join public.message_requests request on request.id = room.request_id
    where room.id = p_room_id
      and (
        (
          request.sender_user_id is not distinct from p_reviewer_user_id
          and request.sender_group_id is not distinct from p_reviewer_group_id
          and request.receiver_user_id is not distinct from p_reviewee_user_id
          and request.receiver_group_id is not distinct from p_reviewee_group_id
        )
        or (
          request.receiver_user_id is not distinct from p_reviewer_user_id
          and request.receiver_group_id is not distinct from p_reviewer_group_id
          and request.sender_user_id is not distinct from p_reviewee_user_id
          and request.sender_group_id is not distinct from p_reviewee_group_id
        )
      )
  );
$$;

create or replace function public.is_room_participant(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.room_participants
    where room_id = p_room_id and user_id = public.current_user_id() and left_at is null
  );
$$;

create or replace function public.is_room_group_party(p_room_id uuid, p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_group_id is not null
    and public.is_group_admin(p_group_id)
    and exists (
      select 1
      from public.message_rooms room
      join public.message_requests request on request.id = room.request_id
      where room.id = p_room_id
        and (request.sender_group_id = p_group_id or request.receiver_group_id = p_group_id)
    );
$$;

-- Call this RPC from FlutterFlow when a recipient accepts a pending request.
-- It atomically creates the one-to-one room and concrete user participants.
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
  select * into r from public.message_requests where id = p_request_id for update;
  if not found or r.status <> 'pending' then
    raise exception 'pending message request not found';
  end if;
  if not public.can_act_for_party(r.receiver_user_id, r.receiver_group_id) then
    raise exception 'only the recipient can accept this request';
  end if;
  if not public.is_party_active(r.sender_user_id, r.sender_group_id)
    or not public.is_party_active(r.receiver_user_id, r.receiver_group_id) then
    raise exception 'inactive party cannot start a message room';
  end if;

  update public.message_requests
  set status = 'accepted', responded_at = now(), responded_by = v_actor_id
  where id = r.id;

  insert into public.message_rooms (request_id, initial_note, last_message_at)
  values (r.id, r.note, now())
  returning id into v_room_id;

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

-- Publishes both sides immediately after reciprocal review submission, or any due review after 14 days.
-- Schedule this function from a protected cron/Edge Function; it is not callable by app clients.
create or replace function public.publish_due_reviews()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  changed_count integer;
begin
  update public.reviews r
  set is_published = true, published_at = coalesce(r.published_at, now())
  where not r.is_published
    and (
      r.blind_until <= now()
      or exists (
        select 1 from public.reviews counterpart
        where counterpart.room_id = r.room_id
          and counterpart.id <> r.id
          and counterpart.reviewer_user_id is not distinct from r.reviewee_user_id
          and counterpart.reviewer_group_id is not distinct from r.reviewee_group_id
          and counterpart.reviewee_user_id is not distinct from r.reviewer_user_id
          and counterpart.reviewee_group_id is not distinct from r.reviewer_group_id
      )
    );
  get diagnostics changed_count = row_count;
  return changed_count;
end;
$$;

create or replace function public.publish_reciprocal_reviews()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.publish_due_reviews();
  return new;
end;
$$;

create trigger publish_reciprocal_reviews
after insert on public.reviews
for each row execute function public.publish_reciprocal_reviews();

-- User-side withdrawal is logical. Conversation and review history remain intact.
create or replace function public.withdraw_current_user()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.current_user_id();
  v_group_id uuid;
  v_successor_id uuid;
begin
  if v_user_id is null then
    raise exception 'profile not found';
  end if;

  for v_group_id in
    select group_id from public.group_members
    where user_id = v_user_id and role = 'admin'
  loop
    select gm.user_id into v_successor_id
    from public.group_members gm
    join public.users u on u.id = gm.user_id
    where gm.group_id = v_group_id
      and gm.user_id <> v_user_id
      and u.account_status = 'active'
    order by gm.joined_at asc
    limit 1;

    update public.group_members
    set role = 'member'
    where group_id = v_group_id and user_id = v_user_id;

    if v_successor_id is null then
      update public.groups set account_status = 'suspended' where id = v_group_id;
    else
      update public.group_members
      set role = 'admin'
      where group_id = v_group_id and user_id = v_successor_id;
    end if;
  end loop;

  update public.users
  set account_status = 'withdrawn', withdrawn_at = now()
  where id = v_user_id;
end;
$$;

-- Redeem codes through RPC instead of exposing invitation lists to other users.
create or replace function public.redeem_invitation(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invitation public.invitations%rowtype;
  v_user_id uuid := public.current_user_id();
begin
  if v_user_id is null then
    raise exception 'profile not found';
  end if;

  select * into v_invitation
  from public.invitations
  where code = p_code
    and status = 'sent'
    and (expires_at is null or expires_at > now())
  for update;
  if not found then
    raise exception 'valid invitation not found';
  end if;
  if v_invitation.inviter_id = v_user_id then
    raise exception 'cannot redeem your own invitation';
  end if;

  update public.invitations
  set status = 'registered', registered_user_id = v_user_id, registered_at = now()
  where id = v_invitation.id;
  update public.users
  set invited_by = coalesce(invited_by, v_invitation.inviter_id)
  where id = v_user_id;

  if v_invitation.invite_type = 'band' then
    insert into public.group_members (user_id, group_id, part_id, role)
    values (v_user_id, v_invitation.target_group_id, v_invitation.target_part_id, 'member')
    on conflict (user_id, group_id) do nothing;
  end if;
  return v_invitation.id;
end;
$$;

-- Public search never reads the private users row directly. The view deliberately excludes
-- email, phone, birth date, consent, account administration, and invitation-tracking fields.
create or replace view public.user_public_profiles
with (security_invoker = false)
as
select
  u.id,
  u.display_name,
  u.avatar_url,
  case when u.show_age then date_part('year', age(current_date, u.birth_date))::integer end as age,
  case when u.show_gender then u.gender end as gender,
  u.experience_level,
  u.activity_frequency,
  u.plays_instrument,
  u.employment,
  u.favorite_artists,
  u.gear,
  u.bio,
  u.style_orientation,
  u.is_recruiting,
  u.recruit_gender,
  u.recruit_age_min,
  u.recruit_age_max,
  u.recruit_purpose,
  u.last_login_at,
  u.created_at,
  u.updated_at
from public.users u
where u.account_status = 'active'
  and not public.has_block_relationship(public.current_user_id(), u.id);

create or replace view public.user_public_areas
with (security_invoker = false)
as
select
  ua.user_id,
  a.id as area_id,
  a.parent_id,
  a.code,
  a.name,
  a.level,
  ua.is_primary
from public.user_areas ua
join public.areas a on a.id = ua.area_id and a.is_active
join public.users u on u.id = ua.user_id and u.account_status = 'active'
where (a.level = 'prefecture' or ua.show_on_profile)
  and not public.has_block_relationship(public.current_user_id(), ua.user_id);

-- PostgreSQL grants EXECUTE on new functions to PUBLIC by default. Restrict every
-- SECURITY DEFINER helper explicitly so it cannot become an information side channel.
revoke all on function public.current_user_id() from public, anon;
revoke all on function public.is_admin() from public, anon;
revoke all on function public.is_group_admin(uuid) from public, anon;
revoke all on function public.can_initialize_group_member(uuid, uuid, text) from public, anon;
revoke all on function public.can_act_for_party(uuid, uuid) from public, anon;
revoke all on function public.is_party_active(uuid, uuid) from public, anon;
revoke all on function public.has_block_relationship(uuid, uuid) from public, anon;
revoke all on function public.is_public_profile_visible(uuid) from public, anon;
revoke all on function public.is_room_participant(uuid) from public, anon;
revoke all on function public.is_room_group_party(uuid, uuid) from public, anon;
revoke all on function public.is_valid_review_parties(uuid, uuid, uuid, uuid, uuid) from public, anon;
revoke all on function public.accept_message_request(uuid) from public, anon;
revoke all on function public.withdraw_current_user() from public, anon;
revoke all on function public.redeem_invitation(text) from public, anon;
revoke all on function public.publish_due_reviews() from public, anon, authenticated;
grant execute on function public.current_user_id() to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_group_admin(uuid) to authenticated;
grant execute on function public.can_initialize_group_member(uuid, uuid, text) to authenticated;
grant execute on function public.can_act_for_party(uuid, uuid) to authenticated;
grant execute on function public.is_party_active(uuid, uuid) to authenticated;
grant execute on function public.has_block_relationship(uuid, uuid) to authenticated;
grant execute on function public.is_public_profile_visible(uuid) to authenticated;
grant execute on function public.is_room_participant(uuid) to authenticated;
grant execute on function public.is_room_group_party(uuid, uuid) to authenticated;
grant execute on function public.is_valid_review_parties(uuid, uuid, uuid, uuid, uuid) to authenticated;
grant execute on function public.accept_message_request(uuid) to authenticated;
grant execute on function public.withdraw_current_user() to authenticated;
grant execute on function public.redeem_invitation(text) to authenticated;
grant select on public.user_public_profiles to authenticated;
grant select on public.user_public_areas to authenticated;

commit;

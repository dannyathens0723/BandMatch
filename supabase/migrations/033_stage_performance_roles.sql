-- STAGE performance-role foundation.
--
-- Performance roles are intentionally separate from the legacy BandMatch
-- parts taxonomy. Selecting a role never grants crew governance permissions,
-- and selecting the instructor role never implies professional verification.
--
-- Existing users receive no inferred role assignment. Recruitment role slots
-- and dance-genre activation remain deferred to later, separately deployable
-- migrations.
-- Run after 032_stage_taxonomy_and_user_profile.sql.

begin;

-- Fail before DDL when the expected Migration 032 baseline or helper
-- functions are unavailable. Existing 033-named objects indicate a partial
-- application or catalog drift and must be reviewed instead of repaired.
do $preflight$
declare
  v_dance_genre_codes text[] := array[
    'dance_kpop',
    'dance_hiphop',
    'dance_jazz',
    'dance_jazz_hiphop',
    'dance_girls_hiphop',
    'dance_waack',
    'dance_locking',
    'dance_popping',
    'dance_breaking',
    'dance_house',
    'dance_other'
  ];
begin
  if to_regclass('public.users') is null
    or to_regclass('public.genres') is null
    or to_regclass('public.parts') is null
    or to_regclass('public.user_parts') is null
    or to_regclass('public.user_target_parts') is null
    or to_regclass('public.user_recruiting_parts') is null
    or to_regclass('public.group_target_parts') is null
    or to_regclass('public.group_recruiting_parts') is null
    or to_regclass('public.group_members') is null
    or to_regclass('public.invitations') is null
    or to_regclass('public.recruitment_post_parts') is null
    or to_regclass('public.user_genres') is null then
    raise exception 'Migration 033 requires the complete Migration 032 baseline'
      using errcode = '55000';
  end if;

  if to_regprocedure('public.current_user_id()') is null
    or to_regprocedure('public.is_admin()') is null
    or to_regprocedure('public.set_updated_at()') is null then
    raise exception 'Migration 033 requires current user, admin, and timestamp helpers'
      using errcode = '55000';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'genres'
      and column_name = 'domain'
      and data_type = 'text'
      and is_nullable = 'NO'
      and column_default = '''band''::text'
  ) or not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'genres'
      and column_name = 'category'
      and data_type = 'text'
      and is_nullable = 'NO'
      and column_default = '''legacy_music''::text'
  ) or not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'performance_domain'
      and data_type = 'text'
      and is_nullable = 'YES'
      and column_default is null
  ) or not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'professional_state'
      and data_type = 'text'
      and is_nullable = 'NO'
      and column_default = '''general''::text'
  ) then
    raise exception 'Migration 032 taxonomy or user-profile columns are incompatible'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from pg_constraint constraint_row
    where constraint_row.convalidated
      and (
        (
          constraint_row.conrelid = 'public.genres'::regclass
          and constraint_row.conname in (
            'genres_domain_check',
            'genres_category_check'
          )
        )
        or (
          constraint_row.conrelid = 'public.users'::regclass
          and constraint_row.conname in (
            'users_performance_domain_check',
            'users_professional_state_check'
          )
        )
      )
  ) <> 4 then
    raise exception 'Migration 032 taxonomy constraints are missing or unvalidated'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from public.genres genre
    where genre.code = any(v_dance_genre_codes)
  ) <> 11
    or exists (
      select 1
      from public.genres genre
      where genre.code = any(v_dance_genre_codes)
        and (
          genre.domain is distinct from 'dance'
          or genre.is_active is distinct from false
        )
    )
    or exists (
      select 1
      from public.genres genre
      where left(genre.code, 6) = 'dance_'
        and not (genre.code = any(v_dance_genre_codes))
    ) then
    raise exception 'Migration 032 dance genres are missing, drifted, or active'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from public.users profile
    where profile.professional_state not in (
      'general',
      'professional_unverified'
    )
      or (
        profile.performance_domain is not null
        and profile.performance_domain not in (
          'band',
          'dance',
          'multi_domain'
        )
      )
  ) then
    raise exception 'Migration 032 user taxonomy values are incompatible'
      using errcode = '55000';
  end if;

  if to_regclass('public.performance_roles') is not null
    or to_regclass('public.user_performance_roles') is not null
    or to_regclass(
      'public.user_performance_roles_one_primary_per_user'
    ) is not null
    or to_regclass(
      'public.user_performance_roles_role_user_idx'
    ) is not null
    or exists (
      select 1
      from pg_proc procedure_row
      join pg_namespace namespace
        on namespace.oid = procedure_row.pronamespace
      where namespace.nspname = 'public'
        and procedure_row.proname in (
          'get_active_performance_roles_v1',
          'get_my_performance_roles_v1',
          'replace_my_performance_roles_v1'
        )
    ) then
    raise exception
      'Migration 033 objects already exist; review possible partial application'
      using errcode = '55000';
  end if;
end;
$preflight$;

-- Stabilize the legacy data snapshots while the additive objects are created.
lock table
  public.users,
  public.genres,
  public.parts,
  public.user_parts,
  public.user_target_parts,
  public.user_recruiting_parts,
  public.group_target_parts,
  public.group_recruiting_parts,
  public.group_members,
  public.invitations,
  public.recruitment_post_parts,
  public.user_genres
in share row exclusive mode;

create temporary table migration_033_legacy_snapshot (
  parts_rows jsonb not null,
  part_join_rows jsonb not null,
  genre_rows jsonb not null,
  user_genre_rows jsonb not null,
  user_taxonomy_rows jsonb not null,
  view_definitions jsonb not null,
  function_definitions jsonb not null,
  policy_definitions jsonb not null
) on commit drop;

insert into pg_temp.migration_033_legacy_snapshot (
  parts_rows,
  part_join_rows,
  genre_rows,
  user_genre_rows,
  user_taxonomy_rows,
  view_definitions,
  function_definitions,
  policy_definitions
)
select
  (
    select coalesce(
      jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
      '[]'::jsonb
    )
    from public.parts snapshot_row
  ),
  jsonb_build_object(
    'user_parts',
    (
      select coalesce(
        jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
        '[]'::jsonb
      )
      from public.user_parts snapshot_row
    ),
    'user_target_parts',
    (
      select coalesce(
        jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
        '[]'::jsonb
      )
      from public.user_target_parts snapshot_row
    ),
    'user_recruiting_parts',
    (
      select coalesce(
        jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
        '[]'::jsonb
      )
      from public.user_recruiting_parts snapshot_row
    ),
    'group_target_parts',
    (
      select coalesce(
        jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
        '[]'::jsonb
      )
      from public.group_target_parts snapshot_row
    ),
    'group_recruiting_parts',
    (
      select coalesce(
        jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
        '[]'::jsonb
      )
      from public.group_recruiting_parts snapshot_row
    ),
    'group_members',
    (
      select coalesce(
        jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
        '[]'::jsonb
      )
      from public.group_members snapshot_row
    ),
    'invitations',
    (
      select coalesce(
        jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
        '[]'::jsonb
      )
      from public.invitations snapshot_row
    ),
    'recruitment_post_parts',
    (
      select coalesce(
        jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
        '[]'::jsonb
      )
      from public.recruitment_post_parts snapshot_row
    )
  ),
  (
    select coalesce(
      jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
      '[]'::jsonb
    )
    from public.genres snapshot_row
  ),
  (
    select coalesce(
      jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
      '[]'::jsonb
    )
    from public.user_genres snapshot_row
  ),
  (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', profile.id,
          'performance_domain', profile.performance_domain,
          'professional_state', profile.professional_state
        )
        order by profile.id
      ),
      '[]'::jsonb
    )
    from public.users profile
  ),
  (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'oid', relation.oid,
          'schema', namespace.nspname,
          'name', relation.relname,
          'definition', pg_get_viewdef(relation.oid, false)
        )
        order by relation.oid
      ),
      '[]'::jsonb
    )
    from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relkind = 'v'
  ),
  (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'oid', procedure_row.oid,
          'schema', namespace.nspname,
          'name', procedure_row.proname,
          'definition', pg_get_functiondef(procedure_row.oid)
        )
        order by procedure_row.oid
      ),
      '[]'::jsonb
    )
    from pg_proc procedure_row
    join pg_namespace namespace
      on namespace.oid = procedure_row.pronamespace
    where namespace.nspname = 'public'
      and procedure_row.prokind in ('f', 'p')
      and procedure_row.proname not in (
        'get_active_performance_roles_v1',
        'get_my_performance_roles_v1',
        'replace_my_performance_roles_v1'
      )
  ),
  (
    select coalesce(
      jsonb_agg(to_jsonb(policy_row) order by policy_row.tablename, policy_row.policyname),
      '[]'::jsonb
    )
    from pg_policies policy_row
    where policy_row.schemaname = 'public'
      and policy_row.tablename not in (
        'performance_roles',
        'user_performance_roles'
      )
  );

-- A performance role is a project capability, not an instrument part,
-- governance permission, genre, experience level, or verification status.
create table public.performance_roles (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  name text not null,
  domain text not null,
  sort_order smallint not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint performance_roles_code_key unique (code),
  constraint performance_roles_domain_name_key unique (domain, name),
  constraint performance_roles_domain_sort_order_key
    unique (domain, sort_order),
  constraint performance_roles_domain_check
    check (domain in ('band', 'dance')),
  constraint performance_roles_name_length_check
    check (char_length(name) between 1 and 60)
);

create table public.user_performance_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null
    references public.users(id) on delete cascade,
  performance_role_id uuid not null
    references public.performance_roles(id) on delete restrict,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_performance_roles_user_role_key
    unique (user_id, performance_role_id)
);

create unique index user_performance_roles_one_primary_per_user
  on public.user_performance_roles (user_id)
  where is_primary;

create index user_performance_roles_role_user_idx
  on public.user_performance_roles (performance_role_id, user_id);

create trigger set_updated_at
before update on public.performance_roles
for each row execute function public.set_updated_at();

create trigger set_updated_at
before update on public.user_performance_roles
for each row execute function public.set_updated_at();

-- Stable code is the seed identity. Compatible rows retain their UUID; any
-- immutable taxonomy conflict aborts instead of being overwritten.
do $seed_preflight$
begin
  if exists (
    with expected(code, name, domain, sort_order, is_active) as (
      values
        ('dance_dancer', 'ダンサー', 'dance', 101::smallint, true),
        ('dance_choreographer', '振付師', 'dance', 102::smallint, true),
        (
          'dance_instructor',
          'インストラクター',
          'dance',
          103::smallint,
          true
        ),
        ('dance_other', 'その他', 'dance', 199::smallint, true)
    )
    select 1
    from expected
    join public.performance_roles role on role.code = expected.code
    where role.name is distinct from expected.name
      or role.domain is distinct from expected.domain
      or role.sort_order is distinct from expected.sort_order
      or role.is_active is distinct from expected.is_active
  ) then
    raise exception 'Existing performance-role code has conflicting metadata'
      using errcode = '55000';
  end if;

  if exists (
    with expected(code, name, domain, sort_order) as (
      values
        ('dance_dancer', 'ダンサー', 'dance', 101::smallint),
        ('dance_choreographer', '振付師', 'dance', 102::smallint),
        (
          'dance_instructor',
          'インストラクター',
          'dance',
          103::smallint
        ),
        ('dance_other', 'その他', 'dance', 199::smallint)
    )
    select 1
    from expected
    join public.performance_roles role
      on role.domain = expected.domain
      and (
        role.name = expected.name
        or role.sort_order = expected.sort_order
      )
      and role.code <> expected.code
  ) then
    raise exception
      'Approved performance-role name or sort order belongs to another code'
      using errcode = '55000';
  end if;
end;
$seed_preflight$;

insert into public.performance_roles (
  code,
  name,
  domain,
  sort_order,
  is_active
)
values
  ('dance_dancer', 'ダンサー', 'dance', 101, true),
  ('dance_choreographer', '振付師', 'dance', 102, true),
  ('dance_instructor', 'インストラクター', 'dance', 103, true),
  ('dance_other', 'その他', 'dance', 199, true)
on conflict (code) do nothing;

alter table public.performance_roles enable row level security;
alter table public.user_performance_roles enable row level security;

create policy performance_roles_read_active
on public.performance_roles
for select to authenticated
using (is_active);

-- Mirrors the existing master-data administration rule. Client-side DML is
-- not granted by this migration, so taxonomy changes remain migration/operator
-- work until a dedicated audited administration contract is approved.
create policy performance_roles_admin_manage
on public.performance_roles
for all to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy user_performance_roles_read_self
on public.user_performance_roles
for select to authenticated
using (user_id = public.current_user_id());

revoke all on table public.performance_roles
  from public, anon, authenticated;
revoke all on table public.user_performance_roles
  from public, anon, authenticated;

grant select on table public.performance_roles to authenticated;
grant select on table public.user_performance_roles to authenticated;

-- Safe domain-specific master contract. This remains SECURITY INVOKER so the
-- active-row RLS policy is still authoritative.
create function public.get_active_performance_roles_v1(
  p_domain text
)
returns table (
  id uuid,
  code text,
  name text,
  domain text,
  sort_order smallint
)
language plpgsql
stable
security invoker
set search_path = public, pg_temp
as $$
begin
  if p_domain is null or p_domain not in ('band', 'dance') then
    raise exception 'unsupported performance-role domain'
      using errcode = '22023';
  end if;

  return query
  select
    role.id,
    role.code,
    role.name,
    role.domain,
    role.sort_order
  from public.performance_roles role
  where role.domain = p_domain
    and role.is_active
  order by role.sort_order, role.code;
end;
$$;

-- Self-only read contract includes is_active so a retired assignment remains
-- understandable and removable without exposing any private user fields.
create function public.get_my_performance_roles_v1()
returns table (
  id uuid,
  code text,
  name text,
  domain text,
  sort_order smallint,
  is_primary boolean,
  is_active boolean
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

  return query
  select
    role.id,
    role.code,
    role.name,
    role.domain,
    role.sort_order,
    assignment.is_primary,
    role.is_active
  from public.user_performance_roles assignment
  join public.performance_roles role
    on role.id = assignment.performance_role_id
  where assignment.user_id = v_user_id
  order by assignment.is_primary desc, role.sort_order, role.code;
end;
$$;

-- Atomic self replacement. The RPC has no target-user parameter and accepts
-- only active dance roles in v1. It does not read or modify professional,
-- governance, billing, authentication, or other private user fields.
create function public.replace_my_performance_roles_v1(
  p_performance_domain text,
  p_role_ids uuid[],
  p_primary_role_id uuid
)
returns table (
  id uuid,
  code text,
  name text,
  domain text,
  sort_order smallint,
  is_primary boolean,
  is_active boolean
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := public.current_user_id();
  v_account_status text;
  v_requested_count integer;
  v_matching_count integer;
begin
  if v_user_id is null then
    raise exception 'sign in is required';
  end if;

  select profile.account_status
  into v_account_status
  from public.users profile
  where profile.id = v_user_id
  for update;

  if not found then
    raise exception 'active profile is required';
  end if;

  if v_account_status <> 'active' then
    raise exception 'active profile is required';
  end if;

  if p_performance_domain is distinct from 'dance' then
    raise exception 'performance-role v1 supports dance only'
      using errcode = '22023';
  end if;

  if p_role_ids is null or cardinality(p_role_ids) = 0 then
    raise exception 'at least one performance role is required'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from unnest(p_role_ids) selected(role_id)
    where selected.role_id is null
  ) then
    raise exception 'performance-role IDs cannot contain null'
      using errcode = '22023';
  end if;

  select
    count(*)::integer,
    count(distinct selected.role_id)::integer
  into v_requested_count, v_matching_count
  from unnest(p_role_ids) selected(role_id);

  if v_requested_count <> v_matching_count then
    raise exception 'duplicate performance-role ID'
      using errcode = '22023';
  end if;

  if p_primary_role_id is null
    or not (p_primary_role_id = any(p_role_ids)) then
    raise exception 'primary role must be one of the selected roles'
      using errcode = '22023';
  end if;

  -- Lock the selected master rows so none can be retired between validation
  -- and insertion.
  perform role.id
  from public.performance_roles role
  where role.id = any(p_role_ids)
  for share;

  select count(*)::integer
  into v_matching_count
  from public.performance_roles role
  where role.id = any(p_role_ids)
    and role.is_active
    and role.domain = 'dance';

  if v_matching_count <> v_requested_count then
    raise exception 'requested performance role is missing, inactive, or unsupported'
      using errcode = '22023';
  end if;

  update public.users profile
  set performance_domain = 'dance'
  where profile.id = v_user_id;

  delete from public.user_performance_roles assignment
  where assignment.user_id = v_user_id;

  insert into public.user_performance_roles (
    user_id,
    performance_role_id,
    is_primary
  )
  select
    v_user_id,
    selected.role_id,
    selected.role_id = p_primary_role_id
  from unnest(p_role_ids) with ordinality
    as selected(role_id, ordinal)
  order by selected.ordinal;

  return query
  select
    role.id,
    role.code,
    role.name,
    role.domain,
    role.sort_order,
    assignment.is_primary,
    role.is_active
  from public.user_performance_roles assignment
  join public.performance_roles role
    on role.id = assignment.performance_role_id
  where assignment.user_id = v_user_id
  order by assignment.is_primary desc, role.sort_order, role.code;
end;
$$;

comment on table public.performance_roles is
  'STAGE functional performance roles, separate from legacy BandMatch parts.';
comment on table public.user_performance_roles is
  'Explicit self-selected STAGE roles; roles do not grant crew permissions.';
comment on function public.get_active_performance_roles_v1(text) is
  'Returns the active safe role master projection for one approved domain.';
comment on function public.get_my_performance_roles_v1() is
  'Returns only the signed-in user''s safe role assignments.';
comment on function public.replace_my_performance_roles_v1(text, uuid[], uuid) is
  'Atomically replaces only the signed-in user''s active dance roles.';

revoke all on function public.get_active_performance_roles_v1(text)
  from public, anon;
revoke all on function public.get_my_performance_roles_v1()
  from public, anon;
revoke all on function public.replace_my_performance_roles_v1(
  text,
  uuid[],
  uuid
) from public, anon;

grant execute on function public.get_active_performance_roles_v1(text)
  to authenticated;
grant execute on function public.get_my_performance_roles_v1()
  to authenticated;
grant execute on function public.replace_my_performance_roles_v1(
  text,
  uuid[],
  uuid
) to authenticated;

-- Verify the additive contract and prove that legacy taxonomy, joins,
-- professional state, views, RPCs, and policies were not replaced.
do $postconditions$
declare
  v_snapshot record;
  v_function_oid oid;
  v_function_config text[];
  v_parts_after jsonb;
  v_part_joins_after jsonb;
  v_genres_after jsonb;
  v_user_genres_after jsonb;
  v_user_taxonomy_after jsonb;
  v_views_after jsonb;
  v_functions_after jsonb;
  v_policies_after jsonb;
begin
  select *
  into v_snapshot
  from pg_temp.migration_033_legacy_snapshot;

  if (
    select count(*)
    from public.performance_roles
  ) <> 4 or exists (
    with expected(code, name, domain, sort_order, is_active) as (
      values
        ('dance_dancer', 'ダンサー', 'dance', 101::smallint, true),
        ('dance_choreographer', '振付師', 'dance', 102::smallint, true),
        (
          'dance_instructor',
          'インストラクター',
          'dance',
          103::smallint,
          true
        ),
        ('dance_other', 'その他', 'dance', 199::smallint, true)
    )
    select 1
    from expected
    left join public.performance_roles role on role.code = expected.code
    where role.id is null
      or role.name is distinct from expected.name
      or role.domain is distinct from expected.domain
      or role.sort_order is distinct from expected.sort_order
      or role.is_active is distinct from expected.is_active
  ) then
    raise exception 'Migration 033 role seed verification failed'
      using errcode = '55000';
  end if;

  if exists (
    select 1 from public.user_performance_roles
  ) then
    raise exception 'Migration 033 must not assign roles to existing users'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from pg_constraint constraint_row
    where constraint_row.convalidated
      and constraint_row.conrelid = 'public.performance_roles'::regclass
      and constraint_row.conname in (
        'performance_roles_pkey',
        'performance_roles_code_key',
        'performance_roles_domain_name_key',
        'performance_roles_domain_sort_order_key',
        'performance_roles_domain_check',
        'performance_roles_name_length_check'
      )
  ) <> 6 or (
    select count(*)
    from pg_constraint constraint_row
    where constraint_row.convalidated
      and constraint_row.conrelid =
        'public.user_performance_roles'::regclass
      and constraint_row.conname in (
        'user_performance_roles_pkey',
        'user_performance_roles_user_id_fkey',
        'user_performance_roles_performance_role_id_fkey',
        'user_performance_roles_user_role_key'
      )
  ) <> 4 then
    raise exception 'Migration 033 table constraints are incomplete'
      using errcode = '55000';
  end if;

  if not exists (
    select 1
    from pg_index index_row
    join pg_class index_relation
      on index_relation.oid = index_row.indexrelid
    where index_row.indrelid =
        'public.user_performance_roles'::regclass
      and index_relation.relname =
        'user_performance_roles_one_primary_per_user'
      and index_row.indisunique
      and pg_get_expr(
        index_row.indpred,
        index_row.indrelid
      ) in ('is_primary', '(is_primary = true)')
  ) or to_regclass(
    'public.user_performance_roles_role_user_idx'
  ) is null then
    raise exception 'Migration 033 role indexes are incomplete'
      using errcode = '55000';
  end if;

  if not (
    select relation.relrowsecurity
    from pg_class relation
    where relation.oid = 'public.performance_roles'::regclass
  ) or not (
    select relation.relrowsecurity
    from pg_class relation
    where relation.oid = 'public.user_performance_roles'::regclass
  ) then
    raise exception 'Migration 033 RLS is not enabled'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from pg_policies policy_row
    where policy_row.schemaname = 'public'
      and (
        (
          policy_row.tablename = 'performance_roles'
          and policy_row.policyname in (
            'performance_roles_read_active',
            'performance_roles_admin_manage'
          )
        )
        or (
          policy_row.tablename = 'user_performance_roles'
          and policy_row.policyname =
            'user_performance_roles_read_self'
        )
      )
  ) <> 3 or (
    select count(*)
    from pg_policies policy_row
    where policy_row.schemaname = 'public'
      and policy_row.tablename in (
        'performance_roles',
        'user_performance_roles'
      )
  ) <> 3 then
    raise exception 'Migration 033 RLS policies are incomplete or unexpected'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from information_schema.table_privileges privilege_row
    where privilege_row.table_schema = 'public'
      and privilege_row.table_name in (
        'performance_roles',
        'user_performance_roles'
      )
      and privilege_row.grantee in ('PUBLIC', 'anon')
  ) or exists (
    select 1
    from information_schema.table_privileges privilege_row
    where privilege_row.table_schema = 'public'
      and privilege_row.table_name in (
        'performance_roles',
        'user_performance_roles'
      )
      and privilege_row.grantee = 'authenticated'
      and privilege_row.privilege_type in (
        'INSERT',
        'UPDATE',
        'DELETE',
        'TRUNCATE',
        'REFERENCES',
        'TRIGGER'
      )
  ) then
    raise exception 'Migration 033 table grants are broader than approved'
      using errcode = '55000';
  end if;

  if not has_table_privilege(
    'authenticated',
    'public.performance_roles',
    'SELECT'
  ) or not has_table_privilege(
    'authenticated',
    'public.user_performance_roles',
    'SELECT'
  ) then
    raise exception 'Migration 033 authenticated read grants are missing'
      using errcode = '55000';
  end if;

  v_function_oid := to_regprocedure(
    'public.get_active_performance_roles_v1(text)'
  );
  if v_function_oid is null
    or (
      select procedure_row.prosecdef
      from pg_proc procedure_row
      where procedure_row.oid = v_function_oid
    )
    or pg_get_function_result(v_function_oid) <>
      'TABLE(id uuid, code text, name text, domain text, sort_order smallint)'
    or not has_function_privilege(
      'authenticated',
      v_function_oid,
      'EXECUTE'
    )
    or has_function_privilege('anon', v_function_oid, 'EXECUTE')
    or exists (
      select 1
      from pg_proc procedure_row,
        lateral aclexplode(
          coalesce(
            procedure_row.proacl,
            acldefault('f', procedure_row.proowner)
          )
        ) acl_row
      where procedure_row.oid = v_function_oid
        and acl_row.grantee = 0
        and acl_row.privilege_type = 'EXECUTE'
    ) then
    raise exception 'Active performance-role RPC contract is incompatible'
      using errcode = '55000';
  end if;

  v_function_oid := to_regprocedure(
    'public.get_my_performance_roles_v1()'
  );
  select procedure_row.proconfig
  into v_function_config
  from pg_proc procedure_row
  where procedure_row.oid = v_function_oid;

  if v_function_oid is null
    or not (
      select procedure_row.prosecdef
      from pg_proc procedure_row
      where procedure_row.oid = v_function_oid
    )
    or not coalesce(
      v_function_config @> array['search_path=public, pg_temp'],
      false
    )
    or pg_get_function_result(v_function_oid) <>
      'TABLE(id uuid, code text, name text, domain text, sort_order smallint, is_primary boolean, is_active boolean)'
    or not has_function_privilege(
      'authenticated',
      v_function_oid,
      'EXECUTE'
    )
    or has_function_privilege('anon', v_function_oid, 'EXECUTE')
    or exists (
      select 1
      from pg_proc procedure_row,
        lateral aclexplode(
          coalesce(
            procedure_row.proacl,
            acldefault('f', procedure_row.proowner)
          )
        ) acl_row
      where procedure_row.oid = v_function_oid
        and acl_row.grantee = 0
        and acl_row.privilege_type = 'EXECUTE'
    ) then
    raise exception 'Current-user performance-role read RPC is incompatible'
      using errcode = '55000';
  end if;

  v_function_oid := to_regprocedure(
    'public.replace_my_performance_roles_v1(text,uuid[],uuid)'
  );
  select procedure_row.proconfig
  into v_function_config
  from pg_proc procedure_row
  where procedure_row.oid = v_function_oid;

  if v_function_oid is null
    or not (
      select procedure_row.prosecdef
      from pg_proc procedure_row
      where procedure_row.oid = v_function_oid
    )
    or not coalesce(
      v_function_config @> array['search_path=public, pg_temp'],
      false
    )
    or pg_get_function_result(v_function_oid) <>
      'TABLE(id uuid, code text, name text, domain text, sort_order smallint, is_primary boolean, is_active boolean)'
    or not has_function_privilege(
      'authenticated',
      v_function_oid,
      'EXECUTE'
    )
    or has_function_privilege('anon', v_function_oid, 'EXECUTE')
    or exists (
      select 1
      from pg_proc procedure_row,
        lateral aclexplode(
          coalesce(
            procedure_row.proacl,
            acldefault('f', procedure_row.proowner)
          )
        ) acl_row
      where procedure_row.oid = v_function_oid
        and acl_row.grantee = 0
        and acl_row.privilege_type = 'EXECUTE'
    ) then
    raise exception 'Performance-role replacement RPC is incompatible'
      using errcode = '55000';
  end if;

  select coalesce(
    jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
    '[]'::jsonb
  )
  into v_parts_after
  from public.parts snapshot_row;

  v_part_joins_after := jsonb_build_object(
    'user_parts',
    (
      select coalesce(
        jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
        '[]'::jsonb
      )
      from public.user_parts snapshot_row
    ),
    'user_target_parts',
    (
      select coalesce(
        jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
        '[]'::jsonb
      )
      from public.user_target_parts snapshot_row
    ),
    'user_recruiting_parts',
    (
      select coalesce(
        jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
        '[]'::jsonb
      )
      from public.user_recruiting_parts snapshot_row
    ),
    'group_target_parts',
    (
      select coalesce(
        jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
        '[]'::jsonb
      )
      from public.group_target_parts snapshot_row
    ),
    'group_recruiting_parts',
    (
      select coalesce(
        jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
        '[]'::jsonb
      )
      from public.group_recruiting_parts snapshot_row
    ),
    'group_members',
    (
      select coalesce(
        jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
        '[]'::jsonb
      )
      from public.group_members snapshot_row
    ),
    'invitations',
    (
      select coalesce(
        jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
        '[]'::jsonb
      )
      from public.invitations snapshot_row
    ),
    'recruitment_post_parts',
    (
      select coalesce(
        jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
        '[]'::jsonb
      )
      from public.recruitment_post_parts snapshot_row
    )
  );

  select coalesce(
    jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
    '[]'::jsonb
  )
  into v_genres_after
  from public.genres snapshot_row;

  select coalesce(
    jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
    '[]'::jsonb
  )
  into v_user_genres_after
  from public.user_genres snapshot_row;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', profile.id,
        'performance_domain', profile.performance_domain,
        'professional_state', profile.professional_state
      )
      order by profile.id
    ),
    '[]'::jsonb
  )
  into v_user_taxonomy_after
  from public.users profile;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'oid', relation.oid,
        'schema', namespace.nspname,
        'name', relation.relname,
        'definition', pg_get_viewdef(relation.oid, false)
      )
      order by relation.oid
    ),
    '[]'::jsonb
  )
  into v_views_after
  from pg_class relation
  join pg_namespace namespace on namespace.oid = relation.relnamespace
  where namespace.nspname = 'public'
    and relation.relkind = 'v';

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'oid', procedure_row.oid,
        'schema', namespace.nspname,
        'name', procedure_row.proname,
        'definition', pg_get_functiondef(procedure_row.oid)
      )
      order by procedure_row.oid
    ),
    '[]'::jsonb
  )
  into v_functions_after
  from pg_proc procedure_row
  join pg_namespace namespace
    on namespace.oid = procedure_row.pronamespace
  where namespace.nspname = 'public'
    and procedure_row.prokind in ('f', 'p')
    and procedure_row.proname not in (
      'get_active_performance_roles_v1',
      'get_my_performance_roles_v1',
      'replace_my_performance_roles_v1'
    );

  select coalesce(
    jsonb_agg(to_jsonb(policy_row) order by policy_row.tablename, policy_row.policyname),
    '[]'::jsonb
  )
  into v_policies_after
  from pg_policies policy_row
  where policy_row.schemaname = 'public'
    and policy_row.tablename not in (
      'performance_roles',
      'user_performance_roles'
    );

  if v_parts_after is distinct from v_snapshot.parts_rows
    or v_part_joins_after is distinct from v_snapshot.part_join_rows then
    raise exception 'Migration 033 changed legacy parts or part joins'
      using errcode = '55000';
  end if;

  if v_genres_after is distinct from v_snapshot.genre_rows
    or v_user_genres_after is distinct from v_snapshot.user_genre_rows then
    raise exception 'Migration 033 changed genres or user_genres'
      using errcode = '55000';
  end if;

  if v_user_taxonomy_after is distinct from v_snapshot.user_taxonomy_rows then
    raise exception
      'Migration 033 backfilled user domain or changed professional state'
      using errcode = '55000';
  end if;

  if v_views_after is distinct from v_snapshot.view_definitions
    or v_functions_after is distinct from v_snapshot.function_definitions
    or v_policies_after is distinct from v_snapshot.policy_definitions then
    raise exception
      'Migration 033 replaced an existing view, function, or policy'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from public.genres genre
    where genre.code in (
      'dance_kpop',
      'dance_hiphop',
      'dance_jazz',
      'dance_jazz_hiphop',
      'dance_girls_hiphop',
      'dance_waack',
      'dance_locking',
      'dance_popping',
      'dance_breaking',
      'dance_house',
      'dance_other'
    )
      and not genre.is_active
  ) <> 11 then
    raise exception 'Migration 033 activated or changed a dance genre'
      using errcode = '55000';
  end if;
end;
$postconditions$;

notify pgrst, 'reload schema';

commit;

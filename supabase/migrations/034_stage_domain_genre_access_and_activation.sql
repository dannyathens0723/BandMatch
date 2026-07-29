-- STAGE domain-specific genre access and the approved Dance activation.
--
-- The v1 RPC gives Web and future iOS clients a stable, explicit contract.
-- Only band and dance are valid genre domains; multi_domain remains a user
-- profile concept, not a genre-master domain.
--
-- Existing direct SELECT access intentionally remains available during the
-- compatibility window. Legacy BandMatch clients must keep filtering
-- domain = 'band' until every supported client has moved to the versioned RPC.
--
-- Activation is deliberately strict: already-active, partially active,
-- unexpected, drifted, or pre-assigned Dance rows abort the transaction.
-- Rollback must use a later forward migration that deactivates the same stable
-- rows; never delete or recreate their UUIDs or assignment history.
-- Run after 033_stage_performance_roles.sql.

begin;

set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- Fail before locks or mutation when the expected 032/033 catalog is missing,
-- incompatible, or already contains a same-named RPC.
do $preflight$
declare
  v_domain_constraint text;
  v_category_constraint text;
begin
  if to_regclass('public.genres') is null
    or to_regclass('public.user_genres') is null
    or to_regclass('public.group_genres') is null
    or to_regclass('public.recruitment_post_genres') is null then
    raise exception
      'Migration 034 requires genres and all three genre assignment tables'
      using errcode = '55000';
  end if;

  if to_regclass('public.performance_roles') is null
    or to_regclass('public.user_performance_roles') is null
    or to_regprocedure(
      'public.get_active_performance_roles_v1(text)'
    ) is null
    or to_regprocedure(
      'public.get_my_performance_roles_v1()'
    ) is null
    or to_regprocedure(
      'public.replace_my_performance_roles_v1(text,uuid[],uuid)'
    ) is null then
    raise exception 'Migration 034 requires the Migration 033 foundation'
      using errcode = '55000';
  end if;

  if to_regprocedure('public.set_updated_at()') is null then
    raise exception 'Migration 034 requires public.set_updated_at()'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from information_schema.columns column_row
    where column_row.table_schema = 'public'
      and column_row.table_name = 'genres'
      and (
        (
          column_row.column_name = 'id'
          and column_row.data_type = 'uuid'
          and column_row.is_nullable = 'NO'
        )
        or (
          column_row.column_name in (
            'code',
            'name',
            'domain',
            'category'
          )
          and column_row.data_type = 'text'
          and column_row.is_nullable = 'NO'
        )
        or (
          column_row.column_name = 'sort_order'
          and column_row.data_type = 'smallint'
          and column_row.is_nullable = 'NO'
        )
        or (
          column_row.column_name = 'is_active'
          and column_row.data_type = 'boolean'
          and column_row.is_nullable = 'NO'
        )
        or (
          column_row.column_name in ('created_at', 'updated_at')
          and column_row.data_type = 'timestamp with time zone'
          and column_row.is_nullable = 'NO'
        )
      )
  ) <> 9 or (
    select count(*)
    from information_schema.columns column_row
    where column_row.table_schema = 'public'
      and column_row.table_name = 'genres'
  ) <> 9 then
    raise exception 'public.genres columns are incompatible with Migration 032'
      using errcode = '55000';
  end if;

  if not exists (
    select 1
    from information_schema.columns column_row
    where column_row.table_schema = 'public'
      and column_row.table_name = 'genres'
      and column_row.column_name = 'domain'
      and column_row.column_default = '''band''::text'
  ) or not exists (
    select 1
    from information_schema.columns column_row
    where column_row.table_schema = 'public'
      and column_row.table_name = 'genres'
      and column_row.column_name = 'category'
      and column_row.column_default = '''legacy_music''::text'
  ) then
    raise exception 'Migration 032 genre defaults are incompatible'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.genres'::regclass
      and constraint_row.convalidated
      and (
        (
          constraint_row.conname = 'genres_pkey'
          and constraint_row.contype = 'p'
        )
        or (
          constraint_row.conname in (
            'genres_code_key',
            'genres_name_key',
            'genres_sort_order_key'
          )
          and constraint_row.contype = 'u'
        )
        or (
          constraint_row.conname in (
            'genres_domain_check',
            'genres_category_check'
          )
          and constraint_row.contype = 'c'
        )
      )
  ) <> 6 or (
    select count(*)
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.genres'::regclass
  ) <> 6 then
    raise exception 'public.genres constraints are incomplete or unexpected'
      using errcode = '55000';
  end if;

  select regexp_replace(
    pg_get_expr(constraint_row.conbin, constraint_row.conrelid),
    '[[:space:]]+',
    '',
    'g'
  )
  into v_domain_constraint
  from pg_constraint constraint_row
  where constraint_row.conrelid = 'public.genres'::regclass
    and constraint_row.conname = 'genres_domain_check';

  if v_domain_constraint not in (
    '(domain=ANY(ARRAY[''band''::text,''dance''::text]))',
    'domain=ANY(ARRAY[''band''::text,''dance''::text])'
  ) then
    raise exception 'genres_domain_check is incompatible'
      using errcode = '55000';
  end if;

  select regexp_replace(
    pg_get_expr(constraint_row.conbin, constraint_row.conrelid),
    '[[:space:]]+',
    '',
    'g'
  )
  into v_category_constraint
  from pg_constraint constraint_row
  where constraint_row.conrelid = 'public.genres'::regclass
    and constraint_row.conname = 'genres_category_check';

  if v_category_constraint not in (
    '(category=ANY(ARRAY[''legacy_music''::text,'
      || '''commercial''::text,''street''::text,'
      || '''jazz_contemporary''::text,''entertainment''::text,'
      || '''other''::text]))',
    'category=ANY(ARRAY[''legacy_music''::text,'
      || '''commercial''::text,''street''::text,'
      || '''jazz_contemporary''::text,''entertainment''::text,'
      || '''other''::text])'
  ) then
    raise exception 'genres_category_check is incompatible'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from pg_trigger trigger_row
    join pg_proc procedure_row
      on procedure_row.oid = trigger_row.tgfoid
    join pg_namespace namespace
      on namespace.oid = procedure_row.pronamespace
    where trigger_row.tgrelid = 'public.genres'::regclass
      and not trigger_row.tgisinternal
      and trigger_row.tgname = 'set_updated_at'
      and trigger_row.tgenabled = 'O'
      and trigger_row.tgtype = 19
      and namespace.nspname = 'public'
      and procedure_row.proname = 'set_updated_at'
  ) <> 1 or (
    select count(*)
    from pg_trigger trigger_row
    where trigger_row.tgrelid = 'public.genres'::regclass
      and not trigger_row.tgisinternal
  ) <> 1 then
    raise exception 'public.genres updated-at trigger is incompatible'
      using errcode = '55000';
  end if;

  if not (
    select relation.relrowsecurity
    from pg_class relation
    where relation.oid = 'public.genres'::regclass
  ) then
    raise exception 'public.genres RLS must remain enabled'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from pg_policies policy_row
    where policy_row.schemaname = 'public'
      and policy_row.tablename = 'genres'
  ) <> 2 or not exists (
    select 1
    from pg_policies policy_row
    where policy_row.schemaname = 'public'
      and policy_row.tablename = 'genres'
      and policy_row.policyname = 'genres_read_active'
      and policy_row.permissive = 'PERMISSIVE'
      and policy_row.cmd = 'SELECT'
      and cardinality(policy_row.roles) = 2
      and policy_row.roles @> array[
        'anon'::name,
        'authenticated'::name
      ]
      and regexp_replace(
        policy_row.qual,
        '[[:space:]()]',
        '',
        'g'
      ) = 'is_active'
      and policy_row.with_check is null
  ) or not exists (
    select 1
    from pg_policies policy_row
    where policy_row.schemaname = 'public'
      and policy_row.tablename = 'genres'
      and policy_row.policyname = 'master_data_admin_manage_genres'
      and policy_row.permissive = 'PERMISSIVE'
      and policy_row.cmd = 'ALL'
      and cardinality(policy_row.roles) = 1
      and policy_row.roles @> array['authenticated'::name]
      and regexp_replace(
        policy_row.qual,
        '[[:space:]()]',
        '',
        'g'
      ) = 'is_admin'
      and regexp_replace(
        policy_row.with_check,
        '[[:space:]()]',
        '',
        'g'
      ) = 'is_admin'
  ) then
    raise exception 'public.genres policies are incompatible'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from pg_roles role_row
    where role_row.rolname in ('anon', 'authenticated')
  ) <> 2 then
    raise exception 'Migration 034 requires anon and authenticated roles'
      using errcode = '55000';
  end if;

  if not has_table_privilege('anon', 'public.genres', 'SELECT')
    or not has_table_privilege(
      'authenticated',
      'public.genres',
      'SELECT'
    ) then
    raise exception
      'SECURITY INVOKER genre RPC requires existing anon/authenticated SELECT'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from pg_proc procedure_row
    join pg_namespace namespace
      on namespace.oid = procedure_row.pronamespace
    where namespace.nspname = 'public'
      and procedure_row.proname = 'get_active_genres_v1'
  ) then
    raise exception
      'get_active_genres_v1 already exists; review partial application'
      using errcode = '55000';
  end if;
end;
$preflight$;

-- Reads remain available. Genre master writes and assignment writes are held
-- only while the exact before/after state is proved.
lock table public.genres in share row exclusive mode;
lock table
  public.group_genres,
  public.recruitment_post_genres,
  public.user_genres
in share mode;

create temporary table migration_034_approved_genres (
  code text primary key,
  name text not null,
  domain text not null,
  category text not null,
  sort_order smallint not null unique
) on commit drop;

insert into pg_temp.migration_034_approved_genres (
  code,
  name,
  domain,
  category,
  sort_order
)
values
  ('dance_kpop', 'K-POP', 'dance', 'commercial', 101),
  ('dance_hiphop', 'HIPHOP', 'dance', 'street', 102),
  ('dance_jazz', 'JAZZ', 'dance', 'jazz_contemporary', 103),
  (
    'dance_jazz_hiphop',
    'JAZZ HIPHOP',
    'dance',
    'jazz_contemporary',
    104
  ),
  (
    'dance_girls_hiphop',
    'GIRLS HIPHOP',
    'dance',
    'commercial',
    105
  ),
  ('dance_waack', 'WAACK', 'dance', 'street', 106),
  ('dance_locking', 'LOCKING', 'dance', 'street', 107),
  ('dance_popping', 'POPPING', 'dance', 'street', 108),
  ('dance_breaking', 'BREAKING', 'dance', 'street', 109),
  ('dance_house', 'HOUSE', 'dance', 'street', 110),
  ('dance_other', 'その他（ダンス）', 'dance', 'other', 111);

create temporary table migration_034_expected_band_genres (
  code text primary key,
  name text not null,
  sort_order smallint not null unique
) on commit drop;

insert into pg_temp.migration_034_expected_band_genres (
  code,
  name,
  sort_order
)
values
  ('pops', 'ポップス', 1),
  ('rock', 'ロック', 2),
  (
    'hard_rock_heavy_metal',
    'ハードロック・ヘビーメタル',
    3
  ),
  ('punk_melocore', 'パンク・メロコア', 4),
  ('hardcore', 'ハードコア', 5),
  (
    'thrash_death_metal',
    'スラッシュメタル・デスメタル',
    6
  ),
  ('visual_kei', 'ビジュアル系', 7),
  ('funk_blues', 'ファンク・ブルース', 8),
  ('jazz_fusion', 'ジャズ・フュージョン', 9),
  ('country_folk', 'カントリー・フォーク', 10),
  ('ska_rockabilly', 'スカ・ロカビリー', 11),
  ('soul_rnb', 'ソウル・R&B', 12),
  ('gospel_a_cappella', 'ゴスペル・アカペラ', 13),
  ('bossa_nova_latin', 'ボサノバ・ラテン', 14),
  ('classical', 'クラシック', 15),
  ('hiphop_reggae', 'ヒップホップ・レゲエ', 16),
  ('house_techno', 'ハウス・テクノ', 17),
  ('anison_vocaloid', 'アニソン・ボカロ', 18);

create temporary table migration_034_snapshot (
  band_genres jsonb not null,
  dance_genres jsonb not null,
  user_genres jsonb not null,
  group_genres jsonb not null,
  recruitment_post_genres jsonb not null,
  view_definitions jsonb not null,
  function_definitions jsonb not null,
  policy_definitions jsonb not null,
  genre_relation_state jsonb not null,
  genre_trigger_definitions jsonb not null,
  genre_constraint_definitions jsonb not null
) on commit drop;

insert into pg_temp.migration_034_snapshot (
  band_genres,
  dance_genres,
  user_genres,
  group_genres,
  recruitment_post_genres,
  view_definitions,
  function_definitions,
  policy_definitions,
  genre_relation_state,
  genre_trigger_definitions,
  genre_constraint_definitions
)
select
  (
    select coalesce(
      jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.code),
      '[]'::jsonb
    )
    from (
      select
        genre.id,
        genre.code,
        genre.name,
        genre.domain,
        genre.category,
        genre.sort_order,
        genre.is_active,
        genre.created_at,
        genre.updated_at
      from public.genres genre
      where genre.domain = 'band'
    ) snapshot_row
  ),
  (
    select coalesce(
      jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.code),
      '[]'::jsonb
    )
    from (
      select
        genre.id,
        genre.code,
        genre.name,
        genre.domain,
        genre.category,
        genre.sort_order,
        genre.is_active,
        genre.created_at,
        genre.updated_at
      from public.genres genre
      join pg_temp.migration_034_approved_genres approved
        on approved.code = genre.code
    ) snapshot_row
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
      jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
      '[]'::jsonb
    )
    from public.group_genres snapshot_row
  ),
  (
    select coalesce(
      jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
      '[]'::jsonb
    )
    from public.recruitment_post_genres snapshot_row
  ),
  (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'oid', relation.oid,
          'schema', namespace.nspname,
          'name', relation.relname,
          'kind', relation.relkind,
          'definition', pg_get_viewdef(relation.oid, false)
        )
        order by relation.oid
      ),
      '[]'::jsonb
    )
    from pg_class relation
    join pg_namespace namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relkind in ('v', 'm')
  ),
  (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'oid', procedure_row.oid,
          'schema', namespace.nspname,
          'name', procedure_row.proname,
          'definition', pg_get_functiondef(procedure_row.oid),
          'owner', procedure_row.proowner,
          'acl', to_jsonb(procedure_row.proacl)
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
      and procedure_row.proname <> 'get_active_genres_v1'
  ),
  (
    select coalesce(
      jsonb_agg(
        to_jsonb(policy_row)
        order by policy_row.tablename, policy_row.policyname
      ),
      '[]'::jsonb
    )
    from pg_policies policy_row
    where policy_row.schemaname = 'public'
  ),
  (
    select jsonb_build_object(
      'relrowsecurity', relation.relrowsecurity,
      'relforcerowsecurity', relation.relforcerowsecurity,
      'owner', relation.relowner,
      'acl', to_jsonb(relation.relacl)
    )
    from pg_class relation
    where relation.oid = 'public.genres'::regclass
  ),
  (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'oid', trigger_row.oid,
          'name', trigger_row.tgname,
          'enabled', trigger_row.tgenabled,
          'definition', pg_get_triggerdef(trigger_row.oid, false)
        )
        order by trigger_row.oid
      ),
      '[]'::jsonb
    )
    from pg_trigger trigger_row
    where trigger_row.tgrelid = 'public.genres'::regclass
      and not trigger_row.tgisinternal
  ),
  (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'oid', constraint_row.oid,
          'name', constraint_row.conname,
          'type', constraint_row.contype,
          'validated', constraint_row.convalidated,
          'deferrable', constraint_row.condeferrable,
          'deferred', constraint_row.condeferred,
          'definition', pg_get_constraintdef(
            constraint_row.oid,
            false
          )
        )
        order by constraint_row.oid
      ),
      '[]'::jsonb
    )
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.genres'::regclass
  );

-- No repair path is allowed here. Exact repository-history rows, metadata,
-- inactive state, and zero assignments are the activation gate.
do $activation_preconditions$
begin
  if (
    select count(*)
    from pg_temp.migration_034_approved_genres
  ) <> 11 or (
    select count(*)
    from public.genres genre
    join pg_temp.migration_034_approved_genres approved
      on approved.code = genre.code
  ) <> 11 then
    raise exception 'Exactly 11 approved Dance genres must exist'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from pg_temp.migration_034_approved_genres approved
    left join public.genres genre on genre.code = approved.code
    where genre.id is null
      or genre.name is distinct from approved.name
      or genre.domain is distinct from approved.domain
      or genre.category is distinct from approved.category
      or genre.sort_order is distinct from approved.sort_order
      or genre.is_active is distinct from false
  ) then
    raise exception
      'Approved Dance genres are missing, drifted, or already active'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from public.genres genre
    join pg_temp.migration_034_approved_genres approved
      on approved.sort_order = genre.sort_order
    where genre.code <> approved.code
  ) then
    raise exception 'Approved Dance sort order belongs to another genre'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from public.genres genre
    where genre.domain = 'dance'
      and not exists (
        select 1
        from pg_temp.migration_034_approved_genres approved
        where approved.code = genre.code
      )
  ) or exists (
    select 1
    from public.genres genre
    where left(genre.code, 6) = 'dance_'
      and not exists (
        select 1
        from pg_temp.migration_034_approved_genres approved
        where approved.code = genre.code
      )
  ) then
    raise exception 'Unexpected Dance genre exists'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from public.genres genre
    where genre.domain = 'band'
  ) <> 18 or exists (
    select 1
    from pg_temp.migration_034_expected_band_genres expected
    left join public.genres genre on genre.code = expected.code
    where genre.id is null
      or genre.name is distinct from expected.name
      or genre.domain is distinct from 'band'
      or genre.category is distinct from 'legacy_music'
      or genre.sort_order is distinct from expected.sort_order
  ) or (
    select count(*)
    from public.genres
  ) <> 29 then
    raise exception 'Band genre state is incompatible with Migration 032'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from public.user_genres assignment
    join public.genres genre on genre.id = assignment.genre_id
    join pg_temp.migration_034_approved_genres approved
      on approved.code = genre.code
  ) or exists (
    select 1
    from public.group_genres assignment
    join public.genres genre on genre.id = assignment.genre_id
    join pg_temp.migration_034_approved_genres approved
      on approved.code = genre.code
  ) or exists (
    select 1
    from public.recruitment_post_genres assignment
    join public.genres genre on genre.id = assignment.genre_id
    join pg_temp.migration_034_approved_genres approved
      on approved.code = genre.code
  ) then
    raise exception
      'Approved Dance genres must have zero assignments before activation'
      using errcode = '55000';
  end if;
end;
$activation_preconditions$;

-- The version suffix protects deployed Web caches and future iOS clients from
-- incompatible in-place response changes.
create function public.get_active_genres_v1(
  p_domain text
)
returns table (
  id uuid,
  code text,
  name text,
  domain text,
  category text,
  sort_order smallint
)
language plpgsql
stable
security invoker
set search_path = public, pg_temp
as $$
begin
  if p_domain is null or p_domain not in ('band', 'dance') then
    raise exception 'unsupported genre domain'
      using errcode = '22023';
  end if;

  return query
  select
    genre.id,
    genre.code,
    genre.name,
    genre.domain,
    genre.category,
    genre.sort_order
  from public.genres genre
  where genre.is_active
    and genre.domain = p_domain
  order by genre.sort_order, genre.code;
end;
$$;

comment on function public.get_active_genres_v1(text) is
  'Returns the active safe genre projection for band or dance.';

revoke all on function public.get_active_genres_v1(text)
  from public, anon, authenticated;
grant execute on function public.get_active_genres_v1(text)
  to anon, authenticated;

-- Match both the exact code allowlist and every approved immutable metadata
-- field. The existing trigger owns updated_at.
do $activation$
declare
  v_affected_rows integer;
begin
  update public.genres genre
  set is_active = true
  from pg_temp.migration_034_approved_genres approved
  where genre.code = approved.code
    and genre.name = approved.name
    and genre.domain = approved.domain
    and genre.category = approved.category
    and genre.sort_order = approved.sort_order
    and genre.is_active is false;

  get diagnostics v_affected_rows = row_count;

  if v_affected_rows <> 11 then
    raise exception
      'Dance activation affected % rows instead of 11',
      v_affected_rows
      using errcode = '55000';
  end if;
end;
$activation$;

-- Prove the new RPC/ACL and Dance activation while requiring all legacy data,
-- assignments, views, functions, policies, grants, triggers, and constraints
-- to remain byte-for-byte equivalent as JSON values.
do $postconditions$
declare
  v_snapshot record;
  v_function_oid oid;
  v_function_config text[];
  v_function_owner oid;
  v_band_after jsonb;
  v_dance_after jsonb;
  v_dance_immutable_before jsonb;
  v_dance_immutable_after jsonb;
  v_user_genres_after jsonb;
  v_group_genres_after jsonb;
  v_recruitment_post_genres_after jsonb;
  v_views_after jsonb;
  v_functions_after jsonb;
  v_policies_after jsonb;
  v_genre_relation_after jsonb;
  v_genre_triggers_after jsonb;
  v_genre_constraints_after jsonb;
  v_band_rpc_rows jsonb;
  v_band_direct_rows jsonb;
  v_dance_rpc_rows jsonb;
  v_dance_direct_rows jsonb;
  v_band_rpc_order text[];
  v_band_expected_order text[];
  v_dance_rpc_order text[];
  v_dance_expected_order text[];
  v_invalid_domain text;
begin
  select *
  into v_snapshot
  from pg_temp.migration_034_snapshot;

  v_function_oid := to_regprocedure(
    'public.get_active_genres_v1(text)'
  );

  if v_function_oid is null or (
    select count(*)
    from pg_proc procedure_row
    join pg_namespace namespace
      on namespace.oid = procedure_row.pronamespace
    where namespace.nspname = 'public'
      and procedure_row.proname = 'get_active_genres_v1'
  ) <> 1 then
    raise exception 'Active genre RPC signature is missing or ambiguous'
      using errcode = '55000';
  end if;

  select
    procedure_row.proconfig,
    procedure_row.proowner
  into
    v_function_config,
    v_function_owner
  from pg_proc procedure_row
  where procedure_row.oid = v_function_oid;

  if (
    select procedure_row.prosecdef
    from pg_proc procedure_row
    where procedure_row.oid = v_function_oid
  ) or (
    select procedure_row.provolatile
    from pg_proc procedure_row
    where procedure_row.oid = v_function_oid
  ) <> 's'
    or (
      select language.lanname
      from pg_proc procedure_row
      join pg_language language on language.oid = procedure_row.prolang
      where procedure_row.oid = v_function_oid
    ) <> 'plpgsql'
    or not coalesce(
      v_function_config @> array['search_path=public, pg_temp'],
      false
    )
    or pg_get_function_result(v_function_oid) <>
      'TABLE(id uuid, code text, name text, domain text, category text, sort_order smallint)'
    or not has_function_privilege(
      'anon',
      v_function_oid,
      'EXECUTE'
    )
    or not has_function_privilege(
      'authenticated',
      v_function_oid,
      'EXECUTE'
    )
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
    )
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
        and acl_row.privilege_type = 'EXECUTE'
        and acl_row.grantee not in (
          v_function_owner,
          (
            select role_row.oid
            from pg_roles role_row
            where role_row.rolname = 'anon'
          ),
          (
            select role_row.oid
            from pg_roles role_row
            where role_row.rolname = 'authenticated'
          )
        )
    ) then
    raise exception 'Active genre RPC contract or grants are incompatible'
      using errcode = '55000';
  end if;

  foreach v_invalid_domain in array array[
    null::text,
    '',
    ' ',
    'multi_domain',
    'DANCE',
    'Dance',
    'unsupported'
  ]
  loop
    begin
      perform 1
      from public.get_active_genres_v1(v_invalid_domain);

      raise exception
        'Active genre RPC accepted unsupported domain: %',
        coalesce(v_invalid_domain, '<null>');
    exception
      when sqlstate '22023' then
        null;
    end;
  end loop;

  select coalesce(
    jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.code),
    '[]'::jsonb
  )
  into v_band_after
  from (
    select
      genre.id,
      genre.code,
      genre.name,
      genre.domain,
      genre.category,
      genre.sort_order,
      genre.is_active,
      genre.created_at,
      genre.updated_at
    from public.genres genre
    where genre.domain = 'band'
  ) snapshot_row;

  select coalesce(
    jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.code),
    '[]'::jsonb
  )
  into v_dance_after
  from (
    select
      genre.id,
      genre.code,
      genre.name,
      genre.domain,
      genre.category,
      genre.sort_order,
      genre.is_active,
      genre.created_at,
      genre.updated_at
    from public.genres genre
    join pg_temp.migration_034_approved_genres approved
      on approved.code = genre.code
  ) snapshot_row;

  select coalesce(
    jsonb_agg(
      element - 'is_active' - 'updated_at'
      order by element ->> 'code'
    ),
    '[]'::jsonb
  )
  into v_dance_immutable_before
  from jsonb_array_elements(v_snapshot.dance_genres) element;

  select coalesce(
    jsonb_agg(
      element - 'is_active' - 'updated_at'
      order by element ->> 'code'
    ),
    '[]'::jsonb
  )
  into v_dance_immutable_after
  from jsonb_array_elements(v_dance_after) element;

  if v_band_after is distinct from v_snapshot.band_genres then
    raise exception 'Migration 034 changed a Band genre'
      using errcode = '55000';
  end if;

  if v_dance_immutable_after is distinct from v_dance_immutable_before
    or jsonb_array_length(v_dance_after) <> 11
    or exists (
      select 1
      from pg_temp.migration_034_approved_genres approved
      left join public.genres genre on genre.code = approved.code
      where genre.id is null
        or genre.name is distinct from approved.name
        or genre.domain is distinct from approved.domain
        or genre.category is distinct from approved.category
        or genre.sort_order is distinct from approved.sort_order
        or genre.is_active is distinct from true
    ) then
    raise exception
      'Dance activation changed immutable metadata or is incomplete'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from public.genres genre
    where genre.domain = 'dance'
      and not exists (
        select 1
        from pg_temp.migration_034_approved_genres approved
        where approved.code = genre.code
      )
  ) or exists (
    select 1
    from public.genres genre
    where left(genre.code, 6) = 'dance_'
      and not exists (
        select 1
        from pg_temp.migration_034_approved_genres approved
        where approved.code = genre.code
      )
  ) then
    raise exception 'Unexpected Dance genre exists after activation'
      using errcode = '55000';
  end if;

  select coalesce(
    jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
    '[]'::jsonb
  )
  into v_user_genres_after
  from public.user_genres snapshot_row;

  select coalesce(
    jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
    '[]'::jsonb
  )
  into v_group_genres_after
  from public.group_genres snapshot_row;

  select coalesce(
    jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
    '[]'::jsonb
  )
  into v_recruitment_post_genres_after
  from public.recruitment_post_genres snapshot_row;

  if v_user_genres_after is distinct from v_snapshot.user_genres
    or v_group_genres_after is distinct from v_snapshot.group_genres
    or v_recruitment_post_genres_after is distinct from
      v_snapshot.recruitment_post_genres then
    raise exception 'Migration 034 changed a genre assignment table'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from public.user_genres assignment
    join public.genres genre on genre.id = assignment.genre_id
    join pg_temp.migration_034_approved_genres approved
      on approved.code = genre.code
  ) or exists (
    select 1
    from public.group_genres assignment
    join public.genres genre on genre.id = assignment.genre_id
    join pg_temp.migration_034_approved_genres approved
      on approved.code = genre.code
  ) or exists (
    select 1
    from public.recruitment_post_genres assignment
    join public.genres genre on genre.id = assignment.genre_id
    join pg_temp.migration_034_approved_genres approved
      on approved.code = genre.code
  ) then
    raise exception 'Dance assignments appeared during Migration 034'
      using errcode = '55000';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'oid', relation.oid,
        'schema', namespace.nspname,
        'name', relation.relname,
        'kind', relation.relkind,
        'definition', pg_get_viewdef(relation.oid, false)
      )
      order by relation.oid
    ),
    '[]'::jsonb
  )
  into v_views_after
  from pg_class relation
  join pg_namespace namespace
    on namespace.oid = relation.relnamespace
  where namespace.nspname = 'public'
    and relation.relkind in ('v', 'm');

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'oid', procedure_row.oid,
        'schema', namespace.nspname,
        'name', procedure_row.proname,
        'definition', pg_get_functiondef(procedure_row.oid),
        'owner', procedure_row.proowner,
        'acl', to_jsonb(procedure_row.proacl)
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
    and procedure_row.proname <> 'get_active_genres_v1';

  select coalesce(
    jsonb_agg(
      to_jsonb(policy_row)
      order by policy_row.tablename, policy_row.policyname
    ),
    '[]'::jsonb
  )
  into v_policies_after
  from pg_policies policy_row
  where policy_row.schemaname = 'public';

  select jsonb_build_object(
    'relrowsecurity', relation.relrowsecurity,
    'relforcerowsecurity', relation.relforcerowsecurity,
    'owner', relation.relowner,
    'acl', to_jsonb(relation.relacl)
  )
  into v_genre_relation_after
  from pg_class relation
  where relation.oid = 'public.genres'::regclass;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'oid', trigger_row.oid,
        'name', trigger_row.tgname,
        'enabled', trigger_row.tgenabled,
        'definition', pg_get_triggerdef(trigger_row.oid, false)
      )
      order by trigger_row.oid
    ),
    '[]'::jsonb
  )
  into v_genre_triggers_after
  from pg_trigger trigger_row
  where trigger_row.tgrelid = 'public.genres'::regclass
    and not trigger_row.tgisinternal;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'oid', constraint_row.oid,
        'name', constraint_row.conname,
        'type', constraint_row.contype,
        'validated', constraint_row.convalidated,
        'deferrable', constraint_row.condeferrable,
        'deferred', constraint_row.condeferred,
        'definition', pg_get_constraintdef(
          constraint_row.oid,
          false
        )
      )
      order by constraint_row.oid
    ),
    '[]'::jsonb
  )
  into v_genre_constraints_after
  from pg_constraint constraint_row
  where constraint_row.conrelid = 'public.genres'::regclass;

  if v_views_after is distinct from v_snapshot.view_definitions
    or v_functions_after is distinct from v_snapshot.function_definitions
    or v_policies_after is distinct from v_snapshot.policy_definitions
    or v_genre_relation_after is distinct from
      v_snapshot.genre_relation_state
    or v_genre_triggers_after is distinct from
      v_snapshot.genre_trigger_definitions
    or v_genre_constraints_after is distinct from
      v_snapshot.genre_constraint_definitions then
    raise exception
      'Migration 034 changed an existing contract, policy, grant, or trigger'
      using errcode = '55000';
  end if;

  select coalesce(
    jsonb_agg(to_jsonb(result_row) order by result_row.sort_order, result_row.code),
    '[]'::jsonb
  )
  into v_band_rpc_rows
  from public.get_active_genres_v1('band') result_row;

  select coalesce(
    jsonb_agg(to_jsonb(result_row) order by result_row.sort_order, result_row.code),
    '[]'::jsonb
  )
  into v_band_direct_rows
  from (
    select
      genre.id,
      genre.code,
      genre.name,
      genre.domain,
      genre.category,
      genre.sort_order
    from public.genres genre
    where genre.is_active
      and genre.domain = 'band'
  ) result_row;

  select coalesce(
    jsonb_agg(to_jsonb(result_row) order by result_row.sort_order, result_row.code),
    '[]'::jsonb
  )
  into v_dance_rpc_rows
  from public.get_active_genres_v1('dance') result_row;

  select coalesce(
    jsonb_agg(to_jsonb(result_row) order by result_row.sort_order, result_row.code),
    '[]'::jsonb
  )
  into v_dance_direct_rows
  from (
    select
      genre.id,
      genre.code,
      genre.name,
      genre.domain,
      genre.category,
      genre.sort_order
    from public.genres genre
    where genre.is_active
      and genre.domain = 'dance'
  ) result_row;

  if v_band_rpc_rows is distinct from v_band_direct_rows
    or v_dance_rpc_rows is distinct from v_dance_direct_rows
    or jsonb_array_length(v_dance_rpc_rows) <> 11 then
    raise exception 'Active genre RPC results are incompatible'
      using errcode = '55000';
  end if;

  select array_agg(
    result_row.code order by result_row.sort_order, result_row.code
  )
  into v_band_rpc_order
  from public.get_active_genres_v1('band') result_row;

  select array_agg(genre.code order by genre.sort_order, genre.code)
  into v_band_expected_order
  from public.genres genre
  where genre.is_active
    and genre.domain = 'band';

  select array_agg(
    result_row.code order by result_row.sort_order, result_row.code
  )
  into v_dance_rpc_order
  from public.get_active_genres_v1('dance') result_row;

  select array_agg(genre.code order by genre.sort_order, genre.code)
  into v_dance_expected_order
  from public.genres genre
  where genre.is_active
    and genre.domain = 'dance';

  if v_band_rpc_order is distinct from v_band_expected_order
    or v_dance_rpc_order is distinct from v_dance_expected_order then
    raise exception 'Active genre RPC ordering is incompatible'
      using errcode = '55000';
  end if;
end;
$postconditions$;

notify pgrst, 'reload schema';

commit;

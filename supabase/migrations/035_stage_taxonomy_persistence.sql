-- Atomic self-only persistence and reload for the STAGE Dance taxonomy.
--
-- This migration adds exactly two versioned RPCs. It does not add or alter
-- tables, columns, indexes, triggers, views, RLS policies, or direct-table
-- grants. Applying the migration does not mutate profile or assignment data;
-- data changes occur only when an authenticated user later calls the write RPC.
--
-- V1 accepts only the exact domain value "dance". Dance replacements preserve
-- all Band/future-domain assignments and every other user's rows. The existing
-- one-primary-role-per-user index remains authoritative, so a preserved primary
-- role from another domain makes a Dance save fail instead of being demoted.
-- Run after 034_stage_domain_genre_access_and_activation.sql.

begin;

set local lock_timeout = '10s';
set local statement_timeout = '120s';

-- Fail before locks or persistent changes if the repository-history schema,
-- security boundaries, approved master rows, or prior RPC contracts drifted.
do $preflight$
declare
  v_constraint_expression text;
  v_function_oid oid;
  v_function_owner oid;
  v_function_config text[];
  v_rpc record;
begin
  if (
    select count(*)
    from pg_roles role_row
    where role_row.rolname in ('anon', 'authenticated')
  ) <> 2 then
    raise exception 'Migration 035 requires anon and authenticated roles'
      using errcode = '55000';
  end if;

  if to_regclass('public.users') is null
    or to_regclass('public.genres') is null
    or to_regclass('public.user_genres') is null
    or to_regclass('public.performance_roles') is null
    or to_regclass('public.user_performance_roles') is null then
    raise exception 'Migration 035 requires all five taxonomy tables'
      using errcode = '55000';
  end if;

  if to_regprocedure('public.current_user_id()') is null
    or to_regprocedure('public.set_updated_at()') is null then
    raise exception 'Migration 035 requires the authentication/timestamp helpers'
      using errcode = '55000';
  end if;

  v_function_oid := to_regprocedure('public.current_user_id()');
  select procedure_row.proconfig
  into v_function_config
  from pg_proc procedure_row
  where procedure_row.oid = v_function_oid;

  if pg_get_function_result(v_function_oid) <> 'uuid' or (
    select language.lanname
    from pg_proc procedure_row
    join pg_language language on language.oid = procedure_row.prolang
    where procedure_row.oid = v_function_oid
  ) <> 'sql' or (
    select procedure_row.provolatile
    from pg_proc procedure_row
    where procedure_row.oid = v_function_oid
  ) <> 's' or not (
    select procedure_row.prosecdef
    from pg_proc procedure_row
    where procedure_row.oid = v_function_oid
  ) or not coalesce(
    v_function_config = array['search_path=public'],
    false
  ) then
    raise exception 'public.current_user_id() contract is incompatible'
      using errcode = '55000';
  end if;

  v_function_oid := to_regprocedure('public.set_updated_at()');
  if pg_get_function_result(v_function_oid) <> 'trigger' or (
    select language.lanname
    from pg_proc procedure_row
    join pg_language language on language.oid = procedure_row.prolang
    where procedure_row.oid = v_function_oid
  ) <> 'plpgsql' or (
    select procedure_row.provolatile
    from pg_proc procedure_row
    where procedure_row.oid = v_function_oid
  ) <> 'v' or (
    select procedure_row.prosecdef
    from pg_proc procedure_row
    where procedure_row.oid = v_function_oid
  ) then
    raise exception 'public.set_updated_at() contract is incompatible'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from pg_proc procedure_row
    join pg_namespace namespace
      on namespace.oid = procedure_row.pronamespace
    where namespace.nspname = 'public'
      and procedure_row.proname in (
        'get_my_stage_taxonomy_v1',
        'replace_my_stage_taxonomy_v1'
      )
  ) then
    raise exception
      'Migration 035 RPC name already exists; review partial application'
      using errcode = '55000';
  end if;

  -- Exact relevant user-profile columns from Migrations 001 and 032.
  if (
    select count(*)
    from information_schema.columns column_row
    where column_row.table_schema = 'public'
      and column_row.table_name = 'users'
      and (
        (
          column_row.column_name in ('id', 'auth_uid')
          and column_row.data_type = 'uuid'
          and column_row.is_nullable = 'NO'
        )
        or (
          column_row.column_name = 'account_status'
          and column_row.data_type = 'text'
          and column_row.is_nullable = 'NO'
          and column_row.column_default = '''active''::text'
        )
        or (
          column_row.column_name = 'performance_domain'
          and column_row.data_type = 'text'
          and column_row.is_nullable = 'YES'
          and column_row.column_default is null
        )
        or (
          column_row.column_name = 'professional_state'
          and column_row.data_type = 'text'
          and column_row.is_nullable = 'NO'
          and column_row.column_default = '''general''::text'
        )
        or (
          column_row.column_name in ('created_at', 'updated_at')
          and column_row.data_type = 'timestamp with time zone'
          and column_row.is_nullable = 'NO'
        )
      )
  ) <> 7 then
    raise exception 'public.users taxonomy columns are incompatible'
      using errcode = '55000';
  end if;

  if not exists (
    select 1
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.users'::regclass
      and constraint_row.conname = 'users_pkey'
      and constraint_row.contype = 'p'
      and constraint_row.convalidated
  ) or not exists (
    select 1
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.users'::regclass
      and constraint_row.conname = 'users_auth_uid_key'
      and constraint_row.contype = 'u'
      and constraint_row.convalidated
  ) or not exists (
    select 1
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.users'::regclass
      and constraint_row.conname = 'users_auth_uid_fkey'
      and constraint_row.contype = 'f'
      and constraint_row.confrelid = 'auth.users'::regclass
      and constraint_row.confdeltype = 'r'
      and constraint_row.convalidated
  ) or not exists (
    select 1
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.users'::regclass
      and constraint_row.conname = 'users_account_status_check'
      and constraint_row.contype = 'c'
      and constraint_row.convalidated
  ) or not exists (
    select 1
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.users'::regclass
      and constraint_row.conname = 'users_performance_domain_check'
      and constraint_row.contype = 'c'
      and constraint_row.convalidated
  ) or not exists (
    select 1
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.users'::regclass
      and constraint_row.conname = 'users_professional_state_check'
      and constraint_row.contype = 'c'
      and constraint_row.convalidated
  ) then
    raise exception 'public.users authentication/status constraints are incompatible'
      using errcode = '55000';
  end if;

  -- Exact master/assignment table column contracts.
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
          column_row.column_name in ('code', 'name', 'domain', 'category')
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
    raise exception 'public.genres columns are incompatible'
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
    raise exception 'public.genres defaults are incompatible'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from information_schema.columns column_row
    where column_row.table_schema = 'public'
      and column_row.table_name = 'user_genres'
      and (
        (
          column_row.column_name in ('id', 'user_id', 'genre_id')
          and column_row.data_type = 'uuid'
          and column_row.is_nullable = 'NO'
        )
        or (
          column_row.column_name in ('created_at', 'updated_at')
          and column_row.data_type = 'timestamp with time zone'
          and column_row.is_nullable = 'NO'
        )
      )
  ) <> 5 or (
    select count(*)
    from information_schema.columns column_row
    where column_row.table_schema = 'public'
      and column_row.table_name = 'user_genres'
  ) <> 5 then
    raise exception 'public.user_genres columns are incompatible'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from information_schema.columns column_row
    where column_row.table_schema = 'public'
      and column_row.table_name = 'performance_roles'
      and (
        (
          column_row.column_name = 'id'
          and column_row.data_type = 'uuid'
          and column_row.is_nullable = 'NO'
        )
        or (
          column_row.column_name in ('code', 'name', 'domain')
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
          and column_row.column_default = 'true'
        )
        or (
          column_row.column_name in ('created_at', 'updated_at')
          and column_row.data_type = 'timestamp with time zone'
          and column_row.is_nullable = 'NO'
        )
      )
  ) <> 8 or (
    select count(*)
    from information_schema.columns column_row
    where column_row.table_schema = 'public'
      and column_row.table_name = 'performance_roles'
  ) <> 8 then
    raise exception 'public.performance_roles columns are incompatible'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from information_schema.columns column_row
    where column_row.table_schema = 'public'
      and column_row.table_name = 'user_performance_roles'
      and (
        (
          column_row.column_name in (
            'id',
            'user_id',
            'performance_role_id'
          )
          and column_row.data_type = 'uuid'
          and column_row.is_nullable = 'NO'
        )
        or (
          column_row.column_name = 'is_primary'
          and column_row.data_type = 'boolean'
          and column_row.is_nullable = 'NO'
          and column_row.column_default = 'false'
        )
        or (
          column_row.column_name in ('created_at', 'updated_at')
          and column_row.data_type = 'timestamp with time zone'
          and column_row.is_nullable = 'NO'
        )
      )
  ) <> 6 or (
    select count(*)
    from information_schema.columns column_row
    where column_row.table_schema = 'public'
      and column_row.table_name = 'user_performance_roles'
  ) <> 6 then
    raise exception 'public.user_performance_roles columns are incompatible'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from (
      values
        ('users', 'id', 'gen_random_uuid()'),
        ('users', 'created_at', 'now()'),
        ('users', 'updated_at', 'now()'),
        ('genres', 'id', 'gen_random_uuid()'),
        ('genres', 'is_active', 'true'),
        ('genres', 'created_at', 'now()'),
        ('genres', 'updated_at', 'now()'),
        ('user_genres', 'id', 'gen_random_uuid()'),
        ('user_genres', 'created_at', 'now()'),
        ('user_genres', 'updated_at', 'now()'),
        ('performance_roles', 'id', 'gen_random_uuid()'),
        ('performance_roles', 'is_active', 'true'),
        ('performance_roles', 'created_at', 'now()'),
        ('performance_roles', 'updated_at', 'now()'),
        ('user_performance_roles', 'id', 'gen_random_uuid()'),
        ('user_performance_roles', 'is_primary', 'false'),
        ('user_performance_roles', 'created_at', 'now()'),
        ('user_performance_roles', 'updated_at', 'now()')
    ) expected(table_name, column_name, default_expression)
    left join information_schema.columns column_row
      on column_row.table_schema = 'public'
      and column_row.table_name = expected.table_name
      and column_row.column_name = expected.column_name
      and column_row.column_default = expected.default_expression
    where column_row.column_name is null
  ) then
    raise exception 'Migration 035 relevant column defaults are incompatible'
      using errcode = '55000';
  end if;

  -- Exact assignment PK/FK/unique contracts.
  if (
    select count(*)
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.user_genres'::regclass
      and constraint_row.convalidated
      and (
        (
          constraint_row.conname = 'user_genres_pkey'
          and constraint_row.contype = 'p'
        )
        or (
          constraint_row.conname in (
            'user_genres_user_id_fkey',
            'user_genres_genre_id_fkey'
          )
          and constraint_row.contype = 'f'
        )
        or (
          constraint_row.conname = 'user_genres_user_id_genre_id_key'
          and constraint_row.contype = 'u'
        )
      )
  ) <> 4 or (
    select count(*)
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.user_genres'::regclass
  ) <> 4 then
    raise exception 'public.user_genres constraints are incompatible'
      using errcode = '55000';
  end if;

  if not exists (
    select 1
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.user_genres'::regclass
      and constraint_row.conname = 'user_genres_user_id_fkey'
      and constraint_row.contype = 'f'
      and constraint_row.confrelid = 'public.users'::regclass
      and constraint_row.confdeltype = 'c'
      and constraint_row.conkey = array[
        (
          select attribute.attnum
          from pg_attribute attribute
          where attribute.attrelid = 'public.user_genres'::regclass
            and attribute.attname = 'user_id'
            and not attribute.attisdropped
        )::smallint
      ]
      and constraint_row.confkey = array[
        (
          select attribute.attnum
          from pg_attribute attribute
          where attribute.attrelid = 'public.users'::regclass
            and attribute.attname = 'id'
            and not attribute.attisdropped
        )::smallint
      ]
  ) or not exists (
    select 1
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.user_genres'::regclass
      and constraint_row.conname = 'user_genres_genre_id_fkey'
      and constraint_row.contype = 'f'
      and constraint_row.confrelid = 'public.genres'::regclass
      and constraint_row.confdeltype = 'r'
      and constraint_row.conkey = array[
        (
          select attribute.attnum
          from pg_attribute attribute
          where attribute.attrelid = 'public.user_genres'::regclass
            and attribute.attname = 'genre_id'
            and not attribute.attisdropped
        )::smallint
      ]
      and constraint_row.confkey = array[
        (
          select attribute.attnum
          from pg_attribute attribute
          where attribute.attrelid = 'public.genres'::regclass
            and attribute.attname = 'id'
            and not attribute.attisdropped
        )::smallint
      ]
  ) then
    raise exception 'public.user_genres foreign keys are incompatible'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.user_performance_roles'::regclass
      and constraint_row.convalidated
      and (
        (
          constraint_row.conname = 'user_performance_roles_pkey'
          and constraint_row.contype = 'p'
        )
        or (
          constraint_row.conname in (
            'user_performance_roles_user_id_fkey',
            'user_performance_roles_performance_role_id_fkey'
          )
          and constraint_row.contype = 'f'
        )
        or (
          constraint_row.conname = 'user_performance_roles_user_role_key'
          and constraint_row.contype = 'u'
        )
      )
  ) <> 4 or (
    select count(*)
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.user_performance_roles'::regclass
  ) <> 4 then
    raise exception 'public.user_performance_roles constraints are incompatible'
      using errcode = '55000';
  end if;

  if not exists (
    select 1
    from pg_constraint constraint_row
    where constraint_row.conrelid =
      'public.user_performance_roles'::regclass
      and constraint_row.conname =
        'user_performance_roles_user_id_fkey'
      and constraint_row.contype = 'f'
      and constraint_row.confrelid = 'public.users'::regclass
      and constraint_row.confdeltype = 'c'
      and constraint_row.conkey = array[
        (
          select attribute.attnum
          from pg_attribute attribute
          where attribute.attrelid =
            'public.user_performance_roles'::regclass
            and attribute.attname = 'user_id'
            and not attribute.attisdropped
        )::smallint
      ]
      and constraint_row.confkey = array[
        (
          select attribute.attnum
          from pg_attribute attribute
          where attribute.attrelid = 'public.users'::regclass
            and attribute.attname = 'id'
            and not attribute.attisdropped
        )::smallint
      ]
  ) or not exists (
    select 1
    from pg_constraint constraint_row
    where constraint_row.conrelid =
      'public.user_performance_roles'::regclass
      and constraint_row.conname =
        'user_performance_roles_performance_role_id_fkey'
      and constraint_row.contype = 'f'
      and constraint_row.confrelid = 'public.performance_roles'::regclass
      and constraint_row.confdeltype = 'r'
      and constraint_row.conkey = array[
        (
          select attribute.attnum
          from pg_attribute attribute
          where attribute.attrelid =
            'public.user_performance_roles'::regclass
            and attribute.attname = 'performance_role_id'
            and not attribute.attisdropped
        )::smallint
      ]
      and constraint_row.confkey = array[
        (
          select attribute.attnum
          from pg_attribute attribute
          where attribute.attrelid = 'public.performance_roles'::regclass
            and attribute.attname = 'id'
            and not attribute.attisdropped
        )::smallint
      ]
  ) then
    raise exception 'public.user_performance_roles foreign keys are incompatible'
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
    raise exception 'public.genres constraints are incompatible'
      using errcode = '55000';
  end if;

  select regexp_replace(
    pg_get_expr(constraint_row.conbin, constraint_row.conrelid),
    '[[:space:]]+',
    '',
    'g'
  )
  into v_constraint_expression
  from pg_constraint constraint_row
  where constraint_row.conrelid = 'public.genres'::regclass
    and constraint_row.conname = 'genres_domain_check';

  if v_constraint_expression not in (
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
  into v_constraint_expression
  from pg_constraint constraint_row
  where constraint_row.conrelid = 'public.users'::regclass
    and constraint_row.conname = 'users_performance_domain_check'
    and constraint_row.convalidated;

  if v_constraint_expression not in (
    '(performance_domain=ANY(ARRAY[''band''::text,''dance''::text,'
      || '''multi_domain''::text]))',
    'performance_domain=ANY(ARRAY[''band''::text,''dance''::text,'
      || '''multi_domain''::text])'
  ) then
    raise exception 'users_performance_domain_check is incompatible'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.performance_roles'::regclass
      and constraint_row.convalidated
      and (
        (
          constraint_row.conname = 'performance_roles_pkey'
          and constraint_row.contype = 'p'
        )
        or (
          constraint_row.conname in (
            'performance_roles_code_key',
            'performance_roles_domain_name_key',
            'performance_roles_domain_sort_order_key'
          )
          and constraint_row.contype = 'u'
        )
        or (
          constraint_row.conname in (
            'performance_roles_domain_check',
            'performance_roles_name_length_check'
          )
          and constraint_row.contype = 'c'
        )
      )
  ) <> 6 or (
    select count(*)
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.performance_roles'::regclass
  ) <> 6 then
    raise exception 'public.performance_roles constraints are incompatible'
      using errcode = '55000';
  end if;

  select regexp_replace(
    pg_get_expr(constraint_row.conbin, constraint_row.conrelid),
    '[[:space:]]+',
    '',
    'g'
  )
  into v_constraint_expression
  from pg_constraint constraint_row
  where constraint_row.conrelid = 'public.performance_roles'::regclass
    and constraint_row.conname = 'performance_roles_domain_check';

  if v_constraint_expression not in (
    '(domain=ANY(ARRAY[''band''::text,''dance''::text]))',
    'domain=ANY(ARRAY[''band''::text,''dance''::text])'
  ) then
    raise exception 'performance_roles_domain_check is incompatible'
      using errcode = '55000';
  end if;

  -- Required deterministic lookup/global-primary indexes.
  if to_regclass('public.user_genres_genre_idx') is null
    or to_regclass('public.user_performance_roles_role_user_idx') is null
    or to_regclass(
      'public.user_performance_roles_one_primary_per_user'
    ) is null then
    raise exception 'Migration 035 assignment indexes are missing'
      using errcode = '55000';
  end if;

  if not exists (
    select 1
    from pg_index index_row
    where index_row.indexrelid =
      'public.user_genres_genre_idx'::regclass
      and index_row.indrelid = 'public.user_genres'::regclass
      and not index_row.indisunique
      and index_row.indpred is null
      and pg_get_indexdef(index_row.indexrelid) like
        '% USING btree (genre_id, user_id)'
  ) or not exists (
    select 1
    from pg_index index_row
    where index_row.indexrelid =
      'public.user_performance_roles_role_user_idx'::regclass
      and index_row.indrelid = 'public.user_performance_roles'::regclass
      and not index_row.indisunique
      and index_row.indpred is null
      and pg_get_indexdef(index_row.indexrelid) like
        '% USING btree (performance_role_id, user_id)'
  ) or not exists (
    select 1
    from pg_index index_row
    where index_row.indexrelid =
      'public.user_performance_roles_one_primary_per_user'::regclass
      and index_row.indrelid = 'public.user_performance_roles'::regclass
      and index_row.indisunique
      and regexp_replace(
        pg_get_expr(index_row.indpred, index_row.indrelid),
        '[[:space:]()]',
        '',
        'g'
      ) = 'is_primary'
      and pg_get_indexdef(index_row.indexrelid) like
        '% USING btree (user_id) WHERE is_primary'
  ) then
    raise exception 'Migration 035 assignment index definitions are incompatible'
      using errcode = '55000';
  end if;

  -- All expected timestamp/protection triggers must remain the only external
  -- triggers on these five tables.
  if (
    select count(*)
    from pg_trigger trigger_row
    where trigger_row.tgrelid = 'public.users'::regclass
      and not trigger_row.tgisinternal
  ) <> 2 or not exists (
    select 1
    from pg_trigger trigger_row
    join pg_proc procedure_row on procedure_row.oid = trigger_row.tgfoid
    join pg_namespace namespace on namespace.oid = procedure_row.pronamespace
    where trigger_row.tgrelid = 'public.users'::regclass
      and not trigger_row.tgisinternal
      and trigger_row.tgname = 'set_updated_at'
      and trigger_row.tgenabled = 'O'
      and namespace.nspname = 'public'
      and procedure_row.proname = 'set_updated_at'
  ) or not exists (
    select 1
    from pg_trigger trigger_row
    join pg_proc procedure_row on procedure_row.oid = trigger_row.tgfoid
    join pg_namespace namespace on namespace.oid = procedure_row.pronamespace
    where trigger_row.tgrelid = 'public.users'::regclass
      and not trigger_row.tgisinternal
      and trigger_row.tgname = 'protect_user_system_fields'
      and trigger_row.tgenabled = 'O'
      and namespace.nspname = 'public'
      and procedure_row.proname = 'protect_user_system_fields'
  ) then
    raise exception 'public.users triggers are incompatible'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from (
      values
        ('genres'::text),
        ('user_genres'::text),
        ('performance_roles'::text),
        ('user_performance_roles'::text)
    ) expected(table_name)
    where (
      select count(*)
      from pg_trigger trigger_row
      where trigger_row.tgrelid =
        format('public.%I', expected.table_name)::regclass
        and not trigger_row.tgisinternal
    ) <> 1
      or not exists (
        select 1
        from pg_trigger trigger_row
        join pg_proc procedure_row on procedure_row.oid = trigger_row.tgfoid
        join pg_namespace namespace
          on namespace.oid = procedure_row.pronamespace
        where trigger_row.tgrelid =
          format('public.%I', expected.table_name)::regclass
          and not trigger_row.tgisinternal
          and trigger_row.tgname = 'set_updated_at'
          and trigger_row.tgenabled = 'O'
          and namespace.nspname = 'public'
          and procedure_row.proname = 'set_updated_at'
      )
  ) then
    raise exception 'taxonomy updated-at triggers are incompatible'
      using errcode = '55000';
  end if;

  -- RLS must be enabled, and the repository-history policy inventory must be
  -- exact. Predicate details important to ownership are checked separately.
  if exists (
    select 1
    from (
      values
        ('users'::text),
        ('genres'::text),
        ('user_genres'::text),
        ('performance_roles'::text),
        ('user_performance_roles'::text)
    ) expected(table_name)
    join pg_class relation
      on relation.oid = format('public.%I', expected.table_name)::regclass
    where not relation.relrowsecurity or relation.relforcerowsecurity
  ) then
    raise exception 'Migration 035 requires the expected non-forced RLS state'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from pg_policies policy_row
    where policy_row.schemaname = 'public'
      and policy_row.tablename in (
        'users',
        'genres',
        'user_genres',
        'performance_roles',
        'user_performance_roles'
      )
  ) <> 12 or exists (
    select 1
    from (
      values
        ('users', 'users_select_self', 'SELECT'),
        ('users', 'users_insert_self', 'INSERT'),
        ('users', 'users_update_self_unverified', 'UPDATE'),
        ('users', 'users_update_self_verified', 'UPDATE'),
        ('users', 'users_admin_manage', 'ALL'),
        ('genres', 'genres_read_active', 'SELECT'),
        ('genres', 'master_data_admin_manage_genres', 'ALL'),
        ('user_genres', 'user_genres_read', 'SELECT'),
        ('user_genres', 'user_genres_write', 'ALL'),
        ('performance_roles', 'performance_roles_read_active', 'SELECT'),
        ('performance_roles', 'performance_roles_admin_manage', 'ALL'),
        (
          'user_performance_roles',
          'user_performance_roles_read_self',
          'SELECT'
        )
    ) expected(table_name, policy_name, command_name)
    left join pg_policies policy_row
      on policy_row.schemaname = 'public'
      and policy_row.tablename = expected.table_name
      and policy_row.policyname = expected.policy_name
      and policy_row.cmd = expected.command_name
      and policy_row.permissive = 'PERMISSIVE'
      and cardinality(policy_row.roles) = case
        when expected.policy_name = 'genres_read_active' then 2
        else 1
      end
      and policy_row.roles @> case
        when expected.policy_name = 'genres_read_active'
          then array['anon'::name, 'authenticated'::name]
        else array['authenticated'::name]
      end
    where policy_row.policyname is null
  ) then
    raise exception 'Migration 035 RLS policy inventory is incompatible'
      using errcode = '55000';
  end if;

  if not exists (
    select 1
    from pg_policies policy_row
    where policy_row.schemaname = 'public'
      and policy_row.tablename = 'user_genres'
      and policy_row.policyname = 'user_genres_read'
      and position('current_user_id' in policy_row.qual) > 0
      and position('is_public_profile_visible' in policy_row.qual) > 0
  ) or not exists (
    select 1
    from pg_policies policy_row
    where policy_row.schemaname = 'public'
      and policy_row.tablename = 'user_genres'
      and policy_row.policyname = 'user_genres_write'
      and position('current_user_id' in policy_row.qual) > 0
      and position('current_user_id' in policy_row.with_check) > 0
  ) or not exists (
    select 1
    from pg_policies policy_row
    where policy_row.schemaname = 'public'
      and policy_row.tablename = 'user_performance_roles'
      and policy_row.policyname = 'user_performance_roles_read_self'
      and position('current_user_id' in policy_row.qual) > 0
  ) then
    raise exception 'Migration 035 self-ownership policy predicates drifted'
      using errcode = '55000';
  end if;

  if not has_table_privilege('anon', 'public.genres', 'SELECT')
    or not has_table_privilege(
      'authenticated',
      'public.genres',
      'SELECT'
    )
    or not has_table_privilege(
      'authenticated',
      'public.performance_roles',
      'SELECT'
    )
    or not has_table_privilege(
      'authenticated',
      'public.user_performance_roles',
      'SELECT'
    ) then
    raise exception 'Migration 035 required table SELECT privileges are missing'
      using errcode = '55000';
  end if;

  if has_table_privilege('anon', 'public.performance_roles', 'SELECT')
    or has_table_privilege(
      'anon',
      'public.user_performance_roles',
      'SELECT'
    )
    or has_table_privilege(
      'authenticated',
      'public.performance_roles',
      'INSERT'
    )
    or has_table_privilege(
      'authenticated',
      'public.performance_roles',
      'UPDATE'
    )
    or has_table_privilege(
      'authenticated',
      'public.performance_roles',
      'DELETE'
    )
    or has_table_privilege(
      'authenticated',
      'public.user_performance_roles',
      'INSERT'
    )
    or has_table_privilege(
      'authenticated',
      'public.user_performance_roles',
      'UPDATE'
    )
    or has_table_privilege(
      'authenticated',
      'public.user_performance_roles',
      'DELETE'
    ) then
    raise exception 'Migration 035 role-table privilege boundary drifted'
      using errcode = '55000';
  end if;

  -- Exact prior RPC signatures, return contracts, language, volatility,
  -- security mode, fixed search path, and application-role ACLs.
  for v_rpc in
    select *
    from (
      values
        (
          'public.get_active_genres_v1(text)'::text,
          'get_active_genres_v1'::text,
          'TABLE(id uuid, code text, name text, domain text, category text, sort_order smallint)'::text,
          's'::"char",
          false,
          true
        ),
        (
          'public.get_active_performance_roles_v1(text)'::text,
          'get_active_performance_roles_v1'::text,
          'TABLE(id uuid, code text, name text, domain text, sort_order smallint)'::text,
          's'::"char",
          false,
          false
        ),
        (
          'public.get_my_performance_roles_v1()'::text,
          'get_my_performance_roles_v1'::text,
          'TABLE(id uuid, code text, name text, domain text, sort_order smallint, is_primary boolean, is_active boolean)'::text,
          's'::"char",
          true,
          false
        ),
        (
          'public.replace_my_performance_roles_v1(text,uuid[],uuid)'::text,
          'replace_my_performance_roles_v1'::text,
          'TABLE(id uuid, code text, name text, domain text, sort_order smallint, is_primary boolean, is_active boolean)'::text,
          'v'::"char",
          true,
          false
        )
    ) expected(
      signature,
      function_name,
      result_contract,
      volatility_code,
      security_definer,
      anon_execute
    )
  loop
    v_function_oid := to_regprocedure(v_rpc.signature);

    if v_function_oid is null or (
      select count(*)
      from pg_proc procedure_row
      join pg_namespace namespace
        on namespace.oid = procedure_row.pronamespace
      where namespace.nspname = 'public'
        and procedure_row.proname = v_rpc.function_name
    ) <> 1 then
      raise exception 'Required prior RPC is missing or ambiguous: %',
        v_rpc.signature
        using errcode = '55000';
    end if;

    select procedure_row.proowner, procedure_row.proconfig
    into v_function_owner, v_function_config
    from pg_proc procedure_row
    where procedure_row.oid = v_function_oid;

    if (
      select language.lanname
      from pg_proc procedure_row
      join pg_language language on language.oid = procedure_row.prolang
      where procedure_row.oid = v_function_oid
    ) <> 'plpgsql' or (
      select procedure_row.provolatile
      from pg_proc procedure_row
      where procedure_row.oid = v_function_oid
    ) <> v_rpc.volatility_code or (
      select procedure_row.prosecdef
      from pg_proc procedure_row
      where procedure_row.oid = v_function_oid
    ) is distinct from v_rpc.security_definer or not coalesce(
      v_function_config = array['search_path=public, pg_temp'],
      false
    ) or pg_get_function_result(v_function_oid) <>
      v_rpc.result_contract then
      raise exception 'Prior RPC contract drifted: %', v_rpc.signature
        using errcode = '55000';
    end if;

    if not has_function_privilege(
      'authenticated',
      v_function_oid,
      'EXECUTE'
    ) or has_function_privilege(
      'anon',
      v_function_oid,
      'EXECUTE'
    ) is distinct from v_rpc.anon_execute then
      raise exception 'Prior RPC application grants drifted: %', v_rpc.signature
        using errcode = '55000';
    end if;

    if exists (
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
      raise exception 'Prior RPC grants PUBLIC EXECUTE: %', v_rpc.signature
        using errcode = '55000';
    end if;

    if exists (
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
        and acl_row.grantee <> 0
        and acl_row.grantee <> v_function_owner
        and not exists (
          select 1
          from pg_roles grantee_role
          where grantee_role.oid = acl_row.grantee
            and (
              grantee_role.rolname = 'authenticated'
              or (
                v_rpc.anon_execute
                and grantee_role.rolname = 'anon'
              )
              or grantee_role.rolname = 'service_role'
            )
        )
    ) then
      raise exception 'Prior RPC has unexpected EXECUTE grantee: %',
        v_rpc.signature
        using errcode = '55000';
    end if;
  end loop;

  -- The exact active Dance master rows are the only selectable V1 values.
  if (
    select count(*)
    from public.genres genre
    where genre.domain = 'dance'
  ) <> 11 or exists (
    with expected(code, name, domain, category, sort_order) as (
      values
        ('dance_kpop', 'K-POP', 'dance', 'commercial', 101::smallint),
        ('dance_hiphop', 'HIPHOP', 'dance', 'street', 102::smallint),
        (
          'dance_jazz',
          'JAZZ',
          'dance',
          'jazz_contemporary',
          103::smallint
        ),
        (
          'dance_jazz_hiphop',
          'JAZZ HIPHOP',
          'dance',
          'jazz_contemporary',
          104::smallint
        ),
        (
          'dance_girls_hiphop',
          'GIRLS HIPHOP',
          'dance',
          'commercial',
          105::smallint
        ),
        ('dance_waack', 'WAACK', 'dance', 'street', 106::smallint),
        ('dance_locking', 'LOCKING', 'dance', 'street', 107::smallint),
        ('dance_popping', 'POPPING', 'dance', 'street', 108::smallint),
        ('dance_breaking', 'BREAKING', 'dance', 'street', 109::smallint),
        ('dance_house', 'HOUSE', 'dance', 'street', 110::smallint),
        ('dance_other', 'その他（ダンス）', 'dance', 'other', 111::smallint)
    )
    select 1
    from expected
    left join public.genres genre on genre.code = expected.code
    where genre.id is null
      or genre.name is distinct from expected.name
      or genre.domain is distinct from expected.domain
      or genre.category is distinct from expected.category
      or genre.sort_order is distinct from expected.sort_order
      or genre.is_active is distinct from true
  ) then
    raise exception 'Approved active Dance genre master is incompatible'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from public.performance_roles
  ) <> 4 or exists (
    with expected(code, name, domain, sort_order) as (
      values
        ('dance_dancer', 'ダンサー', 'dance', 101::smallint),
        ('dance_choreographer', '振付師', 'dance', 102::smallint),
        ('dance_instructor', 'インストラクター', 'dance', 103::smallint),
        ('dance_other', 'その他', 'dance', 199::smallint)
    )
    select 1
    from expected
    left join public.performance_roles role on role.code = expected.code
    where role.id is null
      or role.name is distinct from expected.name
      or role.domain is distinct from expected.domain
      or role.sort_order is distinct from expected.sort_order
      or role.is_active is distinct from true
  ) then
    raise exception 'Approved active Dance performance-role master is incompatible'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from public.user_genres assignment
    left join public.users profile on profile.id = assignment.user_id
    left join public.genres genre on genre.id = assignment.genre_id
    where profile.id is null or genre.id is null
  ) or exists (
    select 1
    from public.user_performance_roles assignment
    left join public.users profile on profile.id = assignment.user_id
    left join public.performance_roles role
      on role.id = assignment.performance_role_id
    where profile.id is null or role.id is null
  ) or exists (
    select 1
    from public.user_genres assignment
    group by assignment.user_id, assignment.genre_id
    having count(*) > 1
  ) or exists (
    select 1
    from public.user_performance_roles assignment
    group by assignment.user_id, assignment.performance_role_id
    having count(*) > 1
  ) or exists (
    select 1
    from public.user_performance_roles assignment
    where assignment.is_primary
    group by assignment.user_id
    having count(*) > 1
  ) then
    raise exception 'Existing taxonomy assignments violate required integrity'
      using errcode = '55000';
  end if;
end;
$preflight$;

-- Keep all relevant rows and their catalogs stable while before/after snapshots
-- are compared. SHARE permits reads but blocks concurrent row mutation.
lock table
  public.genres,
  public.performance_roles,
  public.user_genres,
  public.user_performance_roles,
  public.users
in share mode;

create temporary table migration_035_snapshot (
  users_data jsonb not null,
  genres_data jsonb not null,
  user_genres_data jsonb not null,
  performance_roles_data jsonb not null,
  user_performance_roles_data jsonb not null,
  public_relations jsonb not null,
  view_definitions jsonb not null,
  function_definitions jsonb not null,
  policy_definitions jsonb not null,
  column_definitions jsonb not null,
  constraint_definitions jsonb not null,
  index_definitions jsonb not null,
  trigger_definitions jsonb not null
) on commit drop;

insert into pg_temp.migration_035_snapshot (
  users_data,
  genres_data,
  user_genres_data,
  performance_roles_data,
  user_performance_roles_data,
  public_relations,
  view_definitions,
  function_definitions,
  policy_definitions,
  column_definitions,
  constraint_definitions,
  index_definitions,
  trigger_definitions
)
select
  (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', profile.id,
          'performance_domain', profile.performance_domain,
          'updated_at', profile.updated_at
        )
        order by profile.id
      ),
      '[]'::jsonb
    )
    from public.users profile
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
      jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
      '[]'::jsonb
    )
    from public.performance_roles snapshot_row
  ),
  (
    select coalesce(
      jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
      '[]'::jsonb
    )
    from public.user_performance_roles snapshot_row
  ),
  (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'oid', relation.oid,
          'schema', namespace.nspname,
          'name', relation.relname,
          'kind', relation.relkind,
          'owner', relation.relowner,
          'acl', to_jsonb(relation.relacl),
          'rls', relation.relrowsecurity,
          'force_rls', relation.relforcerowsecurity
        )
        order by relation.oid
      ),
      '[]'::jsonb
    )
    from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
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
    join pg_namespace namespace on namespace.oid = relation.relnamespace
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
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'relation_oid', attribute.attrelid,
          'number', attribute.attnum,
          'name', attribute.attname,
          'type', format_type(attribute.atttypid, attribute.atttypmod),
          'not_null', attribute.attnotnull,
          'default', pg_get_expr(default_row.adbin, default_row.adrelid),
          'generated', attribute.attgenerated,
          'identity', attribute.attidentity
        )
        order by attribute.attrelid, attribute.attnum
      ),
      '[]'::jsonb
    )
    from pg_attribute attribute
    left join pg_attrdef default_row
      on default_row.adrelid = attribute.attrelid
      and default_row.adnum = attribute.attnum
    where attribute.attrelid in (
      'public.users'::regclass,
      'public.genres'::regclass,
      'public.user_genres'::regclass,
      'public.performance_roles'::regclass,
      'public.user_performance_roles'::regclass
    )
      and attribute.attnum > 0
      and not attribute.attisdropped
  ),
  (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'oid', constraint_row.oid,
          'relation_oid', constraint_row.conrelid,
          'name', constraint_row.conname,
          'type', constraint_row.contype,
          'validated', constraint_row.convalidated,
          'deferrable', constraint_row.condeferrable,
          'deferred', constraint_row.condeferred,
          'definition', pg_get_constraintdef(constraint_row.oid, false)
        )
        order by constraint_row.oid
      ),
      '[]'::jsonb
    )
    from pg_constraint constraint_row
    where constraint_row.conrelid in (
      'public.users'::regclass,
      'public.genres'::regclass,
      'public.user_genres'::regclass,
      'public.performance_roles'::regclass,
      'public.user_performance_roles'::regclass
    )
  ),
  (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'oid', index_row.indexrelid,
          'relation_oid', index_row.indrelid,
          'definition', pg_get_indexdef(index_row.indexrelid)
        )
        order by index_row.indexrelid
      ),
      '[]'::jsonb
    )
    from pg_index index_row
    where index_row.indrelid in (
      'public.users'::regclass,
      'public.genres'::regclass,
      'public.user_genres'::regclass,
      'public.performance_roles'::regclass,
      'public.user_performance_roles'::regclass
    )
  ),
  (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'oid', trigger_row.oid,
          'relation_oid', trigger_row.tgrelid,
          'name', trigger_row.tgname,
          'enabled', trigger_row.tgenabled,
          'definition', pg_get_triggerdef(trigger_row.oid, false)
        )
        order by trigger_row.oid
      ),
      '[]'::jsonb
    )
    from pg_trigger trigger_row
    where trigger_row.tgrelid in (
      'public.users'::regclass,
      'public.genres'::regclass,
      'public.user_genres'::regclass,
      'public.performance_roles'::regclass,
      'public.user_performance_roles'::regclass
    )
      and not trigger_row.tgisinternal
  );

-- Self-only aggregate reload. Assigned IDs are retained in the response even
-- when a master row is later inactive. A partial/inconsistent stored state is
-- surfaced explicitly instead of being repaired or reinterpreted as unsaved.
create function public.get_my_stage_taxonomy_v1(
  p_performance_domain text
)
returns table (
  domain text,
  has_saved_taxonomy boolean,
  genre_ids uuid[],
  role_ids uuid[],
  primary_role_id uuid
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_auth_uid uuid := auth.uid();
  v_user_id uuid;
  v_genre_ids uuid[];
  v_role_ids uuid[];
  v_primary_role_ids uuid[];
  v_primary_role_id uuid;
begin
  if v_auth_uid is null then
    raise exception 'sign in is required'
      using errcode = '28000';
  end if;

  if p_performance_domain is distinct from 'dance' then
    raise exception 'STAGE taxonomy v1 supports dance only'
      using errcode = '22023';
  end if;

  select profile.id
  into v_user_id
  from public.users profile
  where profile.auth_uid = v_auth_uid;

  if not found then
    raise exception 'profile mapping is required'
      using errcode = '55000';
  end if;

  select coalesce(
    array_agg(genre.id order by genre.sort_order, genre.code),
    '{}'::uuid[]
  )
  into v_genre_ids
  from public.user_genres assignment
  join public.genres genre on genre.id = assignment.genre_id
  where assignment.user_id = v_user_id
    and genre.domain = 'dance';

  select
    coalesce(
      array_agg(role.id order by role.sort_order, role.code),
      '{}'::uuid[]
    ),
    coalesce(
      array_agg(role.id order by role.sort_order, role.code)
        filter (where assignment.is_primary),
      '{}'::uuid[]
    )
  into v_role_ids, v_primary_role_ids
  from public.user_performance_roles assignment
  join public.performance_roles role
    on role.id = assignment.performance_role_id
  where assignment.user_id = v_user_id
    and role.domain = 'dance';

  if cardinality(v_genre_ids) = 0 and cardinality(v_role_ids) = 0 then
    return query
    select
      'dance'::text,
      false,
      '{}'::uuid[],
      '{}'::uuid[],
      null::uuid;
    return;
  end if;

  if cardinality(v_genre_ids) = 0
    or cardinality(v_role_ids) = 0
    or cardinality(v_primary_role_ids) <> 1 then
    raise exception 'stored STAGE taxonomy state is inconsistent'
      using errcode = '55000';
  end if;

  v_primary_role_id := v_primary_role_ids[1];

  if not (v_primary_role_id = any(v_role_ids)) then
    raise exception 'stored STAGE taxonomy state is inconsistent'
      using errcode = '55000';
  end if;

  return query
  select
    'dance'::text,
    true,
    v_genre_ids,
    v_role_ids,
    v_primary_role_id;
end;
$$;

comment on function public.get_my_stage_taxonomy_v1(text) is
  'Authenticated self-only Dance taxonomy aggregate read; returns no private profile fields and fails on partial stored state.';

-- Atomic self-only Dance replacement. All validation and locks complete before
-- mutation. Identical normalized selections skip assignment replacement, and
-- the user marker updates only when its approved transition changes the value.
create function public.replace_my_stage_taxonomy_v1(
  p_performance_domain text,
  p_genre_ids uuid[],
  p_role_ids uuid[],
  p_primary_role_id uuid
)
returns table (
  domain text,
  has_saved_taxonomy boolean,
  genre_ids uuid[],
  role_ids uuid[],
  primary_role_id uuid
)
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  v_auth_uid uuid := auth.uid();
  v_user_id uuid;
  v_account_status text;
  v_current_performance_domain text;
  v_effective_performance_domain text;
  v_requested_count integer;
  v_distinct_count integer;
  v_matching_count integer;
  v_requested_genre_ids uuid[];
  v_requested_role_ids uuid[];
  v_current_genre_ids uuid[];
  v_current_role_ids uuid[];
  v_current_primary_role_ids uuid[];
  v_current_primary_role_id uuid;
  v_saved_genre_ids uuid[];
  v_saved_role_ids uuid[];
  v_saved_primary_role_ids uuid[];
  v_saved_primary_role_id uuid;
  v_saved_performance_domain text;
begin
  if v_auth_uid is null then
    raise exception 'sign in is required'
      using errcode = '28000';
  end if;

  -- This exact row is the per-user serialization point for Web and future iOS
  -- saves. No caller-provided profile identifier is accepted.
  select
    profile.id,
    profile.account_status,
    profile.performance_domain
  into
    v_user_id,
    v_account_status,
    v_current_performance_domain
  from public.users profile
  where profile.auth_uid = v_auth_uid
  for update;

  if not found or v_account_status <> 'active' then
    raise exception 'active profile is required'
      using errcode = '55000';
  end if;

  if p_performance_domain is distinct from 'dance' then
    raise exception 'STAGE taxonomy v1 supports dance only'
      using errcode = '22023';
  end if;

  if p_genre_ids is null then
    raise exception 'genre IDs are required'
      using errcode = '22004';
  end if;

  if cardinality(p_genre_ids) = 0 then
    raise exception 'at least one Dance genre is required'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from unnest(p_genre_ids) selected(genre_id)
    where selected.genre_id is null
  ) then
    raise exception 'genre IDs cannot contain null'
      using errcode = '22023';
  end if;

  select
    count(*)::integer,
    count(distinct selected.genre_id)::integer
  into v_requested_count, v_distinct_count
  from unnest(p_genre_ids) selected(genre_id);

  if v_requested_count <> v_distinct_count then
    raise exception 'duplicate genre ID'
      using errcode = '22023';
  end if;

  if p_role_ids is null then
    raise exception 'performance-role IDs are required'
      using errcode = '22004';
  end if;

  if cardinality(p_role_ids) = 0 then
    raise exception 'at least one Dance performance role is required'
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
  into v_requested_count, v_distinct_count
  from unnest(p_role_ids) selected(role_id);

  if v_requested_count <> v_distinct_count then
    raise exception 'duplicate performance-role ID'
      using errcode = '22023';
  end if;

  if p_primary_role_id is null then
    raise exception 'primary role is required'
      using errcode = '22004';
  end if;

  if (
    select count(*)
    from unnest(p_role_ids) selected(role_id)
    where selected.role_id = p_primary_role_id
  ) <> 1 then
    raise exception 'primary role must occur exactly once in selected roles'
      using errcode = '22023';
  end if;

  -- Master locks use a fixed table order and UUID order. Validation below uses
  -- exact counts, so missing, inactive, and wrong-domain IDs are never filtered.
  perform genre.id
  from public.genres genre
  where genre.id = any(p_genre_ids)
  order by genre.id
  for share;

  select count(*)::integer
  into v_matching_count
  from public.genres genre
  where genre.id = any(p_genre_ids)
    and genre.domain = 'dance'
    and genre.is_active;

  if v_matching_count <> cardinality(p_genre_ids) then
    raise exception 'requested genre is missing, inactive, or not Dance'
      using errcode = '22023';
  end if;

  select array_agg(genre.id order by genre.sort_order, genre.code)
  into v_requested_genre_ids
  from public.genres genre
  where genre.id = any(p_genre_ids)
    and genre.domain = 'dance'
    and genre.is_active;

  perform role.id
  from public.performance_roles role
  where role.id = any(p_role_ids)
  order by role.id
  for share;

  select count(*)::integer
  into v_matching_count
  from public.performance_roles role
  where role.id = any(p_role_ids)
    and role.domain = 'dance'
    and role.is_active;

  if v_matching_count <> cardinality(p_role_ids) then
    raise exception 'requested performance role is missing, inactive, or not Dance'
      using errcode = '22023';
  end if;

  select array_agg(role.id order by role.sort_order, role.code)
  into v_requested_role_ids
  from public.performance_roles role
  where role.id = any(p_role_ids)
    and role.domain = 'dance'
    and role.is_active;

  if exists (
    select 1
    from public.user_performance_roles assignment
    join public.performance_roles role
      on role.id = assignment.performance_role_id
    where assignment.user_id = v_user_id
      and assignment.is_primary
      and role.domain <> 'dance'
  ) then
    raise exception 'stored non-Dance primary role is incompatible with Dance save'
      using errcode = '55000';
  end if;

  select coalesce(
    array_agg(genre.id order by genre.sort_order, genre.code),
    '{}'::uuid[]
  )
  into v_current_genre_ids
  from public.user_genres assignment
  join public.genres genre on genre.id = assignment.genre_id
  where assignment.user_id = v_user_id
    and genre.domain = 'dance';

  select
    coalesce(
      array_agg(role.id order by role.sort_order, role.code),
      '{}'::uuid[]
    ),
    coalesce(
      array_agg(role.id order by role.sort_order, role.code)
        filter (where assignment.is_primary),
      '{}'::uuid[]
    )
  into v_current_role_ids, v_current_primary_role_ids
  from public.user_performance_roles assignment
  join public.performance_roles role
    on role.id = assignment.performance_role_id
  where assignment.user_id = v_user_id
    and role.domain = 'dance';

  if cardinality(v_current_genre_ids) = 0
    and cardinality(v_current_role_ids) = 0
    and cardinality(v_current_primary_role_ids) = 0 then
    v_current_primary_role_id := null;
  elsif cardinality(v_current_genre_ids) > 0
    and cardinality(v_current_role_ids) > 0
    and cardinality(v_current_primary_role_ids) = 1 then
    v_current_primary_role_id := v_current_primary_role_ids[1];
  else
    raise exception 'stored STAGE taxonomy state is inconsistent'
      using errcode = '55000';
  end if;

  v_effective_performance_domain := case
    when v_current_performance_domain is null then 'dance'
    when v_current_performance_domain = 'dance' then 'dance'
    when v_current_performance_domain = 'band' then 'multi_domain'
    when v_current_performance_domain = 'multi_domain' then 'multi_domain'
    else null
  end;

  if v_effective_performance_domain is null then
    raise exception 'stored performance domain is incompatible'
      using errcode = '55000';
  end if;

  update public.users profile
  set performance_domain = v_effective_performance_domain
  where profile.id = v_user_id
    and profile.performance_domain is distinct from
      v_effective_performance_domain;

  if v_current_genre_ids is distinct from v_requested_genre_ids then
    delete from public.user_genres assignment
    using public.genres genre
    where assignment.user_id = v_user_id
      and genre.id = assignment.genre_id
      and genre.domain = 'dance';

    insert into public.user_genres (user_id, genre_id)
    select v_user_id, selected.genre_id
    from unnest(v_requested_genre_ids) with ordinality
      as selected(genre_id, ordinal)
    order by selected.ordinal;
  end if;

  if v_current_role_ids is distinct from v_requested_role_ids
    or v_current_primary_role_id is distinct from p_primary_role_id then
    delete from public.user_performance_roles assignment
    using public.performance_roles role
    where assignment.user_id = v_user_id
      and role.id = assignment.performance_role_id
      and role.domain = 'dance';

    insert into public.user_performance_roles (
      user_id,
      performance_role_id,
      is_primary
    )
    select
      v_user_id,
      selected.role_id,
      selected.role_id = p_primary_role_id
    from unnest(v_requested_role_ids) with ordinality
      as selected(role_id, ordinal)
    order by selected.ordinal;
  end if;

  select profile.performance_domain
  into v_saved_performance_domain
  from public.users profile
  where profile.id = v_user_id;

  select coalesce(
    array_agg(genre.id order by genre.sort_order, genre.code),
    '{}'::uuid[]
  )
  into v_saved_genre_ids
  from public.user_genres assignment
  join public.genres genre on genre.id = assignment.genre_id
  where assignment.user_id = v_user_id
    and genre.domain = 'dance';

  select
    coalesce(
      array_agg(role.id order by role.sort_order, role.code),
      '{}'::uuid[]
    ),
    coalesce(
      array_agg(role.id order by role.sort_order, role.code)
        filter (where assignment.is_primary),
      '{}'::uuid[]
    )
  into v_saved_role_ids, v_saved_primary_role_ids
  from public.user_performance_roles assignment
  join public.performance_roles role
    on role.id = assignment.performance_role_id
  where assignment.user_id = v_user_id
    and role.domain = 'dance';

  if cardinality(v_saved_primary_role_ids) = 1 then
    v_saved_primary_role_id := v_saved_primary_role_ids[1];
  end if;

  if v_saved_genre_ids is distinct from v_requested_genre_ids
    or v_saved_role_ids is distinct from v_requested_role_ids
    or cardinality(v_saved_primary_role_ids) <> 1
    or v_saved_primary_role_id is distinct from p_primary_role_id
    or v_saved_performance_domain is distinct from
      v_effective_performance_domain then
    raise exception 'saved STAGE taxonomy state does not match the request'
      using errcode = '55000';
  end if;

  return query
  select
    'dance'::text,
    true,
    v_saved_genre_ids,
    v_saved_role_ids,
    v_saved_primary_role_id;
end;
$$;

comment on function public.replace_my_stage_taxonomy_v1(
  text,
  uuid[],
  uuid[],
  uuid
) is
  'Authenticated self-only atomic Dance taxonomy replacement; derives the user from auth, accepts no target-user parameter, and preserves Band/unrelated-domain assignments.';

-- PostgreSQL grants new functions to PUBLIC by default. Remove every app-role
-- grant first, then expose only these exact signatures to authenticated users.
-- A project-default service_role ACL entry is intentionally neither granted nor
-- revoked here and is only tolerated by the postcondition.
revoke all on function public.get_my_stage_taxonomy_v1(text)
  from public, anon, authenticated;
revoke all on function public.replace_my_stage_taxonomy_v1(
  text,
  uuid[],
  uuid[],
  uuid
) from public, anon, authenticated;

grant execute on function public.get_my_stage_taxonomy_v1(text)
  to authenticated;
grant execute on function public.replace_my_stage_taxonomy_v1(
  text,
  uuid[],
  uuid[],
  uuid
) to authenticated;

-- Prove the new contracts and ACLs, and prove that every pre-existing data row,
-- relation, view, function, policy, table privilege, column, constraint, index,
-- and trigger captured above remained unchanged.
do $postconditions$
declare
  v_snapshot record;
  v_function_oid oid;
  v_function_owner oid;
  v_function_config text[];
  v_rpc record;
  v_users_after jsonb;
  v_genres_after jsonb;
  v_user_genres_after jsonb;
  v_performance_roles_after jsonb;
  v_user_performance_roles_after jsonb;
  v_public_relations_after jsonb;
  v_views_after jsonb;
  v_functions_after jsonb;
  v_policies_after jsonb;
  v_columns_after jsonb;
  v_constraints_after jsonb;
  v_indexes_after jsonb;
  v_triggers_after jsonb;
begin
  select *
  into v_snapshot
  from pg_temp.migration_035_snapshot;

  if (
    select count(*)
    from pg_proc procedure_row
    join pg_namespace namespace on namespace.oid = procedure_row.pronamespace
    where namespace.nspname = 'public'
      and procedure_row.proname = 'get_my_stage_taxonomy_v1'
  ) <> 1 or (
    select count(*)
    from pg_proc procedure_row
    join pg_namespace namespace on namespace.oid = procedure_row.pronamespace
    where namespace.nspname = 'public'
      and procedure_row.proname = 'replace_my_stage_taxonomy_v1'
  ) <> 1 then
    raise exception 'Migration 035 RPC signatures are missing or ambiguous'
      using errcode = '55000';
  end if;

  for v_rpc in
    select *
    from (
      values
        (
          'public.get_my_stage_taxonomy_v1(text)'::text,
          'text'::text,
          array['p_performance_domain']::text[],
          's'::"char",
          'Authenticated self-only Dance taxonomy aggregate read; returns no private profile fields and fails on partial stored state.'::text
        ),
        (
          'public.replace_my_stage_taxonomy_v1(text,uuid[],uuid[],uuid)'::text,
          'text, uuid[], uuid[], uuid'::text,
          array[
            'p_performance_domain',
            'p_genre_ids',
            'p_role_ids',
            'p_primary_role_id'
          ]::text[],
          'v'::"char",
          'Authenticated self-only atomic Dance taxonomy replacement; derives the user from auth, accepts no target-user parameter, and preserves Band/unrelated-domain assignments.'::text
        )
    ) expected(
      signature,
      input_type_contract,
      input_name_contract,
      volatility_code,
      comment_text
    )
  loop
    v_function_oid := to_regprocedure(v_rpc.signature);

    if v_function_oid is null then
      raise exception 'Migration 035 RPC is missing: %', v_rpc.signature
        using errcode = '55000';
    end if;

    select procedure_row.proowner, procedure_row.proconfig
    into v_function_owner, v_function_config
    from pg_proc procedure_row
    where procedure_row.oid = v_function_oid;

    if (
      select language.lanname
      from pg_proc procedure_row
      join pg_language language on language.oid = procedure_row.prolang
      where procedure_row.oid = v_function_oid
    ) <> 'plpgsql' or (
      select procedure_row.provolatile
      from pg_proc procedure_row
      where procedure_row.oid = v_function_oid
    ) <> v_rpc.volatility_code or not (
      select procedure_row.prosecdef
      from pg_proc procedure_row
      where procedure_row.oid = v_function_oid
    ) or not coalesce(
      v_function_config = array['search_path=public, pg_temp'],
      false
    ) or (
      select oidvectortypes(procedure_row.proargtypes)
      from pg_proc procedure_row
      where procedure_row.oid = v_function_oid
    ) <> v_rpc.input_type_contract or (
      select procedure_row.proargnames[1:procedure_row.pronargs]
      from pg_proc procedure_row
      where procedure_row.oid = v_function_oid
    ) is distinct from v_rpc.input_name_contract
      or pg_get_function_result(v_function_oid) <>
      'TABLE(domain text, has_saved_taxonomy boolean, genre_ids uuid[], role_ids uuid[], primary_role_id uuid)' or obj_description(
        v_function_oid,
        'pg_proc'
      ) is distinct from v_rpc.comment_text then
      raise exception 'Migration 035 RPC contract is incompatible: %',
        v_rpc.signature
        using errcode = '55000';
    end if;

    if not has_function_privilege(
      'authenticated',
      v_function_oid,
      'EXECUTE'
    ) then
      raise exception 'Migration 035 RPC lacks authenticated EXECUTE: %',
        v_rpc.signature
        using errcode = '55000';
    end if;

    if has_function_privilege('anon', v_function_oid, 'EXECUTE') then
      raise exception 'Migration 035 RPC grants anon EXECUTE: %',
        v_rpc.signature
        using errcode = '55000';
    end if;

    if exists (
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
      raise exception 'Migration 035 RPC grants PUBLIC EXECUTE: %',
        v_rpc.signature
        using errcode = '55000';
    end if;

    -- Only the owner, authenticated, and an optional pre-existing service_role
    -- entry may execute. Explicit role matching avoids NOT IN null semantics.
    if exists (
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
        and acl_row.grantee <> 0
        and acl_row.grantee <> v_function_owner
        and not exists (
          select 1
          from pg_roles grantee_role
          where grantee_role.oid = acl_row.grantee
            and grantee_role.rolname in (
              'authenticated',
              'service_role'
            )
        )
    ) then
      raise exception 'Migration 035 RPC has unexpected EXECUTE grantee: %',
        v_rpc.signature
        using errcode = '55000';
    end if;
  end loop;

  if (
    select count(*)
    from public.genres genre
    where genre.domain = 'dance'
  ) <> 11 or exists (
    with expected(code, name, category, sort_order) as (
      values
        ('dance_kpop', 'K-POP', 'commercial', 101::smallint),
        ('dance_hiphop', 'HIPHOP', 'street', 102::smallint),
        (
          'dance_jazz',
          'JAZZ',
          'jazz_contemporary',
          103::smallint
        ),
        (
          'dance_jazz_hiphop',
          'JAZZ HIPHOP',
          'jazz_contemporary',
          104::smallint
        ),
        (
          'dance_girls_hiphop',
          'GIRLS HIPHOP',
          'commercial',
          105::smallint
        ),
        ('dance_waack', 'WAACK', 'street', 106::smallint),
        ('dance_locking', 'LOCKING', 'street', 107::smallint),
        ('dance_popping', 'POPPING', 'street', 108::smallint),
        ('dance_breaking', 'BREAKING', 'street', 109::smallint),
        ('dance_house', 'HOUSE', 'street', 110::smallint),
        ('dance_other', 'その他（ダンス）', 'other', 111::smallint)
    )
    select 1
    from expected
    left join public.genres genre on genre.code = expected.code
    where genre.id is null
      or genre.name is distinct from expected.name
      or genre.domain is distinct from 'dance'
      or genre.category is distinct from expected.category
      or genre.sort_order is distinct from expected.sort_order
      or genre.is_active is distinct from true
  ) then
    raise exception 'Migration 035 Dance genre postcondition failed'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from public.performance_roles
  ) <> 4 or exists (
    with expected(code, name, sort_order) as (
      values
        ('dance_dancer', 'ダンサー', 101::smallint),
        ('dance_choreographer', '振付師', 102::smallint),
        ('dance_instructor', 'インストラクター', 103::smallint),
        ('dance_other', 'その他', 199::smallint)
    )
    select 1
    from expected
    left join public.performance_roles role on role.code = expected.code
    where role.id is null
      or role.name is distinct from expected.name
      or role.domain is distinct from 'dance'
      or role.sort_order is distinct from expected.sort_order
      or role.is_active is distinct from true
  ) then
    raise exception 'Migration 035 Dance role postcondition failed'
      using errcode = '55000';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', profile.id,
        'performance_domain', profile.performance_domain,
        'updated_at', profile.updated_at
      )
      order by profile.id
    ),
    '[]'::jsonb
  )
  into v_users_after
  from public.users profile;

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
    jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
    '[]'::jsonb
  )
  into v_performance_roles_after
  from public.performance_roles snapshot_row;

  select coalesce(
    jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
    '[]'::jsonb
  )
  into v_user_performance_roles_after
  from public.user_performance_roles snapshot_row;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'oid', relation.oid,
        'schema', namespace.nspname,
        'name', relation.relname,
        'kind', relation.relkind,
        'owner', relation.relowner,
        'acl', to_jsonb(relation.relacl),
        'rls', relation.relrowsecurity,
        'force_rls', relation.relforcerowsecurity
      )
      order by relation.oid
    ),
    '[]'::jsonb
  )
  into v_public_relations_after
  from pg_class relation
  join pg_namespace namespace on namespace.oid = relation.relnamespace
  where namespace.nspname = 'public';

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
  join pg_namespace namespace on namespace.oid = relation.relnamespace
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
  join pg_namespace namespace on namespace.oid = procedure_row.pronamespace
  where namespace.nspname = 'public'
    and procedure_row.prokind in ('f', 'p')
    and procedure_row.proname not in (
      'get_my_stage_taxonomy_v1',
      'replace_my_stage_taxonomy_v1'
    );

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

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'relation_oid', attribute.attrelid,
        'number', attribute.attnum,
        'name', attribute.attname,
        'type', format_type(attribute.atttypid, attribute.atttypmod),
        'not_null', attribute.attnotnull,
        'default', pg_get_expr(default_row.adbin, default_row.adrelid),
        'generated', attribute.attgenerated,
        'identity', attribute.attidentity
      )
      order by attribute.attrelid, attribute.attnum
    ),
    '[]'::jsonb
  )
  into v_columns_after
  from pg_attribute attribute
  left join pg_attrdef default_row
    on default_row.adrelid = attribute.attrelid
    and default_row.adnum = attribute.attnum
  where attribute.attrelid in (
    'public.users'::regclass,
    'public.genres'::regclass,
    'public.user_genres'::regclass,
    'public.performance_roles'::regclass,
    'public.user_performance_roles'::regclass
  )
    and attribute.attnum > 0
    and not attribute.attisdropped;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'oid', constraint_row.oid,
        'relation_oid', constraint_row.conrelid,
        'name', constraint_row.conname,
        'type', constraint_row.contype,
        'validated', constraint_row.convalidated,
        'deferrable', constraint_row.condeferrable,
        'deferred', constraint_row.condeferred,
        'definition', pg_get_constraintdef(constraint_row.oid, false)
      )
      order by constraint_row.oid
    ),
    '[]'::jsonb
  )
  into v_constraints_after
  from pg_constraint constraint_row
  where constraint_row.conrelid in (
    'public.users'::regclass,
    'public.genres'::regclass,
    'public.user_genres'::regclass,
    'public.performance_roles'::regclass,
    'public.user_performance_roles'::regclass
  );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'oid', index_row.indexrelid,
        'relation_oid', index_row.indrelid,
        'definition', pg_get_indexdef(index_row.indexrelid)
      )
      order by index_row.indexrelid
    ),
    '[]'::jsonb
  )
  into v_indexes_after
  from pg_index index_row
  where index_row.indrelid in (
    'public.users'::regclass,
    'public.genres'::regclass,
    'public.user_genres'::regclass,
    'public.performance_roles'::regclass,
    'public.user_performance_roles'::regclass
  );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'oid', trigger_row.oid,
        'relation_oid', trigger_row.tgrelid,
        'name', trigger_row.tgname,
        'enabled', trigger_row.tgenabled,
        'definition', pg_get_triggerdef(trigger_row.oid, false)
      )
      order by trigger_row.oid
    ),
    '[]'::jsonb
  )
  into v_triggers_after
  from pg_trigger trigger_row
  where trigger_row.tgrelid in (
    'public.users'::regclass,
    'public.genres'::regclass,
    'public.user_genres'::regclass,
    'public.performance_roles'::regclass,
    'public.user_performance_roles'::regclass
  )
    and not trigger_row.tgisinternal;

  if v_users_after is distinct from v_snapshot.users_data
    or v_genres_after is distinct from v_snapshot.genres_data
    or v_user_genres_after is distinct from v_snapshot.user_genres_data
    or v_performance_roles_after is distinct from
      v_snapshot.performance_roles_data
    or v_user_performance_roles_after is distinct from
      v_snapshot.user_performance_roles_data then
    raise exception 'Migration 035 changed existing taxonomy/profile data'
      using errcode = '55000';
  end if;

  if v_public_relations_after is distinct from v_snapshot.public_relations
    or v_views_after is distinct from v_snapshot.view_definitions
    or v_functions_after is distinct from v_snapshot.function_definitions
    or v_policies_after is distinct from v_snapshot.policy_definitions
    or v_columns_after is distinct from v_snapshot.column_definitions
    or v_constraints_after is distinct from v_snapshot.constraint_definitions
    or v_indexes_after is distinct from v_snapshot.index_definitions
    or v_triggers_after is distinct from v_snapshot.trigger_definitions then
    raise exception
      'Migration 035 changed an existing schema, grant, RLS, or RPC contract'
      using errcode = '55000';
  end if;
end;
$postconditions$;

notify pgrst, 'reload schema';

commit;

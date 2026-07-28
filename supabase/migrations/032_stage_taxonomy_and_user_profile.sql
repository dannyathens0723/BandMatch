-- STAGE taxonomy and user-profile foundation.
-- Existing genres remain Band/legacy music: their stable identities and
-- meaning must not be reinterpreted as dance taxonomy.
--
-- Dance seeds are intentionally inactive until a later STAGE release has
-- compatible product queries and UI. "STREET" is a category, not a genre row.
--
-- Professional verification is deliberately limited to an unverified
-- self-declaration here. Migration 033 owns performance roles, 034 owns the
-- private station model, 035 owns professional verification, and 036 owns
-- events and event sources.
-- Run after 031_unread_chat_message_counts.sql.

begin;

-- Fail before taking locks or changing schema when the expected source is
-- incomplete. Migration 032 intentionally has no repair path for missing
-- earlier objects.
do $$
begin
  if to_regclass('public.users') is null then
    raise exception 'Migration 032 requires public.users'
      using errcode = '55000';
  end if;

  if to_regclass('public.genres') is null then
    raise exception 'Migration 032 requires public.genres'
      using errcode = '55000';
  end if;

  if to_regclass('public.user_genres') is null then
    raise exception 'Migration 032 requires public.user_genres'
      using errcode = '55000';
  end if;
end;
$$;

-- Keep taxonomy, user assignments, and the existing-user snapshot stable
-- between preflight and final assertions.
lock table public.genres, public.user_genres, public.users
  in share row exclusive mode;

do $$
declare
  v_legacy_codes text[] := array[
    'pops',
    'rock',
    'hard_rock_heavy_metal',
    'punk_melocore',
    'hardcore',
    'thrash_death_metal',
    'visual_kei',
    'funk_blues',
    'jazz_fusion',
    'country_folk',
    'ska_rockabilly',
    'soul_rnb',
    'gospel_a_cappella',
    'bossa_nova_latin',
    'classical',
    'hiphop_reggae',
    'house_techno',
    'anison_vocaloid'
  ];
  v_dance_codes text[] := array[
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
  v_has_genres_domain boolean;
  v_has_genres_category boolean;
  v_has_users_performance_domain boolean;
  v_has_users_professional_state boolean;
  v_has_constraint boolean;
  v_data_type text;
  v_not_null boolean;
  v_default_expression text;
  v_generated text;
  v_identity text;
  v_constraint_type "char";
  v_constraint_validated boolean;
  v_constraint_expression text;
  v_existing_dance_count integer;
  v_conflict boolean;
  v_legacy_before jsonb;
  v_legacy_after jsonb;
  v_user_genres_before jsonb;
  v_user_genres_after jsonb;
  v_users_before jsonb;
  v_users_after jsonb;
  v_views_before jsonb;
  v_views_after jsonb;
  v_functions_before jsonb;
  v_functions_after jsonb;
begin
  select exists (
    select 1
    from pg_attribute
    where attrelid = 'public.genres'::regclass
      and attname = 'domain'
      and not attisdropped
  ) into v_has_genres_domain;

  select exists (
    select 1
    from pg_attribute
    where attrelid = 'public.genres'::regclass
      and attname = 'category'
      and not attisdropped
  ) into v_has_genres_category;

  select exists (
    select 1
    from pg_attribute
    where attrelid = 'public.users'::regclass
      and attname = 'performance_domain'
      and not attisdropped
  ) into v_has_users_performance_domain;

  select exists (
    select 1
    from pg_attribute
    where attrelid = 'public.users'::regclass
      and attname = 'professional_state'
      and not attisdropped
  ) into v_has_users_professional_state;

  -- Existing columns are accepted only when their type, nullability, and
  -- defaults already match the approved contract.
  if v_has_genres_domain then
    select
      format_type(attribute.atttypid, attribute.atttypmod),
      attribute.attnotnull,
      pg_get_expr(default_value.adbin, default_value.adrelid),
      attribute.attgenerated,
      attribute.attidentity
    into
      v_data_type,
      v_not_null,
      v_default_expression,
      v_generated,
      v_identity
    from pg_attribute attribute
    left join pg_attrdef default_value
      on default_value.adrelid = attribute.attrelid
      and default_value.adnum = attribute.attnum
    where attribute.attrelid = 'public.genres'::regclass
      and attribute.attname = 'domain'
      and not attribute.attisdropped;

    if v_data_type <> 'text'
      or not v_not_null
      or v_default_expression <> '''band''::text'
      or v_generated <> ''
      or v_identity <> '' then
      raise exception 'Incompatible partial state for public.genres.domain'
        using errcode = '55000';
    end if;
  end if;

  if v_has_genres_category then
    select
      format_type(attribute.atttypid, attribute.atttypmod),
      attribute.attnotnull,
      pg_get_expr(default_value.adbin, default_value.adrelid),
      attribute.attgenerated,
      attribute.attidentity
    into
      v_data_type,
      v_not_null,
      v_default_expression,
      v_generated,
      v_identity
    from pg_attribute attribute
    left join pg_attrdef default_value
      on default_value.adrelid = attribute.attrelid
      and default_value.adnum = attribute.attnum
    where attribute.attrelid = 'public.genres'::regclass
      and attribute.attname = 'category'
      and not attribute.attisdropped;

    if v_data_type <> 'text'
      or not v_not_null
      or v_default_expression <> '''legacy_music''::text'
      or v_generated <> ''
      or v_identity <> '' then
      raise exception 'Incompatible partial state for public.genres.category'
        using errcode = '55000';
    end if;
  end if;

  if v_has_users_performance_domain then
    select
      format_type(attribute.atttypid, attribute.atttypmod),
      attribute.attnotnull,
      pg_get_expr(default_value.adbin, default_value.adrelid),
      attribute.attgenerated,
      attribute.attidentity
    into
      v_data_type,
      v_not_null,
      v_default_expression,
      v_generated,
      v_identity
    from pg_attribute attribute
    left join pg_attrdef default_value
      on default_value.adrelid = attribute.attrelid
      and default_value.adnum = attribute.attnum
    where attribute.attrelid = 'public.users'::regclass
      and attribute.attname = 'performance_domain'
      and not attribute.attisdropped;

    if v_data_type <> 'text'
      or v_not_null
      or v_default_expression is not null
      or v_generated <> ''
      or v_identity <> '' then
      raise exception
        'Incompatible partial state for public.users.performance_domain'
        using errcode = '55000';
    end if;
  end if;

  if v_has_users_professional_state then
    select
      format_type(attribute.atttypid, attribute.atttypmod),
      attribute.attnotnull,
      pg_get_expr(default_value.adbin, default_value.adrelid),
      attribute.attgenerated,
      attribute.attidentity
    into
      v_data_type,
      v_not_null,
      v_default_expression,
      v_generated,
      v_identity
    from pg_attribute attribute
    left join pg_attrdef default_value
      on default_value.adrelid = attribute.attrelid
      and default_value.adnum = attribute.attnum
    where attribute.attrelid = 'public.users'::regclass
      and attribute.attname = 'professional_state'
      and not attribute.attisdropped;

    if v_data_type <> 'text'
      or not v_not_null
      or v_default_expression <> '''general''::text'
      or v_generated <> ''
      or v_identity <> '' then
      raise exception
        'Incompatible partial state for public.users.professional_state'
        using errcode = '55000';
    end if;
  end if;

  -- A matching named constraint may already exist in a compatible partial
  -- environment. A name collision with any other expression is unsafe.
  select exists (
    select 1
    from pg_constraint
    where conrelid = 'public.genres'::regclass
      and conname = 'genres_domain_check'
  ) into v_has_constraint;

  if v_has_constraint then
    select
      constraint_row.contype,
      constraint_row.convalidated,
      regexp_replace(
        pg_get_expr(constraint_row.conbin, constraint_row.conrelid),
        '[[:space:]]+',
        '',
        'g'
      )
    into
      v_constraint_type,
      v_constraint_validated,
      v_constraint_expression
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.genres'::regclass
      and constraint_row.conname = 'genres_domain_check';

    if not v_has_genres_domain
      or v_constraint_type <> 'c'
      or not v_constraint_validated
      or v_constraint_expression not in (
        '(domain=ANY(ARRAY[''band''::text,''dance''::text]))',
        'domain=ANY(ARRAY[''band''::text,''dance''::text])'
      ) then
      raise exception 'Incompatible constraint genres_domain_check'
        using errcode = '55000';
    end if;
  end if;

  select exists (
    select 1
    from pg_constraint
    where conrelid = 'public.genres'::regclass
      and conname = 'genres_category_check'
  ) into v_has_constraint;

  if v_has_constraint then
    select
      constraint_row.contype,
      constraint_row.convalidated,
      regexp_replace(
        pg_get_expr(constraint_row.conbin, constraint_row.conrelid),
        '[[:space:]]+',
        '',
        'g'
      )
    into
      v_constraint_type,
      v_constraint_validated,
      v_constraint_expression
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.genres'::regclass
      and constraint_row.conname = 'genres_category_check';

    if not v_has_genres_category
      or v_constraint_type <> 'c'
      or not v_constraint_validated
      or v_constraint_expression not in (
        '(category=ANY(ARRAY[''legacy_music''::text,'
          || '''commercial''::text,''street''::text,'
          || '''jazz_contemporary''::text,''entertainment''::text,'
          || '''other''::text]))',
        'category=ANY(ARRAY[''legacy_music''::text,'
          || '''commercial''::text,''street''::text,'
          || '''jazz_contemporary''::text,''entertainment''::text,'
          || '''other''::text])'
      ) then
      raise exception 'Incompatible constraint genres_category_check'
        using errcode = '55000';
    end if;
  end if;

  select exists (
    select 1
    from pg_constraint
    where conrelid = 'public.users'::regclass
      and conname = 'users_performance_domain_check'
  ) into v_has_constraint;

  if v_has_constraint then
    select
      constraint_row.contype,
      constraint_row.convalidated,
      regexp_replace(
        pg_get_expr(constraint_row.conbin, constraint_row.conrelid),
        '[[:space:]]+',
        '',
        'g'
      )
    into
      v_constraint_type,
      v_constraint_validated,
      v_constraint_expression
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.users'::regclass
      and constraint_row.conname = 'users_performance_domain_check';

    if not v_has_users_performance_domain
      or v_constraint_type <> 'c'
      or not v_constraint_validated
      or v_constraint_expression not in (
        '(performance_domain=ANY(ARRAY[''band''::text,''dance''::text,'
          || '''multi_domain''::text]))',
        'performance_domain=ANY(ARRAY[''band''::text,''dance''::text,'
          || '''multi_domain''::text])'
      ) then
      raise exception
        'Incompatible constraint users_performance_domain_check'
        using errcode = '55000';
    end if;
  end if;

  select exists (
    select 1
    from pg_constraint
    where conrelid = 'public.users'::regclass
      and conname = 'users_professional_state_check'
  ) into v_has_constraint;

  if v_has_constraint then
    select
      constraint_row.contype,
      constraint_row.convalidated,
      regexp_replace(
        pg_get_expr(constraint_row.conbin, constraint_row.conrelid),
        '[[:space:]]+',
        '',
        'g'
      )
    into
      v_constraint_type,
      v_constraint_validated,
      v_constraint_expression
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'public.users'::regclass
      and constraint_row.conname = 'users_professional_state_check';

    if not v_has_users_professional_state
      or v_constraint_type <> 'c'
      or not v_constraint_validated
      or v_constraint_expression not in (
        '(professional_state=ANY(ARRAY[''general''::text,'
          || '''professional_unverified''::text]))',
        'professional_state=ANY(ARRAY[''general''::text,'
          || '''professional_unverified''::text])'
      ) then
      raise exception
        'Incompatible constraint users_professional_state_check'
        using errcode = '55000';
    end if;
  end if;

  -- The 18 legacy rows must still match migration 002. Their active state is
  -- intentionally not fixed here because operations may have deactivated a
  -- row after seeding.
  with expected(code, name, sort_order) as (
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
      ('anison_vocaloid', 'アニソン・ボカロ', 18)
  )
  select exists (
    select 1
    from expected
    left join public.genres genre on genre.code = expected.code
    where genre.id is null
      or genre.name is distinct from expected.name
      or genre.sort_order is distinct from expected.sort_order
  ) into v_conflict;

  if v_conflict then
    raise exception
      'Legacy genre identity differs from migration 002 history'
      using errcode = '55000';
  end if;

  -- Only repository-history rows and exact, previously applied approved seeds
  -- are accepted. Unexpected taxonomy requires a separate reviewed migration.
  if exists (
    select 1
    from public.genres genre
    where not (
      genre.code = any(v_legacy_codes)
      or genre.code = any(v_dance_codes)
    )
  ) then
    raise exception 'Unexpected pre-Migration-032 genre row detected'
      using errcode = '55000';
  end if;

  with expected(code, name, category, sort_order) as (
    values
      ('dance_kpop', 'K-POP', 'commercial', 101),
      ('dance_hiphop', 'HIPHOP', 'street', 102),
      ('dance_jazz', 'JAZZ', 'jazz_contemporary', 103),
      (
        'dance_jazz_hiphop',
        'JAZZ HIPHOP',
        'jazz_contemporary',
        104
      ),
      ('dance_girls_hiphop', 'GIRLS HIPHOP', 'commercial', 105),
      ('dance_waack', 'WAACK', 'street', 106),
      ('dance_locking', 'LOCKING', 'street', 107),
      ('dance_popping', 'POPPING', 'street', 108),
      ('dance_breaking', 'BREAKING', 'street', 109),
      ('dance_house', 'HOUSE', 'street', 110),
      ('dance_other', 'その他（ダンス）', 'other', 111)
  )
  select exists (
    select 1
    from expected
    join public.genres genre on genre.code = expected.code
    where genre.name is distinct from expected.name
      or genre.sort_order is distinct from expected.sort_order
      or genre.is_active is distinct from false
  ) into v_conflict;

  if v_conflict then
    raise exception 'Existing dance seed code has conflicting metadata'
      using errcode = '55000';
  end if;

  with expected(code, name, sort_order) as (
    values
      ('dance_kpop', 'K-POP', 101),
      ('dance_hiphop', 'HIPHOP', 102),
      ('dance_jazz', 'JAZZ', 103),
      ('dance_jazz_hiphop', 'JAZZ HIPHOP', 104),
      ('dance_girls_hiphop', 'GIRLS HIPHOP', 105),
      ('dance_waack', 'WAACK', 106),
      ('dance_locking', 'LOCKING', 107),
      ('dance_popping', 'POPPING', 108),
      ('dance_breaking', 'BREAKING', 109),
      ('dance_house', 'HOUSE', 110),
      ('dance_other', 'その他（ダンス）', 111)
  )
  select exists (
    select 1
    from expected
    join public.genres genre
      on (
        genre.name = expected.name
        or genre.sort_order = expected.sort_order
      )
      and genre.code <> expected.code
  ) into v_conflict;

  if v_conflict then
    raise exception
      'Approved dance seed name or sort order belongs to another code'
      using errcode = '55000';
  end if;

  select count(*)
  into v_existing_dance_count
  from public.genres
  where code = any(v_dance_codes);

  if v_existing_dance_count > 0
    and not (v_has_genres_domain and v_has_genres_category) then
    raise exception
      'Existing dance seeds require compatible domain and category columns'
      using errcode = '55000';
  end if;

  if v_has_genres_domain then
    execute
      'select exists (
         select 1
         from public.genres
         where code = any($1)
           and domain is distinct from ''band''
       )'
    into v_conflict
    using v_legacy_codes;

    if v_conflict then
      raise exception 'Existing legacy genre domain is not band'
        using errcode = '55000';
    end if;

    execute
      'select exists (
         select 1
         from public.genres
         where code = any($1)
           and domain is distinct from ''dance''
       )'
    into v_conflict
    using v_dance_codes;

    if v_conflict then
      raise exception 'Existing dance seed domain is not dance'
        using errcode = '55000';
    end if;

    execute
      'select exists (
         select 1
         from public.genres
         where domain not in (''band'', ''dance'')
       )'
    into v_conflict;

    if v_conflict then
      raise exception 'Existing genre domain contains an unsupported value'
        using errcode = '55000';
    end if;
  end if;

  if v_has_genres_category then
    execute
      'select exists (
         select 1
         from public.genres
         where code = any($1)
           and category is distinct from ''legacy_music''
       )'
    into v_conflict
    using v_legacy_codes;

    if v_conflict then
      raise exception 'Existing legacy genre category is not legacy_music'
        using errcode = '55000';
    end if;

    execute
      'with expected(code, category) as (
         values
           (''dance_kpop'', ''commercial''),
           (''dance_hiphop'', ''street''),
           (''dance_jazz'', ''jazz_contemporary''),
           (''dance_jazz_hiphop'', ''jazz_contemporary''),
           (''dance_girls_hiphop'', ''commercial''),
           (''dance_waack'', ''street''),
           (''dance_locking'', ''street''),
           (''dance_popping'', ''street''),
           (''dance_breaking'', ''street''),
           (''dance_house'', ''street''),
           (''dance_other'', ''other'')
       )
       select exists (
         select 1
         from expected
         join public.genres genre on genre.code = expected.code
         where genre.category is distinct from expected.category
       )'
    into v_conflict;

    if v_conflict then
      raise exception 'Existing dance seed category is incompatible'
        using errcode = '55000';
    end if;

    execute
      'select exists (
         select 1
         from public.genres
         where category not in (
           ''legacy_music'',
           ''commercial'',
           ''street'',
           ''jazz_contemporary'',
           ''entertainment'',
           ''other''
         )
       )'
    into v_conflict;

    if v_conflict then
      raise exception 'Existing genre category contains an unsupported value'
        using errcode = '55000';
    end if;
  end if;

  if v_has_users_performance_domain then
    execute
      'select exists (
         select 1
         from public.users
         where performance_domain is not null
           and performance_domain not in (
             ''band'',
             ''dance'',
             ''multi_domain''
           )
       )'
    into v_conflict;

    if v_conflict then
      raise exception
        'Existing performance_domain contains an unsupported value'
        using errcode = '55000';
    end if;
  end if;

  if v_has_users_professional_state then
    execute
      'select exists (
         select 1
         from public.users
         where professional_state not in (
           ''general'',
           ''professional_unverified''
         )
       )'
    into v_conflict;

    if v_conflict then
      raise exception
        'Existing professional_state contains an unsupported value'
        using errcode = '55000';
    end if;
  end if;

  -- Snapshot data and definitions that Migration 032 must not alter.
  select coalesce(
    jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.code),
    '[]'::jsonb
  )
  into v_legacy_before
  from (
    select
      genre.id,
      genre.code,
      genre.name,
      genre.sort_order,
      genre.is_active,
      genre.created_at,
      genre.updated_at
    from public.genres genre
    where genre.code = any(v_legacy_codes)
  ) snapshot_row;

  select coalesce(
    jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
    '[]'::jsonb
  )
  into v_user_genres_before
  from (
    select
      user_genre.id,
      user_genre.user_id,
      user_genre.genre_id,
      user_genre.created_at,
      user_genre.updated_at
    from public.user_genres user_genre
  ) snapshot_row;

  execute format(
    $snapshot$
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'id', profile.id,
            'performance_domain', %s,
            'professional_state', %s
          )
          order by profile.id
        ),
        '[]'::jsonb
      )
      from public.users profile
    $snapshot$,
    case
      when v_has_users_performance_domain
        then 'profile.performance_domain'
      else 'null::text'
    end,
    case
      when v_has_users_professional_state
        then 'profile.professional_state'
      else '''general''::text'
    end
  ) into v_users_before;

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
  into v_views_before
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
  into v_functions_before
  from pg_proc procedure_row
  join pg_namespace namespace on namespace.oid = procedure_row.pronamespace
  where namespace.nspname = 'public'
    and procedure_row.prokind in ('f', 'p');

  -- Constant defaults classify existing legacy genres without issuing UPDATE,
  -- so their IDs, active state, and timestamps remain untouched.
  if not v_has_genres_domain then
    execute
      'alter table public.genres
         add column domain text not null default ''band''';
  end if;

  if not v_has_genres_category then
    execute
      'alter table public.genres
         add column category text not null default ''legacy_music''';
  end if;

  if not v_has_users_performance_domain then
    execute
      'alter table public.users
         add column performance_domain text';
  end if;

  if not v_has_users_professional_state then
    execute
      'alter table public.users
         add column professional_state text not null default ''general''';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.genres'::regclass
      and conname = 'genres_domain_check'
  ) then
    execute
      'alter table public.genres
         add constraint genres_domain_check
         check (
           domain = any (array[''band''::text, ''dance''::text])
         )';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.genres'::regclass
      and conname = 'genres_category_check'
  ) then
    execute
      'alter table public.genres
         add constraint genres_category_check
         check (
           category = any (
             array[
               ''legacy_music''::text,
               ''commercial''::text,
               ''street''::text,
               ''jazz_contemporary''::text,
               ''entertainment''::text,
               ''other''::text
             ]
           )
         )';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.users'::regclass
      and conname = 'users_performance_domain_check'
  ) then
    execute
      'alter table public.users
         add constraint users_performance_domain_check
         check (
           performance_domain = any (
             array[
               ''band''::text,
               ''dance''::text,
               ''multi_domain''::text
             ]
           )
         )';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.users'::regclass
      and conname = 'users_professional_state_check'
  ) then
    execute
      'alter table public.users
         add constraint users_professional_state_check
         check (
           professional_state = any (
             array[
               ''general''::text,
               ''professional_unverified''::text
             ]
           )
         )';
  end if;

  -- Stable code is the seed identity. Preflight already rejected code, name,
  -- or sort-order drift, so an exact prior seed is a no-op and retains its ID.
  execute $seed$
    insert into public.genres (
      code,
      name,
      domain,
      category,
      sort_order,
      is_active
    )
    values
      (
        'dance_kpop',
        'K-POP',
        'dance',
        'commercial',
        101,
        false
      ),
      (
        'dance_hiphop',
        'HIPHOP',
        'dance',
        'street',
        102,
        false
      ),
      (
        'dance_jazz',
        'JAZZ',
        'dance',
        'jazz_contemporary',
        103,
        false
      ),
      (
        'dance_jazz_hiphop',
        'JAZZ HIPHOP',
        'dance',
        'jazz_contemporary',
        104,
        false
      ),
      (
        'dance_girls_hiphop',
        'GIRLS HIPHOP',
        'dance',
        'commercial',
        105,
        false
      ),
      (
        'dance_waack',
        'WAACK',
        'dance',
        'street',
        106,
        false
      ),
      (
        'dance_locking',
        'LOCKING',
        'dance',
        'street',
        107,
        false
      ),
      (
        'dance_popping',
        'POPPING',
        'dance',
        'street',
        108,
        false
      ),
      (
        'dance_breaking',
        'BREAKING',
        'dance',
        'street',
        109,
        false
      ),
      (
        'dance_house',
        'HOUSE',
        'dance',
        'street',
        110,
        false
      ),
      (
        'dance_other',
        'その他（ダンス）',
        'dance',
        'other',
        111,
        false
      )
    on conflict (code) do nothing
  $seed$;

  -- Final taxonomy assertions.
  select coalesce(
    jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.code),
    '[]'::jsonb
  )
  into v_legacy_after
  from (
    select
      genre.id,
      genre.code,
      genre.name,
      genre.sort_order,
      genre.is_active,
      genre.created_at,
      genre.updated_at
    from public.genres genre
    where genre.code = any(v_legacy_codes)
  ) snapshot_row;

  if v_legacy_after is distinct from v_legacy_before then
    raise exception 'Migration 032 changed legacy genre identity or metadata'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from public.genres
    where code = any(v_legacy_codes)
      and (
        domain is distinct from 'band'
        or category is distinct from 'legacy_music'
      )
  ) then
    raise exception 'Legacy genres were not classified as band/legacy_music'
      using errcode = '55000';
  end if;

  with expected(code, name, category, sort_order) as (
    values
      ('dance_kpop', 'K-POP', 'commercial', 101),
      ('dance_hiphop', 'HIPHOP', 'street', 102),
      ('dance_jazz', 'JAZZ', 'jazz_contemporary', 103),
      (
        'dance_jazz_hiphop',
        'JAZZ HIPHOP',
        'jazz_contemporary',
        104
      ),
      ('dance_girls_hiphop', 'GIRLS HIPHOP', 'commercial', 105),
      ('dance_waack', 'WAACK', 'street', 106),
      ('dance_locking', 'LOCKING', 'street', 107),
      ('dance_popping', 'POPPING', 'street', 108),
      ('dance_breaking', 'BREAKING', 'street', 109),
      ('dance_house', 'HOUSE', 'street', 110),
      ('dance_other', 'その他（ダンス）', 'other', 111)
  )
  select exists (
    select 1
    from expected
    left join public.genres genre on genre.code = expected.code
    where genre.id is null
      or genre.name is distinct from expected.name
      or genre.domain is distinct from 'dance'
      or genre.category is distinct from expected.category
      or genre.sort_order is distinct from expected.sort_order
      or genre.is_active is distinct from false
  ) into v_conflict;

  if v_conflict then
    raise exception 'Approved dance seed verification failed'
      using errcode = '55000';
  end if;

  if (
    select count(*)
    from public.genres
    where code = any(v_dance_codes)
  ) <> 11 then
    raise exception 'Migration 032 must contain exactly 11 approved dance codes'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from public.genres
    where left(code, 6) = 'dance_'
      and not (code = any(v_dance_codes))
  ) then
    raise exception 'Unexpected dance_* genre exists after Migration 032'
      using errcode = '55000';
  end if;

  -- Existing assignments must be byte-for-byte equivalent as JSON values.
  select coalesce(
    jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.id),
    '[]'::jsonb
  )
  into v_user_genres_after
  from (
    select
      user_genre.id,
      user_genre.user_id,
      user_genre.genre_id,
      user_genre.created_at,
      user_genre.updated_at
    from public.user_genres user_genre
  ) snapshot_row;

  if v_user_genres_after is distinct from v_user_genres_before then
    raise exception 'Migration 032 changed public.user_genres'
      using errcode = '55000';
  end if;

  -- When the columns were absent, the before-image intentionally represents
  -- the approved defaults: null performance domain and general state.
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
  into v_users_after
  from public.users profile;

  if v_users_after is distinct from v_users_before then
    raise exception
      'Migration 032 automatically classified an existing user'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from public.users
    where professional_state not in (
      'general',
      'professional_unverified'
    )
      or (
        performance_domain is not null
        and performance_domain not in ('band', 'dance', 'multi_domain')
      )
  ) then
    raise exception 'User profile foundation verification failed'
      using errcode = '55000';
  end if;

  -- The four named constraints must exist and be validated. In particular,
  -- professional_verified is absent from the allowed values.
  if (
    select count(*)
    from pg_constraint
    where convalidated
      and (
        (
          conrelid = 'public.genres'::regclass
          and conname in (
            'genres_domain_check',
            'genres_category_check'
          )
        )
        or (
          conrelid = 'public.users'::regclass
          and conname in (
            'users_performance_domain_check',
            'users_professional_state_check'
          )
        )
      )
  ) <> 4 then
    raise exception 'Migration 032 check constraints are incomplete'
      using errcode = '55000';
  end if;

  -- Adding columns must not replace any existing public view or function.
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

  if v_views_after is distinct from v_views_before then
    raise exception 'Migration 032 changed an existing public view definition'
      using errcode = '55000';
  end if;

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
  join pg_namespace namespace on namespace.oid = procedure_row.pronamespace
  where namespace.nspname = 'public'
    and procedure_row.prokind in ('f', 'p');

  if v_functions_after is distinct from v_functions_before then
    raise exception
      'Migration 032 changed an existing public function definition'
      using errcode = '55000';
  end if;
end;
$$;

notify pgrst, 'reload schema';

commit;

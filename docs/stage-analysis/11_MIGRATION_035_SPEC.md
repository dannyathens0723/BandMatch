# Migration 035: STAGE taxonomy persistence and reload specification

## Document status

- **Task type:** design only; this document is not executable SQL.
- **Repository branch inspected:** `stage-redesign`
- **Repository HEAD inspected:** `5e50d5ad1432401efde8ea41fb893e0ec8844c2a`
- **Working tree at analysis start:** clean
- **Migration baseline:** numbered migrations `001` through `034` exist; the latest is `034_stage_domain_genre_access_and_activation.sql`.
- **Implementation boundary:** Migration 035 will persist and reload only the authenticated user's Dance genre and Dance performance-role selections.
- **Compatibility target:** Flutter Web and future iOS clients use the same versioned PostgREST RPC contracts. No Web-only API is part of this design.

Labels used throughout this document:

- **Confirmed fact:** directly verified in the repository.
- **Recommendation:** the proposed Migration 035 design.
- **Decision required:** a choice that should be explicitly approved before SQL implementation.

---

## 1. Purpose

Migration 035 should add the minimum database API required for this flow:

1. An authenticated user opens the STAGE taxonomy screen.
2. The app loads the user's saved Dance taxonomy, if one exists.
3. The user selects one or more active Dance genres.
4. The user selects one or more active Dance performance roles.
5. The user chooses exactly one selected role as the primary role.
6. One RPC validates and saves genres and roles atomically.
7. The same safe aggregate state is returned after save and can be reloaded on later launches.

Migration 035 must not persist or redesign:

- display name;
- biography;
- avatar;
- nearest station or activity area;
- experience level;
- professional verification;
- crew membership;
- recruitment preferences.

**Recommendation:** create exactly two new versioned functions:

- `get_my_stage_taxonomy_v1(text)` for the self-only aggregate read;
- `replace_my_stage_taxonomy_v1(text, uuid[], uuid[], uuid)` for the atomic self-only replacement.

No table, column, index, trigger, view, RLS policy, or direct-table grant is required by the recommended Migration 035 design.

---

## 2. Current schema findings

### 2.1 Migration baseline

**Confirmed fact:** Migration 001 created `users`, `genres`, and `user_genres`. Migration 032 extended the taxonomy and user profile. Migration 033 added performance roles and their assignments. Migration 034 activated the approved Dance genres and added the domain-safe genre master RPC.

**Confirmed fact:** migrations 001–034 are the immutable repository source history. Migration 035 must be additive and must not edit them.

**Not remotely verified:** this design-only task did not connect to Supabase, so the repository cannot prove the remote `supabase_migrations.schema_migrations` state. Before future SQL execution, the operator must separately confirm that Migration 034 completed successfully and that no out-of-band schema drift exists.

### 2.2 `public.users`

Relevant confirmed columns after Migration 032:

| Column | Type/nullability | Relevant constraint/default | Use in Migration 035 |
|---|---|---|---|
| `id` | `uuid`, primary key | generated UUID | internal authenticated profile ID |
| `auth_uid` | `uuid`, not null, unique | FK to `auth.users(id)` | maps `auth.uid()` to the public profile |
| `account_status` | `text`, not null | `active`, `suspended`, `withdrawn`; default `active` | writes require an active profile |
| `performance_domain` | `text`, nullable | `band`, `dance`, `multi_domain`; no default | updated only as the related taxonomy-domain marker |
| `professional_state` | `text`, not null | `general`, `professional_unverified`; default `general` | out of scope; never read or changed by the new RPCs |
| `updated_at` | `timestamptz`, not null | maintained by `set_updated_at` | changes only if `performance_domain` actually changes during a runtime save |

The table also contains private authentication, contact, billing-adjacent, and profile fields. None belongs in either proposed return contract.

### 2.3 `public.genres`

Relevant confirmed columns after Migration 032:

| Column | Type | Contract |
|---|---|---|
| `id` | `uuid` | primary key and assignment target |
| `code` | `text` | globally unique stable seed identity |
| `name` | `text` | globally unique display name |
| `domain` | `text` | not null; `band` or `dance`; default `band` |
| `category` | `text` | approved taxonomy category; default `legacy_music` |
| `sort_order` | `smallint` | globally unique deterministic order |
| `is_active` | `boolean` | only active rows may be newly selected |
| `created_at`, `updated_at` | `timestamptz` | existing timestamp contract |

**Confirmed fact:** Migration 034 strictly activated the exact 11 approved Dance genre rows. Their stable IDs were preserved. Existing Band genre rows and all assignment rows were snapshotted and left unchanged.

**Confirmed fact:** `get_active_genres_v1(p_domain text)` returns only `id`, `code`, `name`, `domain`, `category`, and `sort_order` for active rows in `band` or `dance`, ordered by `sort_order`, then `code`.

### 2.4 `public.user_genres`

Confirmed schema:

| Column | Type | Contract |
|---|---|---|
| `id` | `uuid` | primary key, generated |
| `user_id` | `uuid`, not null | FK to `users(id)`, cascade on user delete |
| `genre_id` | `uuid`, not null | FK to `genres(id)`, restrict on genre delete |
| `created_at`, `updated_at` | `timestamptz`, not null | existing timestamp trigger |

Confirmed constraints/indexes:

- primary key on `id`;
- unique `(user_id, genre_id)`;
- `user_genres_genre_idx (genre_id, user_id)`;
- the existing `set_updated_at` trigger.

There is no domain column in the assignment table. Domain-scoped replacement must join `user_genres.genre_id` to `genres.id` and filter `genres.domain = 'dance'`.

### 2.5 `public.performance_roles`

Confirmed Migration 033 schema:

| Column | Type | Contract |
|---|---|---|
| `id` | `uuid` | primary key |
| `code` | `text` | globally unique stable role identity |
| `name` | `text` | unique within domain |
| `domain` | `text` | `band` or `dance` |
| `sort_order` | `smallint` | unique within domain |
| `is_active` | `boolean` | only active rows may be newly assigned |
| `created_at`, `updated_at` | `timestamptz` | timestamp contract |

Confirmed uniqueness/check constraints:

- `performance_roles_code_key`;
- `performance_roles_domain_name_key (domain, name)`;
- `performance_roles_domain_sort_order_key (domain, sort_order)`;
- `performance_roles_domain_check`;
- `performance_roles_name_length_check`.

**Confirmed fact:** the current master contains the four approved active Dance roles from Migration 033. No Band performance-role seed is created by migrations 001–034.

### 2.6 `public.user_performance_roles`

Confirmed schema:

| Column | Type | Contract |
|---|---|---|
| `id` | `uuid` | primary key, generated |
| `user_id` | `uuid`, not null | FK to `users(id)`, cascade on user delete |
| `performance_role_id` | `uuid`, not null | FK to `performance_roles(id)`, restrict on role delete |
| `is_primary` | `boolean`, not null | default `false` |
| `created_at`, `updated_at` | `timestamptz`, not null | existing timestamp trigger |

Confirmed constraints/indexes:

- unique `(user_id, performance_role_id)`;
- unique partial index `user_performance_roles_one_primary_per_user` on `user_id where is_primary`;
- lookup index `user_performance_roles_role_user_idx (performance_role_id, user_id)`.

**Confirmed fact:** the current unique partial index permits exactly one primary role per user globally, not one primary per domain.

### 2.7 Existing functions relevant to authentication

**Confirmed fact:** `public.current_user_id()` is a `STABLE SECURITY DEFINER` SQL helper. It maps `auth.uid()` to `users.id` and accepts no user ID parameter.

The proposed functions must still check `auth.uid()` explicitly and must never accept `p_user_id`.

### 2.8 Existing function contracts from Migration 033

#### `get_active_performance_roles_v1(text)`

- Signature: `get_active_performance_roles_v1(p_domain text)`.
- Return columns, in order: `id uuid`, `code text`, `name text`, `domain text`, `sort_order smallint`.
- `LANGUAGE plpgsql`, `STABLE`, `SECURITY INVOKER`.
- Fixed `search_path = public, pg_temp`.
- Accepts only `band` or `dance`; unsupported/null input raises SQLSTATE `22023`.
- Returns active rows ordered by `sort_order`, then `code`.
- EXECUTE is granted to `authenticated`, not `anon` or `PUBLIC`.

#### `get_my_performance_roles_v1()`

- Signature: `get_my_performance_roles_v1()`.
- Return columns, in order: `id`, `code`, `name`, `domain`, `sort_order`, `is_primary`, `is_active`.
- `LANGUAGE plpgsql`, `STABLE`, `SECURITY DEFINER`.
- Fixed `search_path = public, pg_temp`.
- Derives the user through `current_user_id()`.
- Returns all domains assigned to that user, including inactive master rows.
- Ordered by `is_primary desc`, `sort_order`, then `code`.
- EXECUTE is granted to `authenticated`, not `anon` or `PUBLIC`.

#### `replace_my_performance_roles_v1(text, uuid[], uuid)`

- Parameters: `p_performance_domain text`, `p_role_ids uuid[]`, `p_primary_role_id uuid`.
- Returns the same seven safe role fields as `get_my_performance_roles_v1()`.
- `LANGUAGE plpgsql`, `SECURITY DEFINER`, fixed `search_path = public, pg_temp`.
- Requires a mapped active profile.
- V1 accepts only `dance`.
- Validates nonempty/unique/non-null role IDs, active Dance roles, and selected primary membership.
- Locks the current `users` row and selected role master rows.
- Sets `users.performance_domain = 'dance'`.
- EXECUTE is granted only to `authenticated` among application roles.

**Critical confirmed compatibility fact:** its delete statement removes every `user_performance_roles` row for the current user without filtering role domain. The proposed aggregate RPC must not call this function internally because that would violate Migration 035's unrelated-domain preservation requirement.

### 2.9 Existing function contract from Migration 034

#### `get_active_genres_v1(text)`

- Signature: `get_active_genres_v1(p_domain text)`.
- Return columns, in order: `id uuid`, `code text`, `name text`, `domain text`, `category text`, `sort_order smallint`.
- `LANGUAGE plpgsql`, `STABLE`, `SECURITY INVOKER`.
- Fixed `search_path = public, pg_temp`.
- Accepts only `band` or `dance`; unsupported/null input raises SQLSTATE `22023`.
- Returns active rows ordered by `sort_order`, then `code`.
- EXECUTE is granted to `anon` and `authenticated`; `PUBLIC` is forbidden.
- Migration 034 tolerates an existing `service_role` ACL entry but does not grant or revoke it.

---

## 3. Existing Flutter read/write paths

### 3.1 Legacy BandMatch master-data path

**Confirmed fact:** `MasterDataService` defines `legacyBandGenresMasterQuery` with both:

- `is_active = true`;
- `domain = 'band'`.

The existing onboarding, profile edit, group edit, recruitment, and search filter UI receives the Band-only genre master list from this service. Migration 034 activation therefore does not put Dance choices into these legacy selectors.

### 3.2 Legacy current-profile direct-table path

**Confirmed fact:** `ProfileService.fetchEditableProfile()` directly selects every `user_genres.genre_id` row for the current profile. It does not filter through `genres.domain`.

**Confirmed fact:** both `ProfileService.updateCurrentProfile()` and `ProfileService.saveProfile()` call `_replaceRows('user_genres', ...)`.

`_replaceRows` performs:

1. delete every row for `user_id`;
2. insert the supplied genre IDs.

Because the supplied IDs come from the Band-only master list, a later legacy profile save can delete previously saved Dance assignments and reinsert only Band assignments.

This is not a reason to make Migration 035 non-atomic or to modify old SQL. It is a rollout risk that requires a separate Flutter compatibility change before broad production use of STAGE persistence.

### 3.3 Legacy public/safe projection consumers

The following existing SQL projections aggregate active `user_genres` without a genre-domain filter:

- `member_search_profiles` from Migration 005;
- `search_member_profiles` from Migration 017;
- `get_my_page_profile` from Migration 018;
- `get_my_group_recruitment_applications` from Migration 023;
- `get_group_members` from Migration 025.

Flutter consumers include:

- `MemberSearchService` for list/detail paths;
- `MyPageService`;
- `RecruitmentApplicationService`;
- `GroupMemberService`.

Once Dance assignments exist, their names can appear alongside Band genre names in these existing safe outputs. No private fields are exposed, but product labeling may be ambiguous. Migration 035 must not silently change these deployed contracts.

### 3.4 Existing performance-role Flutter path

**Confirmed fact:** no current Flutter source calls `get_my_performance_roles_v1`, `replace_my_performance_roles_v1`, or directly queries `user_performance_roles`.

### 3.5 Current STAGE profile-flow path

**Confirmed fact:** `StageMasterDataService` currently performs read-only master calls:

- `get_active_genres_v1({'p_domain': 'dance'})`;
- `get_active_performance_roles_v1({'p_domain': 'dance'})`.

The role master call is guarded by an authenticated-session check. The current selection screen maintains local state only and pushes a read-only summary screen.

`StageProfileTaxonomyDraft` contains:

- ordered `selectedGenreIds`;
- ordered `selectedRoleIds`;
- non-null `primaryRoleId`.

The current flow contains no persistence service, insert/update/delete call, personal read RPC, or save action.

### 3.6 Related `users` fields

**Confirmed fact:** current Flutter does not reference `users.performance_domain` or `users.professional_state` directly.

Migration 035 should update only `performance_domain` as a taxonomy-domain marker during an explicit successful STAGE save. `professional_state` and all unrelated profile fields remain untouched.

---

## 4. Compatibility constraints

Migration 035 must satisfy all of these constraints:

1. Existing Band `user_genres` rows are never deleted by a Dance replacement.
2. Existing and future non-Dance performance-role assignments are never deleted by a Dance replacement.
3. No other user's rows can be read or changed.
4. Existing RPC signatures and definitions remain unchanged.
5. Existing table RLS, policies, triggers, indexes, and grants remain unchanged.
6. Existing direct Band profile editing remains available.
7. Existing master-data and safe-profile RPC/view signatures remain unchanged.
8. No client supplies a user ID.
9. No service-role credential is used by Flutter.
10. Migration application itself changes no user assignment or profile data.

**Compatibility limitation:** the existing legacy `ProfileService` can later delete Dance genre assignments. Migration 035 guarantees that a Dance save preserves Band rows; it cannot guarantee the reverse while the legacy client keeps a whole-user delete-and-insert algorithm.

---

## 5. Architecture options considered

### Option A: separate genre RPC plus existing role RPC

Shape:

- create a new Dance genre replacement RPC;
- call it from Flutter;
- call `replace_my_performance_roles_v1` separately.

| Criterion | Assessment |
|---|---|
| Atomicity | unacceptable: one call can commit while the other fails |
| Rollback safety | weak across two PostgREST requests |
| Compatibility | existing role RPC deletes all current-user role domains |
| Validation duplication | validation split between functions/client |
| Flutter complexity | two writes, two responses, partial-success recovery |
| Concurrency | two independent transactions can interleave |
| Migration risk | superficially small, but behavior is unsafe |

**Conclusion:** reject.

### Option B: one new atomic aggregate write RPC plus one aggregate read RPC

Shape:

- one self-only write transaction validates and replaces Dance genres and Dance roles;
- one self-only read returns the persisted aggregate shape;
- existing 033/034 master and personal role RPCs stay intact.

| Criterion | Assessment |
|---|---|
| Atomicity | strong: genre and role mutation share one transaction |
| Rollback safety | any validation or write failure rolls back both sides |
| Compatibility | delete predicates are domain scoped; Band rows survive |
| Validation duplication | centralized server validation |
| Flutter complexity | one load method and one save method |
| PostgREST behavior | deterministic one-row list response |
| Concurrency | current-user row lock provides per-user serialization |
| Maintainability | versioned aggregate contract matches one UI draft |
| Migration risk | two functions only; no table rewrite |

**Conclusion:** recommended.

### Option C: new STAGE-specific assignment tables

Shape:

- create separate user-Dance-genre and user-Dance-role persistence tables;
- synchronize or separately project legacy joins.

| Criterion | Assessment |
|---|---|
| Atomicity | possible |
| Compatibility | poor: duplicates existing normalized assignments |
| Data ownership | ambiguous source of truth |
| Existing projections | require rewrites or synchronization |
| Migration risk | high: new tables, policies, indexes, and backfill rules |
| Long-term maintenance | dual taxonomy assignments invite drift |

**Conclusion:** reject for Migration 035.

---

## 6. Recommended architecture

Use Option B.

### 6.1 Objects added

1. `public.get_my_stage_taxonomy_v1(text)`
2. `public.replace_my_stage_taxonomy_v1(text, uuid[], uuid[], uuid)`

### 6.2 Objects deliberately unchanged

- `users`, `genres`, `user_genres`;
- `performance_roles`, `user_performance_roles`;
- all constraints and indexes;
- all RLS policies and table grants;
- all Migration 033 and 034 RPCs;
- all views;
- all existing rows.

### 6.3 Domain policy

V1 takes an explicit `p_performance_domain text` to match existing versioned RPC conventions, but accepts only the exact value `dance`.

Reasons:

- the current STAGE UI and approved role master are Dance-only;
- explicit domain prevents a caller from assuming the generic name supports Band;
- rejecting unsupported values is clearer than silently treating all input as Dance;
- a future multi-domain contract can use V2 without changing cached Web or shipped iOS parsing.

### 6.4 `users.performance_domain` transition

**Recommendation:** after successful validation and immediately before assignment replacement, compute:

| Current value | Value after explicit Dance save |
|---|---|
| `null` | `dance` |
| `dance` | `dance` |
| `band` | `multi_domain` |
| `multi_domain` | `multi_domain` |

This uses only an explicit existing domain value; it does not infer Band participation from genre names or assignments. The update should use `IS DISTINCT FROM` so an identical repeated save does not churn `users.updated_at`.

### 6.5 Existing RPC compatibility

- Retain all three Migration 033 RPCs unchanged.
- Retain `get_active_genres_v1` unchanged.
- Do not wrap or call `replace_my_performance_roles_v1` from the new write RPC.
- The new read may share query concepts with `get_my_performance_roles_v1`, but it should query the assignment tables directly to produce one aggregate snapshot.
- Redundant legacy RPC cleanup is explicitly deferred to a later compatibility migration after supported clients are audited.

---

## 7. Proposed write RPC contract

### 7.1 Exact signature

Conceptual PostgreSQL contract:

```text
public.replace_my_stage_taxonomy_v1(
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
```

Function attributes:

- `LANGUAGE plpgsql`
- `VOLATILE` (the PostgreSQL default, asserted explicitly in postconditions)
- `SECURITY DEFINER`
- `SET search_path = public, pg_temp`

### 7.2 PostgREST request

```json
{
  "p_performance_domain": "dance",
  "p_genre_ids": ["<genre-uuid-1>", "<genre-uuid-2>"],
  "p_role_ids": ["<role-uuid-1>", "<role-uuid-2>"],
  "p_primary_role_id": "<selected-role-uuid>"
}
```

No user ID, auth UID, email, or profile ID is accepted.

### 7.3 Success response

PostgREST returns a one-element JSON array because the function returns `TABLE`:

```json
[
  {
    "domain": "dance",
    "has_saved_taxonomy": true,
    "genre_ids": ["<genre-uuid-ordered-by-master>"],
    "role_ids": ["<role-uuid-ordered-by-master>"],
    "primary_role_id": "<selected-role-uuid>"
  }
]
```

Return guarantees:

- exactly one row on success;
- `domain` is exactly `dance`;
- `has_saved_taxonomy` is `true`;
- both arrays are non-null and nonempty;
- arrays are ordered by the related master `sort_order`, then `code`;
- `primary_role_id` belongs to `role_ids`;
- no private user field is returned.

### 7.4 Authorization

The function must:

1. reject `auth.uid() is null`;
2. derive the profile with `current_user_id()`/`auth.uid()`;
3. lock that exact `users` row `FOR UPDATE`;
4. require `account_status = 'active'`;
5. never accept or construct a target user from client input.

### 7.5 Write algorithm pseudocode

This is pseudocode, not Migration 035 SQL:

```text
assert authenticated
derive current profile from auth.uid
lock current users row FOR UPDATE
assert active profile
assert domain is exactly dance
validate arrays, uniqueness, primary membership

lock selected genre masters in deterministic UUID order FOR SHARE
assert every genre exists, is active, and domain=dance

lock selected role masters in deterministic UUID order FOR SHARE
assert every role exists, is active, and domain=dance

assert no preserved non-dance assignment is_primary=true
  (required by the current global one-primary-per-user index)

compute effective users.performance_domain
update it only if changed

if current Dance genre ID set differs from requested set:
  delete only current user's assignments joined to genre.domain=dance
  insert requested Dance genre IDs

if current Dance role IDs or primary differs from requested state:
  delete only current user's assignments joined to role.domain=dance
  insert requested Dance roles with exactly one requested primary

return the exact aggregate state in deterministic master order
```

### 7.6 Idempotency

Submitting the same valid request twice must:

- succeed twice;
- return the same aggregate values;
- create no duplicate rows because of existing unique constraints;
- preferably detect an identical set and skip delete/reinsert, preserving assignment IDs and timestamps;
- avoid updating `users.performance_domain` when it is already correct.

---

## 8. Proposed read RPC contract

### 8.1 Existing RPC reuse evaluation

`get_my_performance_roles_v1()` is safe and useful for its original role-only contract, but it cannot restore genre selections or express “no complete STAGE taxonomy saved.” Two Flutter calls would also not provide one aggregate snapshot.

**Recommendation:** keep it unchanged and add one aggregate read RPC.

### 8.2 Exact signature

```text
public.get_my_stage_taxonomy_v1(
  p_performance_domain text
)
returns table (
  domain text,
  has_saved_taxonomy boolean,
  genre_ids uuid[],
  role_ids uuid[],
  primary_role_id uuid
)
```

Function attributes:

- `LANGUAGE plpgsql`
- `STABLE`
- `SECURITY DEFINER`
- `SET search_path = public, pg_temp`

### 8.3 PostgREST request

```json
{
  "p_performance_domain": "dance"
}
```

### 8.4 Saved response

The saved response is exactly the same five-field, one-row shape returned by the write RPC.

### 8.5 No-saved-value response

If the current user has zero Dance genre assignments and zero Dance role assignments:

```json
[
  {
    "domain": "dance",
    "has_saved_taxonomy": false,
    "genre_ids": [],
    "role_ids": [],
    "primary_role_id": null
  }
]
```

The function still returns exactly one row. The Flutter caller therefore distinguishes:

- no saved taxonomy: `has_saved_taxonomy == false`;
- saved taxonomy: `has_saved_taxonomy == true`;
- authentication failure: PostgREST error with the documented SQLSTATE;
- schema/contract or inconsistent stored-state failure: PostgREST/parse error, never an empty success object.

### 8.6 Inactive historical assignments

The read contract should include assigned IDs even if the related master row was later deactivated. This matches the intent of `get_my_performance_roles_v1()` and prevents silent data loss.

The Flutter follow-up must compare saved IDs with the currently active master list and surface an explicit stale-selection state rather than silently deleting inactive IDs.

### 8.7 Incomplete stored state

If only one side exists, or role assignments exist without exactly one Dance primary, the function should fail with SQLSTATE `55000` and a stable development-facing message such as `stored STAGE taxonomy state is inconsistent`.

It must not reinterpret a partial row set as “never saved,” silently choose a primary, or silently discard IDs.

---

## 9. Validation rules

### 9.1 Error taxonomy

Recommended stable SQLSTATE mapping:

| SQLSTATE | Condition | Client category |
|---|---|---|
| `28000` | no authenticated session | authentication required |
| `55000` | no mapped active profile for write | profile state failure |
| `22004` | null genre array, role array, or primary ID | null input |
| `22023` | unsupported domain, empty array, null array element, duplicate ID, missing/inactive/wrong-domain ID, primary not selected | invalid input |
| `55000` | incomplete saved state or cross-domain primary incompatible with current schema | stored/schema state failure |

Unexpected FK/unique errors such as `23503` or `23505` should be treated as schema/concurrency failures in Flutter logs; the explicit validation and per-user lock should make them exceptional.

### 9.2 Domain

- `p_performance_domain` must be non-null and exactly `dance`.
- `band`, `multi_domain`, blank, mixed case, padded values, and arbitrary strings fail with `22023`.
- The function does not trim or normalize domain input.

### 9.3 Genres

- `p_genre_ids` is not null.
- Cardinality is at least one.
- No element is null.
- IDs are unique.
- Every ID exists.
- Every row is active.
- Every row belongs to `domain = 'dance'`.
- Missing, inactive, and wrong-domain values fail the entire operation.
- Invalid IDs are never filtered out.

### 9.4 Roles and primary role

- `p_role_ids` is not null.
- Cardinality is at least one.
- No element is null.
- IDs are unique.
- Every ID exists.
- Every row is active.
- Every row belongs to `domain = 'dance'`.
- `p_primary_role_id` is not null.
- The primary ID appears exactly once in `p_role_ids`.
- No default primary is inferred from sort order.

### 9.5 Current global primary invariant

Because `user_performance_roles_one_primary_per_user` is global, V1 cannot safely preserve an already-primary role from another domain and also insert a Dance primary.

**Recommendation for Migration 035:** reject this drift with SQLSTATE `55000` without modifying the unrelated row. Migrations 001–034 contain no Band role master, so the expected current state is compatible.

A future migration that adds non-Dance performance roles must first approve either:

- one global primary across all domains; or
- a schema change for one primary per user per domain.

Migration 035 must not silently choose this future product rule.

---

## 10. Replacement semantics

### 10.1 Dance genres

The delete scope is exactly:

- current authenticated `user_id`; and
- assignments whose joined `genres.domain = 'dance'`.

The write must preserve:

- every Band genre assignment;
- every future unrelated-domain assignment;
- every other user's assignments.

### 10.2 Dance performance roles

The delete scope is exactly:

- current authenticated `user_id`; and
- assignments whose joined `performance_roles.domain = 'dance'`.

The write must preserve unrelated role assignment rows and every other user's rows.

### 10.3 Primary role

Exactly one newly inserted Dance assignment has `is_primary = true`, and its ID equals `p_primary_role_id`.

Under the current global unique index, a preserved primary outside Dance causes a full rollback rather than an unrelated-row update.

### 10.4 Atomicity

Validation, `performance_domain` transition, genre replacement, role replacement, and result construction occur in one function invocation and one database transaction.

Any error rolls back:

- the user-field update;
- all genre deletes/inserts;
- all role deletes/inserts.

---

## 11. Security and RLS

### 11.1 Current RLS and direct permissions

#### `genres`

- RLS enabled.
- `genres_read_active`: SELECT active rows for `anon` and `authenticated` after Migration 004.
- `master_data_admin_manage_genres`: admin-managed ALL policy.
- Migration 034 confirms table SELECT for `anon` and `authenticated`.

#### `user_genres`

- RLS enabled.
- `user_genres_read`: self or safe public-profile visibility.
- `user_genres_write`: ALL for the current user's rows.
- Repository migrations contain no explicit user_genres table GRANT/REVOKE statement; the legacy Flutter direct path depends on the project's existing table privileges plus RLS.

#### `performance_roles`

- RLS enabled.
- active SELECT policy for `authenticated`;
- admin ALL policy;
- explicit table SELECT for `authenticated` only among app roles.

#### `user_performance_roles`

- RLS enabled.
- self SELECT policy only;
- explicit table SELECT for `authenticated`;
- no ordinary-client DML policy or DML grant.

#### `users`

- RLS enabled.
- full row is self-only except admin;
- self insert/update policies preserve existing system fields;
- existing protection trigger blocks client changes to system-managed fields.

### 11.2 Function security mode

Both proposed functions should be `SECURITY DEFINER`.

Justification:

- the write must mutate `user_performance_roles`, which intentionally has no client DML grant or policy;
- both functions need a stable aggregate contract independent of broad direct-table privileges;
- the write must update three related objects atomically;
- explicit `auth.uid()` and derived-user predicates provide the ownership boundary.

Because definer functions can bypass RLS, every table predicate must include the derived current user and approved Dance domain. No dynamic SQL is needed.

### 11.3 Function ACLs

For each new function:

1. revoke all from `PUBLIC`, `anon`, and `authenticated`;
2. grant EXECUTE to `authenticated` only;
3. do not explicitly grant or revoke `service_role`;
4. allow the function owner in ACL postconditions;
5. tolerate an existing `service_role` EXECUTE entry created by project default privileges;
6. reject arbitrary additional EXECUTE grantees;
7. explicitly reject PUBLIC EXECUTE using ACL expansion, not only `has_function_privilege` inheritance.

### 11.4 Client key boundary

Flutter continues to use only the configured publishable/anon key plus the authenticated user's JWT. No service-role secret, database password, or target-user identifier appears in Flutter.

### 11.5 Table grants and policies

Migration 035 introduces no table grant and no RLS policy. The `SECURITY DEFINER` contract is the only new write surface.

This preserves the legacy Band direct-table path, while the STAGE path uses only the new RPC.

---

## 12. Concurrency and transaction behavior

### 12.1 Runtime transaction scope

One PostgREST call executes the whole write function in one transaction.

### 12.2 User-scoped serialization

The write should lock the mapped current `users` row `FOR UPDATE` before reading current assignments. This provides a deterministic per-user serialization point for:

- simultaneous saves from two tabs;
- simultaneous saves from Web and a future iOS client;
- the existing `replace_my_performance_roles_v1`, which also locks the user row.

### 12.3 Master-row locks

After basic array validation:

1. lock selected genre rows in UUID order `FOR SHARE`;
2. lock selected role rows in UUID order `FOR SHARE`.

This prevents selected rows from being deactivated or changed between validation and insertion. A fixed table and UUID order reduces deadlock risk.

### 12.4 Assignment mutation

Domain-scoped delete and insert occur only after all inputs validate. Existing unique constraints remain the final duplicate guard.

### 12.5 Last-write-wins

Two conforming aggregate RPC calls for the same user serialize on the user row. The later lock holder commits its complete selection last, so the result is deterministic last-write-wins without a mixed genre/role state.

### 12.6 Legacy direct-writer limitation

The current legacy `ProfileService` does not acquire the user-row lock before replacing `user_genres`. A concurrent or later legacy save can therefore remove Dance genres. Migration 035 must document this limitation rather than adding broad table locks or silently rewriting legacy RLS.

### 12.7 Rollback behavior

Any exception from validation, lock timeout, FK/unique enforcement, user update, delete, insert, or result verification aborts the full RPC transaction.

---

## 13. Migration 035 preconditions

Migration SQL should fail before persistent changes if any required assumption is incompatible.

### 13.1 Required objects

- `public.users`
- `public.genres`
- `public.user_genres`
- `public.performance_roles`
- `public.user_performance_roles`
- `public.current_user_id()`
- `public.set_updated_at()`
- all four prior RPC signatures listed in sections 2.8 and 2.9

### 13.2 Required columns and types

Verify exact relevant columns, types, nullability, and defaults described in section 2 for all five tables.

In particular:

- `genres.domain/category` match Migration 032;
- `users.performance_domain/professional_state` match Migration 032;
- `user_performance_roles.is_primary` is non-null boolean default false.

### 13.3 Required constraints and indexes

Verify:

- all PK/FK/unique constraints on both assignment tables;
- `genres_domain_check` and `users_performance_domain_check` definitions;
- role domain and uniqueness constraints;
- `user_genres_genre_idx`;
- `user_performance_roles_role_user_idx`;
- the unique partial global-primary index and its exact predicate.

### 13.4 Required RLS state

RLS must be enabled on:

- `users`;
- `genres`;
- `user_genres`;
- `performance_roles`;
- `user_performance_roles`.

Expected policies and current table privilege boundaries must match repository history. Migration 035 must not silently repair drift.

### 13.5 Prior RPC contract checks

Confirm exact signatures, return types, language, volatility, security mode, fixed search path, and application-role EXECUTE grants for:

- `get_active_genres_v1(text)`;
- `get_active_performance_roles_v1(text)`;
- `get_my_performance_roles_v1()`;
- `replace_my_performance_roles_v1(text, uuid[], uuid)`.

### 13.6 Master-state checks

- the exact 11 approved Dance genres exist, are active, and retain Migration 034 metadata;
- the exact four Migration 033 Dance roles exist and are active;
- no selected-domain constraint has drifted;
- existing assignment rows satisfy FK/unique constraints.

Migration 035 should not require assignment tables to be empty and should not reject valid existing Band genre rows.

### 13.7 Function-name collision checks

Abort if any overload or partial prior application exists for:

- `get_my_stage_taxonomy_v1`;
- `replace_my_stage_taxonomy_v1`.

Do not use `CREATE OR REPLACE` to adapt unknown prior definitions in the first strict application.

### 13.8 Role checks

Require the `authenticated` and `anon` database roles for ACL verification. `service_role` is optional and only tolerated when present.

---

## 14. Migration 035 execution sequence

The future SQL file should follow this structure:

1. `begin`.
2. Set local `lock_timeout = '10s'`.
3. Set local `statement_timeout = '120s'`.
4. Run strict catalog/schema/RLS/RPC/ACL preflight before mutation.
5. Acquire relation locks in a deterministic order for the short migration window. `SHARE` mode on the five relevant tables is sufficient to keep data snapshots stable while creating functions; do not use `ACCESS EXCLUSIVE` without necessity.
6. Snapshot:
   - all `user_genres` rows;
   - all `user_performance_roles` rows;
   - relevant `users.id/performance_domain/updated_at` values;
   - existing function definitions and ACLs;
   - existing policies and table privileges;
   - table constraints, indexes, and non-internal triggers.
7. Create `get_my_stage_taxonomy_v1(text)` with the exact read contract.
8. Add a function comment documenting self-only aggregate read and Dance-only V1.
9. Create `replace_my_stage_taxonomy_v1(text, uuid[], uuid[], uuid)` with the exact atomic write contract.
10. Add a function comment documenting atomic self replacement and domain preservation.
11. Apply function-only revokes/grants.
12. Run exact postconditions from section 15.
13. Execute `notify pgrst, 'reload schema';`.
14. `commit`.

### 14.1 Pseudocode boundaries

The actual SQL should use static SQL only. No dynamic table or column name is required. Catalog inspection in pre/postconditions may query `pg_catalog`, but runtime RPC logic should not construct dynamic SQL.

### 14.2 Migration data behavior

Creating Migration 035 must not invoke either new function and must not repair, backfill, delete, or insert assignment rows. Data changes occur only later when an authenticated user explicitly calls the write RPC.

---

## 15. Migration 035 postconditions

Postconditions should abort the same migration transaction unless every assertion passes.

### 15.1 New function identity and contract

For each function verify:

- exactly one intended overload exists;
- exact input argument types and order;
- exact output field names, types, and order;
- `LANGUAGE plpgsql`;
- read is `STABLE`;
- write is `VOLATILE`;
- both are `SECURITY DEFINER`;
- `proconfig` includes exact `search_path=public, pg_temp`;
- comments are present.

### 15.2 Function ACLs

Verify separately:

- `authenticated` has EXECUTE;
- `anon` does not have EXECUTE;
- PUBLIC ACL grantee `0` has no EXECUTE;
- owner is allowed;
- `service_role` is tolerated if already present but not required;
- no other role has EXECUTE.

The unexpected-grantee test must use a null-safe `NOT EXISTS`/explicit owner-and-role-name check, not `NOT IN` with nullable role names.

### 15.3 Existing functions unchanged

Compare pre/post definitions and ACLs for every existing public function, with only the two new OIDs excluded. In particular, all Migration 033/034 RPCs must be byte-equivalent by normalized catalog representation.

### 15.4 Policies and table privileges unchanged

Verify that:

- no RLS policy definition changed;
- RLS remains enabled;
- no INSERT/UPDATE/DELETE or broader table privilege was added;
- existing direct-table compatibility remains exactly as before.

### 15.5 Schema objects unchanged

Verify pre/post equality for relevant:

- table column metadata;
- constraints;
- indexes;
- triggers;
- views.

### 15.6 Data unchanged during migration

Snapshot equality must prove:

- no Band or Dance `user_genres` row changed;
- no `user_performance_roles` row changed;
- no `users` row or `performance_domain` changed;
- no master row changed;
- no assignment ID/timestamp changed.

### 15.7 Schema reload

The migration source must contain `notify pgrst, 'reload schema';` immediately before commit after successful postconditions.

---

## 16. Runtime verification matrix

These tests are for the future implemented Migration 035. Use disposable test users/rows and authenticated client JWTs; never place a service-role key in Flutter.

| ID | Actor/input | Expected result | DB assertions |
|---|---|---|---|
| A1 | anon calls read | fail `28000` | no data change |
| A2 | anon calls write | fail `28000` | no data change |
| B1 | authenticated user with no Dance assignments calls read | one row, `has_saved_taxonomy=false`, empty arrays, null primary | existing Band rows unchanged |
| B2 | valid 2+ Dance genres, 2+ Dance roles, one selected primary | one row, `has_saved_taxonomy=true` | exact requested Dance rows, exactly one primary |
| B3 | reload after B2 | same deterministic IDs/order | persisted values match response |
| B4 | new app session reload | same as B3 | no dependency on local cache |
| C1 | replace some Dance genre IDs | removed Dance rows absent; new rows present | Band rows byte-equivalent |
| C2 | replace some Dance role IDs and primary | removed Dance roles absent; new primary exact | unrelated-domain rows preserved |
| D1 | null domain | `22023` | no change |
| D2 | unsupported/case-variant domain | `22023` | no change |
| D3 | null genre array | `22004` | no change |
| D4 | empty genre array | `22023` | no change |
| D5 | genre array contains null | `22023` | no change |
| D6 | duplicate genre IDs | `22023` | no change |
| D7 | nonexistent/inactive genre | `22023` | no change |
| D8 | Band genre supplied to Dance save | `22023` | Band and Dance unchanged |
| D9 | null role array | `22004` | no change |
| D10 | empty role array | `22023` | no change |
| D11 | role array contains null | `22023` | no change |
| D12 | duplicate role IDs | `22023` | no change |
| D13 | nonexistent/inactive role | `22023` | no change |
| D14 | future Band role supplied to Dance save | `22023` | no change |
| D15 | null primary | `22004` | no change |
| D16 | primary not in selected roles | `22023` | no change |
| E1 | valid genres plus invalid roles | full failure | neither genre nor role state changes |
| E2 | invalid genres plus valid roles | full failure | neither genre nor role state changes |
| F1 | user A reads | only A aggregate | no B data returned |
| F2 | user A writes | only A rows updated | B snapshots unchanged |
| F3 | caller attempts user-ID parameter | no such contract | impossible through RPC signature |
| G1 | repeat identical valid request | same success response | no duplicates; ideally IDs/timestamps stable |
| H1 | legacy Band profile before/after Dance save | Band assignments identical | Dance rows added separately |
| H2 | legacy master selector | Band genres only | `domain=band` filter retained |
| H3 | existing master RPCs | same signatures/results | no contract change |
| I1 | two concurrent valid saves for same user | serialized last-write-wins | final state equals one complete request, never mixed |
| I2 | injected lock/statement failure | RPC failure | transaction rollback complete |
| J1 | stored genres only, roles absent, then read | fail `55000` | no automatic cleanup |
| J2 | stored roles with missing primary, then read | fail `55000` | no silent primary default |

### 16.1 Exact DB comparison sets

Before each mutation test, snapshot at minimum:

- current user Band `user_genres` ordered by `id`;
- current user Dance `user_genres` ordered by master sort/code;
- current user Dance `user_performance_roles` including `id/is_primary/timestamps`;
- another user's equivalent rows;
- current user's `performance_domain`.

After failure cases, all snapshots must be identical.

---

## 17. Rollback strategy

Rollback is forward-only. Never edit Migration 035 after it has been applied.

A later rollback migration should:

1. revoke EXECUTE on the two new exact signatures from application roles;
2. drop only:
   - `get_my_stage_taxonomy_v1(text)`;
   - `replace_my_stage_taxonomy_v1(text, uuid[], uuid[], uuid)`;
3. leave all `users`, `user_genres`, and `user_performance_roles` rows intact;
4. leave Migration 033 and 034 RPCs intact;
5. leave RLS/table grants unchanged;
6. notify PostgREST schema reload;
7. revert Flutter to the preceding read-only/local-draft behavior.

Rollback must not delete user selections. If data remediation is ever needed, it requires a separately approved migration and user-impact plan.

---

## 18. Flutter follow-up task

The first Flutter task after Migration 035 is applied should be limited to a tested persistence layer.

### 18.1 Add typed persistence contracts

- `StageProfileTaxonomyPersistenceResult`
  - `domain`
  - `hasSavedTaxonomy`
  - immutable ordered genre IDs
  - immutable ordered role IDs
  - nullable primary role ID when not saved
- explicit parser validation for the exact one-row RPC response.

### 18.2 Add typed service methods

Suggested methods:

- `fetchMyStageTaxonomy(PerformanceDomain.dance)`;
- `replaceMyStageTaxonomy(StageProfileTaxonomyDraft draft, PerformanceDomain.dance)`.

The service should call only the two new RPCs, map SQLSTATEs into explicit authentication/input/profile/inconsistent-state/RPC exceptions, and log PostgREST details only in debug output.

### 18.3 Automated tests

Cover:

- exact function names and parameter maps;
- saved and not-saved parsing;
- deterministic immutable arrays;
- malformed top-level/row/field responses;
- null primary only when not saved;
- authentication and SQLSTATE mapping;
- write success and failure separation;
- no direct table writes and no service-role token.

### 18.4 UI boundary

Only after service/model tests pass should a later narrow UI task:

- load existing selections into `StageProfileTaxonomySelection`;
- save the current `StageProfileTaxonomyDraft`;
- show Japanese loading/saving/error states.

Do not combine full profile redesign with the persistence-service task.

---

## 19. Open risks and decisions

### 19.1 Decision required: approve exact aggregate contracts

Approve the two signatures and shared five-field return shape in sections 7 and 8. Changing field names after Web/iOS clients ship requires V2 rather than in-place replacement.

### 19.2 Decision required: `performance_domain` transition

Recommended transition is null/dance → dance and band/multi_domain → multi_domain. This preserves an explicitly selected Band domain while recording an explicit Dance save.

If product instead defines `performance_domain` as one primary domain, Migration 035 should set `dance` unconditionally. That alternative must be approved before SQL; it should not be inferred by the implementer.

### 19.3 Decision required: incomplete stored state

Recommendation is a `55000` failure, not silent repair. This keeps corrupted/legacy partial state visible and allows a deliberate repair flow later.

### 19.4 Legacy profile overwrite risk

The existing Flutter `ProfileService` deletes all current-user `user_genres` rows. After STAGE save is enabled, a legacy profile edit can remove Dance genres.

Recommended rollout gate:

- before broad production use, add a separate tested Flutter compatibility change that replaces only Band assignments or moves legacy genre save to a domain-safe server RPC;
- do not remove the current RLS policy in Migration 035;
- do not silently alter legacy behavior in this database migration.

### 19.5 Legacy safe-projection labeling

Existing safe projections aggregate all active assigned genres. Dance names may appear in fields currently labeled as music genres.

Recommendation: later introduce explicitly domain-aware/versioned profile projections rather than changing existing return contracts in place.

### 19.6 Global primary-role limitation

The current schema supports one primary role per user globally. Migration 035 can safely support the current Dance-only master, but future Band roles require a product/schema decision before multi-domain role persistence.

Migration 035 should reject an existing unrelated primary rather than demote or delete it.

### 19.7 Migration-numbering documentation conflict

Earlier STAGE analysis documents describe “Migration 035” as a future professional-verification migration. This task explicitly assigns Migration 035 to taxonomy persistence.

Recommendation: treat this new approved sequence as authoritative for implementation, and update the roadmap/older forward references in a separate docs-only task. Do not edit historical migrations or unrelated analysis documents as part of this spec task.

### 19.8 Effective table ACLs for legacy joins

The repository defines RLS policies for `user_genres` but does not explicitly grant/revoke its table privileges. Current Flutter direct access implies the project baseline permits the operations under RLS.

Migration 035 should inspect but not normalize those ACLs. The new definer RPC must not depend on broadening them.

---

## 20. Final implementation checklist

### Approval before coding

- [ ] Approve Option B: one atomic write plus one aggregate read.
- [ ] Approve exact function names, parameters, and return fields.
- [ ] Approve Dance-only explicit domain parameter for V1.
- [ ] Approve `performance_domain` transition rules.
- [ ] Approve incomplete-state `55000` behavior.
- [ ] Accept the current global-primary limitation for Dance-only V1.
- [ ] Accept that legacy-profile overwrite mitigation is a separate Flutter/server compatibility task.

### Migration 035 implementation

- [ ] Create only `035_stage_taxonomy_persistence.sql` after approval.
- [ ] Do not modify migrations 001–034.
- [ ] Use one transaction with local lock/statement timeouts.
- [ ] Add strict preflight for tables, columns, constraints, indexes, RLS, grants, roles, and prior RPCs.
- [ ] Snapshot all relevant existing data/contracts.
- [ ] Create `get_my_stage_taxonomy_v1(text)` exactly.
- [ ] Create `replace_my_stage_taxonomy_v1(text, uuid[], uuid[], uuid)` exactly.
- [ ] Use `SECURITY DEFINER` and fixed `search_path = public, pg_temp`.
- [ ] Derive the user from `auth.uid()`; accept no user ID.
- [ ] Validate null, empty, duplicate, missing, inactive, mixed-domain, and primary inputs explicitly.
- [ ] Lock user and master rows in deterministic order.
- [ ] Delete/insert only current-user Dance assignments.
- [ ] Preserve Band and unrelated-domain rows.
- [ ] Return one deterministic aggregate row.
- [ ] Revoke PUBLIC/anon EXECUTE; grant authenticated only.
- [ ] Tolerate but do not grant/revoke existing service_role ACL.
- [ ] Add function comments.
- [ ] Assert no existing data/schema/policy/grant/function changed.
- [ ] Include `notify pgrst, 'reload schema';`.
- [ ] Commit only after every postcondition passes.

### Runtime verification

- [ ] Run every case in section 16 with disposable users.
- [ ] Prove atomic rollback with mixed valid/invalid inputs.
- [ ] Prove Band assignment preservation.
- [ ] Prove cross-user isolation.
- [ ] Prove repeated-request idempotency.
- [ ] Prove legacy master selector remains Band-only.

### Flutter follow-up

- [ ] Add typed result/error models.
- [ ] Add typed read/write service methods.
- [ ] Add parser/RPC/error/boundary tests.
- [ ] Keep service-role secrets out of Flutter.
- [ ] Connect the existing UI only after service tests pass.
- [ ] Schedule the legacy Band genre replacement compatibility fix before broad rollout.

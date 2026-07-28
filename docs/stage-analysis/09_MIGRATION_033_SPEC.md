# Migration 033 상세 사양: STAGE Performance Role Foundation

작성 기준:

- branch: `stage-redesign`
- repository HEAD: `d7d551a001e3987738e0b4a9d1e61e5b20878165`
- repository migration baseline: `001`–`032`
- 직전 migration: `032_stage_taxonomy_and_user_profile.sql`
- 문서 성격: 분석 및 DB 설계 사양
- 이 문서는 실행 가능한 SQL을 포함하지 않는다.

> 결론: 임시 파일명 `033_stage_taxonomy_activation_and_performance_roles.sql`은 사용하지 않는다. 역할 기반과 장르 활성화는 실패 범위, Flutter 선행 배포 조건, rollback 단위가 다르다. 다음 DB 작업은 `033_stage_performance_roles.sql`로 역할 기반만 추가하고, 댄스 장르 활성화는 legacy Flutter의 `domain = band` 필터가 배포·검증된 뒤 별도 `034_stage_domain_genre_access_and_activation.sql`에서 수행한다.

---

## 1. Executive recommendation

### 1.1 권장 결론

1. **Performance role은 프로젝트에서 사용자가 수행할 수 있거나 수행하려는 기능적 역할**이다.
2. Crew 권한을 결정하는 governance role, 장르, 경험 수준, professional verification과 분리한다.
3. 기존 `parts`와 관련 join은 BandMatch legacy 계약으로 그대로 보존한다.
4. 신규 `performance_roles`와 `user_performance_roles`를 별도로 만든다.
5. 033의 초기 dance role은 정확히 4개를 권장한다.
   - ダンサー
   - 振付師
   - インストラクター
   - その他
6. 사용자는 여러 role을 선택할 수 있고 그중 하나를 primary로 지정한다.
7. role별 경험 수준이나 role별 공개 여부는 MVP에서 만들지 않는다.
8. Crew 자체의 supported-role join은 MVP에서 만들지 않는다. 역할 수요는 후속 recruitment slot에서 표현한다.
9. Migration 032의 dance genre 11개는 033에서 활성화하지 않는다.
10. legacy Flutter가 명시적으로 `domain = band`를 조회하도록 먼저 배포한 뒤, 후속 migration에서 versioned domain genre RPC와 dance genre 활성화를 함께 적용한다.

### 1.2 권장 migration 경계

| 순서 | 산출물 | 범위 |
|---:|---|---|
| 1 | `033_stage_performance_roles.sql` | role master, user-role join, self read/write RPC, RLS/grants. Dance genre 상태 변경 없음 |
| 2 | legacy compatibility Flutter release | 기존 master query에 `genres.domain = band` 추가. STAGE feature는 계속 비활성 |
| 3 | `034_stage_domain_genre_access_and_activation.sql` | versioned domain genre RPC 추가, 정확히 11개 approved dance seed만 active 전환 |
| 4 | STAGE Flutter release/feature enable | dance genre 및 performance role UI 사용 |
| 5 | 별도 recruitment integration migration | role slot 및 application-selected role. 번호는 앞 단계 확정 후 배정 |

### 1.3 이 분리의 이유

- 현재 Flutter는 `genres.is_active = true`만 필터하고 domain을 필터하지 않는다.
- Migration 032의 dance genre를 바로 active로 바꾸면 기존 BandMatch onboarding, profile edit, group edit, recruitment edit에 dance genre가 노출된다.
- `parts`를 변경하면 profile, group, recruitment, search의 기존 UUID 배열 계약이 동시에 영향을 받는다.
- 역할 데이터 기반은 기존 앱에서 참조하지 않는 additive object이므로 먼저 적용해도 legacy 동작에 영향이 없다.
- genre activation은 즉시 사용자 화면에 영향을 주는 operation이므로 Flutter compatibility release 이후의 독립 rollback 단위여야 한다.

---

## 2. Current-schema findings

### 2.1 Migration baseline

Repository에는 `001`부터 `032`까지의 번호 migration이 존재한다. 032는 다음을 구현했다.

- `genres.domain`: `band` 또는 `dance`, 기존 row default/classification은 `band`
- `genres.category`: 승인된 taxonomy category, 기존 row는 `legacy_music`
- `users.performance_domain`: nullable `band`, `dance`, `multi_domain`
- `users.professional_state`: `general`, `professional_unverified`
- stable code를 가진 11개 dance genre
- 11개 dance genre 모두 `is_active = false`
- 기존 genre identity, `user_genres`, users의 자동 분류, 기존 public view/function을 변경하지 않는 검증

032는 role table, role join, role RPC, genre activation, professional verification을 만들지 않았다.

### 2.2 현재 `parts` 관계

`parts`는 `001_initial_schema.sql`에서 만들어진 BandMatch instrument/part master이다. `002_seed_master_data.sql`은 다음 12개 active row를 가진다.

`vocal`, `guitar`, `bass`, `piano_keyboard`, `drums`, `percussion`, `wind_instruments`, `string_instruments`, `songwriter_arranger`, `dj`, `dancer`, `other`

`dancer`가 이미 존재하지만, 이 row는 BandMatch의 기존 part master 안에 있고 아래 legacy 관계에 사용된다.

- `user_parts`
- `user_target_parts`
- `user_recruiting_parts`
- `group_target_parts`
- `group_recruiting_parts`
- `group_members.part_id`
- `invitations.target_part_id`
- `recruitment_post_parts`

각 join은 UUID FK와 unique pair를 사용한다. 따라서 `parts.dancer`를 STAGE의 일반 performance-role master로 간주하면 다른 instrument part와 동일한 의미·권한·UI 계약에 갇힌다.

### 2.3 Governance와 membership

현재 `group_members.role`은 `admin` 또는 `member`이며 권한을 결정한다. Migration 028 이후 membership lifecycle은 다음과 분리되어 있다.

- `membership_status`: `active`, `left`, `removed`
- `left_at`
- `removed_by`

`public.is_group_admin(group_id)`는 현재 사용자에게 active `admin` membership이 있는지를 확인한다. STAGE UI의 “crew leader”는 별도 performance role이 아니라 이 governance 계약의 UI 표현으로 유지하는 것이 안전하다.

### 2.4 현재 recruitment 모델

현재 구조:

- `recruitment_posts`
- `recruitment_post_parts`
- `recruitment_post_genres`
- `recruitment_post_areas`
- `recruitment_applications`

현재 application은 post-level 신청이며 선택 role을 저장하지 않는다. 수락 RPC는 applicant를 `group_members`에 `member`로 추가 또는 재활성화한다. Migration 028 이후 동일 post/user의 **pending application만** 중복 제한하고, 거절 또는 종료된 과거 신청은 history로 남긴다.

현재 public recruitment projection은 안전한 다음 값만 반환한다.

- post/group 식별자
- group name
- title/body
- timestamps
- wanted part names
- genre names
- area names

### 2.5 현재 RLS 및 safe access pattern

- `parts`, `genres`, `areas`: active row read, admin manage
- Migration 004 이후 master active read는 `anon`, `authenticated`에 허용
- `users`: private table이며 self/admin 외 직접 조회 제한
- public member UI: `member_search_profiles`, `member_public_profile_details`, `search_member_profiles`
- user join writes: 자기 user ID에 한정
- group/recruitment mutations: active group admin 또는 operator에 한정
- application read: applicant 본인, 해당 group admin, operator
- block 관계: member search, message request, recruitment application의 안전 조건에 사용
- `SECURITY DEFINER` RPC는 현재 `current_user_id()`, group admin check 및 제한된 projection 패턴을 사용

### 2.6 현재 Flutter 계약

`MasterDataService.fetchActiveMasterData()`는:

- `parts`: `is_active = true`
- `genres`: `is_active = true`
- `areas`: `is_active = true`

를 직접 조회한다. **genre domain filter가 없다.**

현재 Flutter 모델/서비스는 다음 legacy 계약을 사용한다.

| 기능 | 현재 계약 |
|---|---|
| profile setup/edit | `partIds`, `genreIds`, `areaIds`, generic `experienceLevel` |
| member search | `p_part_ids`, `p_genre_ids`, `p_area_ids`, experience/purpose |
| group create/edit | `p_genre_ids`, `p_recruiting_part_ids`, `p_area_ids` |
| recruitment create/edit | `p_wanted_part_ids`, `p_genre_ids`, `p_area_ids` |
| recruitment application | post ID와 message만 전송 |
| public member/group/recruitment UI | part/genre/area 이름 배열 parsing |

`MasterDataItem`에는 현재 `domain`과 `category` 필드가 없다. 이 자체는 032와 호환되지만 dance activation 전 legacy genre filter가 반드시 추가되어야 한다.

### 2.7 제품 문서와 prototype 근거

- STAGE 문서는 기존 `parts`를 dance role로 덮어쓰지 말 것을 명시한다.
- `groups`는 기술명으로 유지하고 UI에서 クルー로 표현한다.
- prototype의 recruitment card는 genre, area, level, remaining count 중심이며 `center`, `main dancer`, `sub dancer`를 필수 구조화 필드로 요구하지 않는다.
- prototype의 leader/member 표시는 governance 의미이다.
- professional instructor/operator verified 표시는 일반 role 선택과 별도의 신뢰 경계로 표현된다.

따라서 role foundation은 작고 명확해야 하며, prototype에 근거가 없는 position taxonomy를 미리 확장하지 않는다.

---

## 3. Definition of governance role vs performance role vs genre

### 3.1 Crew governance role

목적:

- Crew 내부 권한 및 mutation 가능 여부를 결정
- member 초대/제거, recruitment 관리, crew edit 등의 authorization 기준

현재 구현:

- `group_members.role = admin | member`
- active membership 여부는 `membership_status`, `left_at`으로 판단

권장:

- 033에서 변경하지 않는다.
- UI에서 owner/leader를 표시하더라도 DB 권한은 기존 active admin을 기준으로 한다.
- 향후 owner 이전이 필요하면 governance 전용 migration으로 다룬다.

### 3.2 Performance role

정의:

> 사용자가 dance performance/project에 기여할 수 있거나 기여하려는 기능적 역할.

예:

- 춤을 수행
- 안무를 제작
- instruction을 제공

Performance role은 다음을 의미하지 않는다.

- Crew 관리 권한
- 경험 수준
- 프로젝트 내 일회성 position
- professional 검증
- genre 선호

Role 선택은 self-declared capability/intent이다. Role만으로 crew admin 권한, verified badge, 수업 개설 권한을 부여하지 않는다.

### 3.3 Recruitment slot/requested role

정의:

> 특정 recruitment post가 현재 찾는 기능적 역할과 해당 수요 조건.

같은 performance-role master를 참조하지만 user-role과 lifecycle이 다르다.

- user role: 비교적 지속적인 자기 프로필
- recruitment slot: 특정 post에 한정된 수요
- application selected role: applicant가 그 post의 어떤 slot에 지원했는지

### 3.4 Genre

Genre는 춤의 스타일/장르이며 role이 아니다.

- K-POP
- HIPHOP
- WAACK

`dancer + WAACK`은 role과 genre의 조합이다. 두 값을 한 master에 넣지 않는다.

### 3.5 Professional verification

`users.professional_state`는 신뢰/검증 상태이다.

- `general`
- `professional_unverified`
- 미래 operator-verified 상태는 별도 migration

`dance_instructor` role 선택은 “instruction 역할을 한다”는 self declaration일 뿐이다. verified instructor badge 또는 lesson publish 권한을 의미하지 않는다.

---

## 4. Existing `parts` impact analysis

### 4.1 Object별 권장 처리

| 기존 object | 현재 의미 | 권장 처리 | STAGE 전환 시점 |
|---|---|---|---|
| `parts` | Band instrument/part master | 변경 없이 legacy 유지 | 삭제/rename 금지 |
| `user_parts` | 사용자의 Band part | legacy 유지 | 새 role로 자동 mapping 금지 |
| `user_target_parts` | 사용자가 찾는 Band part | legacy 유지 | STAGE role preference가 필요하면 별도 설계 |
| `user_recruiting_parts` | 사용자의 Band 모집 part | legacy 유지 | STAGE에서는 recruitment slot 사용 |
| `group_target_parts` | group의 Band target part | legacy 유지 | cutover 뒤 별도 cleanup 검토 |
| `group_recruiting_parts` | group의 Band 모집 part | legacy 유지 | STAGE에서는 post role slot 사용 |
| `group_members.part_id` | crew member의 legacy Band part | nullable legacy 유지 | performance role FK로 재해석 금지 |
| `recruitment_post_parts` | Band 모집 part | legacy post에서 계속 사용 | STAGE post v2는 role slot 사용 |
| `invitations.target_part_id` | Band invitation target | legacy 유지 | STAGE invitation 결정 후 별도 확장 |
| member search part filter | Band part UUID filter | 기존 RPC/signature 유지 | STAGE search v2에서 role filter 별도 추가 |

“deprecated later”는 table/row 삭제를 의미하지 않는다. 새 Flutter/RPC가 완전히 전환되고 legacy read path가 종료된 뒤에도 history 보존과 rollback 필요성을 검토해야 한다.

### 4.2 Option A: separate `performance_roles`

장점:

- legacy data와 stable UUID 의미를 보존
- governance/genre/role 이름이 명확
- recruitment role filter가 명시적
- 새 RLS/RPC를 독립 설계 가능
- migration rollback과 feature disable이 단순
- 미래 band role을 추가하더라도 기존 `parts`를 강제 변환하지 않음

단점:

- Flutter에 role model/service가 하나 추가됨
- legacy part UI와 STAGE role UI를 병행하는 compatibility 기간이 필요

평가: **권장**

### 4.3 Option B: add domain to `parts`

장점:

- 기존 master UI 일부 재사용 가능
- 신규 master table 수가 적음

위험:

- `parts.dancer`의 현재 legacy identity와 새 dance-role 의미가 충돌
- 모든 part query에 domain filter가 필요
- `group_members.part_id`, invitation, recruitment joins의 의미가 혼합
- 기존 public projections와 Flutter model 이름이 계속 “part”
- future band와 dance에서 같은 이름의 기능 역할 처리도 모호
- 잘못 활성화하면 legacy UI에 dance role이 즉시 유출

평가: **미권장**

### 4.4 Option C: generalized capability taxonomy

장점:

- 장기적으로 instrument, role, skill, service를 하나의 taxonomy로 표현 가능

위험:

- 기존 `parts` 및 모든 FK를 새 taxonomy로 옮기는 대규모 migration 필요
- capability type, domain, applicability, visibility를 동시에 설계해야 함
- MVP 요구보다 훨씬 큰 Flutter/RLS/filter 변경
- 불완전한 backfill이 semantic corruption을 만들 수 있음
- rollback이 가장 어려움

평가: **MVP에서 미권장**, 실제 cross-domain capability 검색 요구가 확인된 뒤 별도 architecture task로 검토

### 4.5 최종 권장

Option A를 채택한다. `parts`와 `performance_roles` 사이에 자동 mapping, alias, shared FK를 만들지 않는다. 두 master가 동일한 Japanese label `ダンサー`를 가질 수 있어도 stable code와 table identity가 다르므로 서로 다른 제품 의미로 취급한다.

---

## 5. Proposed MVP role taxonomy

### 5.1 권장 seed

Category column은 MVP에 필요하지 않다. 네 role 모두 `domain = dance`이며 flat list로 충분하다.

| Stable code | 日本語表示名 | English explanation | 한국어 설명 | sort | user select | recruitment request | 권한 영향 | 단계 |
|---|---|---|---|---:|---:|---:|---:|---|
| `dance_dancer` | ダンサー | Performs dance in a project or crew. | 프로젝트/크루에서 춤을 수행하는 역할 | 101 | 예 | 예 | 없음 | MVP |
| `dance_choreographer` | 振付師 | Creates or adapts choreography. | 안무를 창작·구성·수정하는 역할 | 102 | 예 | 예 | 없음 | MVP |
| `dance_instructor` | インストラクター | Provides dance instruction; does not imply verification. | 댄스 지도를 제공하는 역할. 인증을 의미하지 않음 | 103 | 예 | 예 | 없음 | MVP |
| `dance_other` | その他 | A dance-project function not covered by the approved list. | 승인 목록에 없는 기타 댄스 프로젝트 역할 | 199 | 예 | 예 | 없음 | MVP fallback |

Stable code에 `dance_` prefix를 사용하는 이유:

- future band role과 code 충돌 방지
- API log/analytics에서 domain이 명확
- `parts.dancer`와 혼동 방지
- Migration 032의 `dance_*` genre seed naming과 운영 convention 일치

Japanese display name은 수정 가능하지만 stable code는 변경하지 않는다.

### 5.2 검토했지만 MVP에서 제외하는 역할

| 개념 | 분류 | MVP 제외 이유/향후 처리 |
|---|---|---|
| dance leader | governance 또는 project assignment | “crew leader”와 “creative lead”가 모호하다. Crew 권한은 `admin`; creative lead가 필요하면 project/event assignment로 분리 |
| backup/support dancer | recruitment condition 또는 future assignment | 지속적인 user identity보다 특정 무대/slot의 관계에 가깝다. Post 조건/free text로 우선 처리 |
| organizer | governance/event organizer | 무대 performance 기능이 아니라 event/crew 운영 책임. event source/organizer domain에서 설계 |
| center | project-specific position | prototype 근거가 부족하고 작품마다 바뀐다. free-text 조건 또는 future casting assignment |
| main dancer | project-specific position | global profile role로 고정하지 않음 |
| sub dancer | project-specific position | global profile role로 고정하지 않음 |
| crew leader | governance role | active `group_members.role = admin`으로 처리 |

### 5.3 경험 관련 개념

| 개념 | 저장 위치 |
|---|---|
| beginner / experienced | 기존 `users.experience_level` |
| role별 연차 | MVP 미구현 |
| “経験1年〜” 등 recruitment 조건 | 우선 post/slot condition text; 구조화 필요가 검증되면 후속 column |
| `pro_oriented` | 기존 experience orientation. professional verification과 무관 |

---

## 6. User-role data model

### 6.1 MVP 선택 규칙

- 기존 사용자는 0개 role이어도 유효하다.
- STAGE onboarding에서 사용자가 명시적으로 저장할 때는 1개 이상을 요구한다.
- 사용자는 여러 role을 선택할 수 있다.
- 선택된 role 중 정확히 하나를 primary로 지정한다.
- role별 experience level은 만들지 않는다.
- role별 visibility toggle은 만들지 않는다.
- active role은 향후 safe public profile v2에서 공개하며 primary 여부도 공개 가능하다.
- role 선택은 permissions 또는 verification에 영향을 주지 않는다.

DB에 hard maximum은 두지 않는 것을 권장한다. 초기 active role이 4개뿐이므로 unique constraint로 충분하고, 임의의 “최대 3개” 규칙을 stable DB contract로 만들 근거가 부족하다. Flutter는 primary 선택을 강조하고 과도한 선택을 UX로 안내할 수 있다.

### 6.2 `performance_roles`

목적:

- domain별 performance-role master
- stable code와 display label 제공
- inactive 처리로 신규 선택 중단

권장 column:

| Column | Type/constraint | 설명 |
|---|---|---|
| `id` | UUID PK, generated | FK identity |
| `code` | text, not null, globally unique | immutable stable code |
| `name` | text, not null | Japanese display name |
| `domain` | text, not null, check `band/dance` | role 적용 domain |
| `sort_order` | smallint, not null | domain 내 표시 순서 |
| `is_active` | boolean, not null, default true | 신규 선택/표시 가능 여부 |
| `created_at` | timestamptz, not null | audit |
| `updated_at` | timestamptz, not null | audit |

권장 constraints:

- unique `code`
- unique `(domain, name)`
- unique `(domain, sort_order)`
- domain check
- name length 1–60

`user_selectable`, `recruitment_selectable`, category는 초기 4개 role에서 값이 모두 같으므로 만들지 않는다. 실제로 applicability가 갈라지는 시점에 additive column을 검토한다.

### 6.3 `user_performance_roles`

목적:

- 사용자가 명시적으로 선택한 performance role
- primary role 표시

권장 column:

| Column | Type/constraint | 설명 |
|---|---|---|
| `id` | UUID PK, generated | row identity |
| `user_id` | UUID FK `users`, cascade | owner |
| `performance_role_id` | UUID FK `performance_roles`, restrict | selected role |
| `is_primary` | boolean, not null, default false | primary role |
| `created_at` | timestamptz, not null | audit |
| `updated_at` | timestamptz, not null | audit |

권장 constraints/indexes:

- unique `(user_id, performance_role_id)`
- partial unique `(user_id) where is_primary`
- index `(performance_role_id, user_id)` for future role filter
- index `(user_id, is_primary desc)`는 row 수가 작으므로 필수 아님

### 6.4 Lifecycle

- join row에는 soft-delete/status를 만들지 않는다.
- 사용자 선택 해제는 join row delete로 처리한다.
- role master row는 delete하지 않고 `is_active = false`로 retire한다.
- inactive role은 신규 선택할 수 없다.
- 기존 assignment는 audit/compatibility를 위해 남긴다.
- role edit RPC는 inactive 기존 assignment를 조용히 다른 role로 변환하지 않는다.

### 6.5 `users.performance_domain`과의 관계

Future self-save RPC는 사용자가 명시적으로 선택한 domain과 role을 같은 transaction에서 검증해야 한다.

- `dance`: 모든 selected role의 domain이 dance
- `band`: future band role master가 생기기 전에는 STAGE role save 대상 아님
- `multi_domain`: 선택 role이 존재하는 각 domain을 허용하되 future band role 출시 후 활성

기존 null 값을 자동 설정하지 않는다. 명시적인 STAGE onboarding/profile save만 `users.performance_domain`을 변경한다.

---

## 7. Crew/recruitment/application role model

### 7.1 Crew-supported roles

MVP에서는 `group_performance_roles`를 만들지 않는 것을 권장한다.

이유:

- Crew의 장기 identity는 `group_genres`, profile/bio, active members로 이미 일부 표현된다.
- active member role에서 crew role을 자동 derive하면 membership 변화에 따라 crew identity가 흔들린다.
- recruitment 수요는 post 단위 role slot으로 충분하다.
- prototype은 crew 자체의 supported role editor를 필수 흐름으로 보여주지 않는다.

향후 실제 crew capability 필터가 필요하면 별도 `group_performance_roles(group_id, performance_role_id)`를 만들고 active admin만 변경하도록 한다. member role에서 자동 backfill하지 않는다.

### 7.2 Recruitment requested role

후속 recruitment integration migration에서 `recruitment_role_slots`를 권장한다.

권장 column:

| Column | Type/constraint | MVP 의미 |
|---|---|---|
| `id` | UUID PK | application target |
| `recruitment_post_id` | UUID FK, cascade | owning post |
| `performance_role_id` | UUID FK, restrict | requested role |
| `requested_count` | smallint nullable, positive check | optional capacity; null은 미정/비공개 |
| `beginner_friendly` | boolean, default false | filterable minimum condition |
| `conditions` | text nullable, max 300 | role별 자유 조건 |
| `sort_order` | smallint, default 0 | card/form order |
| timestamps | timestamptz | audit |

권장 constraints/indexes:

- unique `(recruitment_post_id, performance_role_id)`
- check `requested_count is null or requested_count between 1 and 99`
- index `(performance_role_id, recruitment_post_id)`
- index `(recruitment_post_id, sort_order)`

MVP에서 저장하지 않을 값:

- `accepted_count`: accepted application에서 계산
- 정교한 minimum experience ordinal: 현재 experience code의 순서 정책이 확정되지 않음
- slot별 status: post status로 시작
- center/main/sub: conditions 또는 future assignment

Capacity는 column부터 nullable로 추가하고, acceptance hard enforcement는 새 application path가 role slot을 항상 저장한 이후에 활성화한다.

### 7.3 Application-selected role

후속 migration에서 `recruitment_applications.recruitment_role_slot_id` nullable FK를 추가하는 것을 권장한다.

- 신규 STAGE application은 정확히 한 requested slot을 선택한다.
- post에 slot이 하나면 UI가 자동 선택할 수 있다.
- 여러 role 동시 지원은 MVP에서 지원하지 않는다.
- existing application은 null로 유지한다.
- FK는 `on delete restrict`를 권장해 application history가 깨지지 않게 한다.
- v2 apply RPC는 slot이 해당 post에 속하고 active role을 참조하는지 확인한다.
- v2 accept RPC는 application, slot, capacity 관련 row를 lock한 뒤 판단한다.
- 기존 post-level apply RPC는 compatibility 기간 동안 유지한다.

### 7.4 Governance와 mutation

- recruitment post/slot 작성·수정: active group admin 또는 operator
- application 생성: active user 본인
- accept/reject: active group admin
- accept 결과 membership role: 기존과 같이 `member`
- selected performance role은 governance role을 바꾸지 않는다.
- applicant가 instructor를 선택해도 admin, operator, verified professional이 되지 않는다.

### 7.5 Block와 account state

새 v2 RPC도 현재 보호를 보존해야 한다.

- 양방향 block 관계가 있으면 apply/accept 불가
- suspended/withdrawn applicant는 apply/accept 불가
- inactive group 또는 closed post는 apply 불가
- left/removed membership은 current active member로 간주하지 않음
- application history는 삭제하지 않음

---

## 8. Dance-genre activation alternatives

현재 핵심 위험은 active dance genre 자체가 아니라 **legacy client가 domain 없이 active genre 전체를 읽는 것**이다.

### 8.1 Option A: Flutter legacy query에 `domain = band` 추가 후 활성화

DB 변경:

- activation migration에서 approved 11개 row를 active로 변경
- 기존 RLS 변경 없음

RLS/grant:

- 현재 `genres_read_active`를 그대로 사용
- active dance row는 anon/authenticated 모두 table에서 읽을 수 있음

Flutter ordering:

- legacy query filter를 반드시 먼저 배포
- 모든 onboarding/profile/group/recruitment master loader가 공통 service를 쓰는지 검증

Rollback:

- feature flag off
- forward-fix migration으로 11개 row를 inactive 복원

영향:

- 새 client는 안전
- 오래된 unfiltered client가 남아 있으면 dance genre가 legacy UI에 노출

복잡도:

- 낮음

평가:

- **필수 compatibility 선행 작업**이지만 단독 API 전략으로는 old client 관리가 필요

### 8.2 Option B: inactive 상태에서 STAGE 전용 view/RPC로 노출

DB 변경:

- inactive dance row를 예외적으로 반환하는 allowlist view/RPC

RLS/grant:

- SECURITY DEFINER 또는 별도 정책 필요 가능
- `is_active = false`를 우회하는 신뢰 경계가 추가됨

Flutter ordering:

- STAGE만 새 RPC 사용
- legacy는 변경 없이 유지 가능

Rollback:

- RPC execute revoke 또는 feature disable

영향:

- legacy leak 없음
- 기존 `assert_active_master_ids` 및 active-only join validator와 의미 충돌

복잡도:

- 중간 이상. “inactive지만 STAGE에서는 active”라는 이중 의미가 모든 write RPC에 전파됨

평가:

- old client를 절대 업데이트할 수 없는 경우의 임시 대안. 현재 Web-first 상황에서는 미권장

### 8.3 Option C: `stage_enabled` 같은 별도 availability 추가

DB 변경:

- genre availability column/check/index 또는 domain availability table

RLS/grant:

- legacy는 `is_active`, STAGE는 `stage_enabled`를 보는 별도 정책/RPC 필요

Flutter ordering:

- 각 client가 어느 availability를 따르는지 명시

Rollback:

- `stage_enabled = false`

영향:

- old legacy client 격리는 가장 강함
- 두 lifecycle flag의 조합과 운영 규칙이 장기 부채가 됨

복잡도:

- 높음

평가:

- 여러 장기 지원 native client가 이미 배포된 환경에는 의미가 있으나 현재 MVP에는 과설계

### 8.4 Option D: versioned domain master RPC

DB 변경:

- `get_active_genres_v1(p_domain)` 같은 최소 projection RPC
- approved activation migration

RLS/grant:

- master는 민감하지 않으므로 SECURITY INVOKER를 권장
- 기존 active RLS를 존중
- `public` execute는 revoke하고 필요한 `anon`, `authenticated`만 grant
- 반환 필드: `id`, `code`, `name`, `domain`, `category`, `sort_order`

Flutter ordering:

- STAGE는 versioned RPC만 사용
- legacy는 먼저 explicit band filter 적용

Rollback:

- STAGE feature disable
- 필요 시 11개 row inactive 복원
- RPC는 client rollback window 동안 유지

영향:

- domain contract가 API에 명시됨
- future Web/iOS가 같은 service 계약을 사용
- generic table query 확산 방지

복잡도:

- 중간이지만 장기 계약이 가장 명확

평가:

- **권장 target interface**

### 8.5 최종 rollout 권장

Option D를 target API로 사용하되, Option A의 legacy filter 배포를 activation gate로 둔다.

1. 033 roles 적용: dance genre는 inactive 유지
2. legacy Flutter에서 `domain = band` 명시
3. Web 배포와 cache/service-worker 갱신 확인
4. 034에서 versioned domain RPC 생성
5. 같은 034 transaction에서 exact 11 seed만 active 전환
6. STAGE client가 `p_domain = dance`로 RPC 사용
7. STAGE feature enable

legacy client 잔존을 운영상 보장할 수 없다면 034를 실행하지 않고 Option B 또는 C를 다시 승인받아야 한다.

---

## 9. Recommended migration and Flutter release sequence

### 9.1 Migration 033

권장 filename:

`033_stage_performance_roles.sql`

정확한 scope:

- dependency/preflight assertion
- `performance_roles`
- `user_performance_roles`
- 4개 active dance-role seed
- updated-at trigger
- RLS 및 least-privilege grants
- active role master read contract
- current-user role read/replace RPC
- seed/signature/postcondition verification
- PostgREST schema reload

포함하지 않는 것:

- dance genre activation
- `parts` 변경
- recruitment slot
- application column
- crew-supported role
- public profile v2
- professional verified state
- Flutter 변경

Dependency:

- Migration 032의 `users.performance_domain`
- 기존 `users`, `current_user_id()`, `is_admin()`, `set_updated_at()`

Compatibility:

- 기존 Flutter는 새 object를 참조하지 않으므로 no-op
- 기존 users/parts/genres/group/recruitment row에 backfill 없음

Rollback:

- 먼저 STAGE role feature를 off
- table/drop보다 보존 우선
- 심각한 결함은 execute grant revoke로 mutation을 중단
- 실제 drop이 필요하면 data export 후 별도 forward rollback migration

### 9.2 Legacy compatibility Flutter release

분류: **legacy compatibility update**

필수 변경:

- current active genre query에 `domain = band` 추가
- profile setup/edit, group edit, recruitment edit, filter가 같은 filtered source를 사용하는지 확인
- old model에 domain/category parsing을 강제하지 않아도 됨

금지:

- 이 단계에서 dance genre UI 노출
- role 값을 legacy `partIds`에 저장

Compatibility window:

- Web production 배포 확인
- 브라우저 cache/service worker가 이전 bundle을 계속 제공하지 않는지 확인
- future iOS release는 처음부터 domain-aware service만 포함

### 9.3 Migration 034

권장 filename:

`034_stage_domain_genre_access_and_activation.sql`

정확한 scope:

- 현재 11개 dance seed identity와 inactive 상태 preflight
- `get_active_genres_v1(p_domain)` 또는 동등한 versioned domain RPC
- exact approved 11개 row만 `is_active = true`
- legacy band row identity/state no-change assertion
- grants/revokes
- PostgREST reload

Dependency:

- 032
- legacy Flutter domain filter의 production 배포·검증

Flutter ordering:

- legacy filter 먼저
- STAGE service/feature enable은 034 이후

Rollback:

- feature flag off
- forward migration으로 exact 11 code만 inactive
- RPC는 rollback client window 동안 유지

### 9.4 STAGE Flutter role/genre release

분류: **reusable production foundation + STAGE-only implementation**

- domain-aware genre model/service
- performance-role model/service
- profile setup/edit role selector
- public profile role display는 safe DB projection 준비 후
- no fallback from role to `parts.dancer`

### 9.5 Recruitment role integration

별도 future migration으로 유지한다. 기존 문서의 migration 번호는 032 이후 순서 확정에 따라 다시 배정한다.

포함:

- `recruitment_role_slots`
- nullable application slot FK
- admin-only slot mutation
- apply/accept v2 RPC
- safe public recruitment v2 projection/filter
- capacity enforcement은 compatibility 검증 후

033 또는 034와 묶지 않는다.

---

## 10. Proposed tables, columns, constraints, and indexes

이 섹션은 future DDL contract이며 실행 SQL이 아니다.

### 10.1 Migration 033 exact object inventory

신규 table:

1. `public.performance_roles`
2. `public.user_performance_roles`

신규 index/constraint:

- `performance_roles.code` unique
- `performance_roles(domain, name)` unique
- `performance_roles(domain, sort_order)` unique
- `user_performance_roles(user_id, performance_role_id)` unique
- primary role partial unique on `user_id`
- role reverse lookup index `(performance_role_id, user_id)`

신규 trigger:

- 두 table의 existing `public.set_updated_at()` trigger

신규 function/RPC:

1. `get_active_performance_roles_v1(p_domain text)`
2. `get_my_performance_roles_v1()`
3. `replace_my_performance_roles_v1(p_performance_domain text, p_role_ids uuid[], p_primary_role_id uuid)`

033에서 만들지 않는 object:

- `group_performance_roles`
- `recruitment_role_slots`
- application role FK
- public profile role view
- genre activation RPC

### 10.2 Role replace RPC contract

Input:

- explicit performance domain
- role UUID array
- primary role UUID

Validation:

- authenticated `current_user_id()` 존재
- active user profile
- role ID 배열 중복 없음
- 1개 이상의 role
- primary가 role ID 배열 안에 존재
- 모든 role이 존재하고 active
- 모든 role domain이 explicit domain과 호환
- `professional_state`는 읽거나 변경하지 않음

Mutation:

- explicit user action으로 `users.performance_domain` 설정
- 기존 user-role rows를 current user 범위에서 교체
- exactly one primary row
- transaction 전체 성공 또는 전체 실패

Return:

- 최소한 success boolean 또는 저장된 role의 safe row
- email, phone, auth UID, birth date, billing/admin field 반환 금지

### 10.3 Future recruitment object inventory

신규:

- `recruitment_role_slots`

기존 additive:

- `recruitment_applications.recruitment_role_slot_id` nullable FK

기존 object 유지:

- `recruitment_post_parts`
- current create/update/apply/accept RPC signatures

새 v2 RPC가 안정화될 때까지 기존 RPC를 replace/drop하지 않는다.

---

## 11. RLS/grant/RPC/view design

### 11.1 `performance_roles`

Read:

- `anon`, `authenticated`: active master row만
- inactive row: operator 또는 self-assignment compatibility RPC에만 필요 시 반환

Write:

- ordinary user insert/update/delete 금지
- operator/admin만 관리
- seed 수정은 migration 우선

Grant:

- `public`의 implicit broad privilege revoke
- 필요한 role에 select 또는 versioned read RPC execute만 grant
- DML은 authenticated 일반 사용자에게 grant하지 않음

### 11.2 `user_performance_roles`

Direct read:

- self-only를 기본값으로 권장
- 다른 사용자의 role은 direct table이 아니라 future safe public projection 사용

Direct write:

- 일반 client의 table insert/update/delete grant 없음
- self mutation은 `replace_my_performance_roles_v1`으로만 수행
- RLS에도 타 사용자 mutation을 허용하는 policy를 만들지 않음

Operator:

- 일반 operator가 user 역할을 임의 수정할 MVP 요구 없음
- 운영 복구가 필요하면 audited operator RPC를 별도 설계

Public profile:

- 033에서는 노출하지 않음
- 후속 public profile v2에서 active user, block 관계, account status를 확인한 최소 projection만 추가

### 11.3 Role RPC security

`SECURITY DEFINER`를 사용하는 self RPC는 반드시:

- `search_path = public, pg_temp`
- 모든 table schema-qualified
- `public.current_user_id()` null check
- active account check
- target user ID를 client input으로 받지 않음
- 최소 필드만 반환
- `public`, `anon` execute revoke
- `authenticated`만 execute grant

Master RPC는 민감 데이터가 없고 active RLS를 그대로 존중할 수 있으므로 SECURITY INVOKER를 우선한다.

### 11.4 Future recruitment RLS

`recruitment_role_slots`:

- open active post의 safe projection은 authenticated read 가능
- draft/closed management read는 active group admin
- insert/update/delete는 active group admin 또는 operator
- member/non-member 일반 사용자의 mutation 금지

Application selected role:

- applicant는 자기 application safe state만
- group admin은 자기 group application만
- slot mutation과 application decision은 분리
- direct full-table grant보다 v2 RPC 선호

### 11.5 Genre RPC

권장 `get_active_genres_v1(p_domain)`:

- SECURITY INVOKER
- domain allowlist validation
- `is_active = true` 및 requested domain 필터
- safe master field만 반환
- `public` execute revoke
- product 요구에 따라 `anon`, `authenticated` execute grant
- 기존 `genres_read_active` policy를 넓히지 않음

### 11.6 Existing policy no-change

033은 다음 policy/signature를 바꾸지 않는다.

- `parts` 및 part joins
- `genres_read_active`
- `user_genres`
- `group_members`
- recruitment posts/applications
- member search views/RPC
- block/report
- chat/message

---

## 12. Backfill and compatibility plan

### 12.1 No inferred backfill

다음을 수행하지 않는다.

- current user에게 role 자동 부여
- `parts.dancer` → `dance_dancer` mapping
- `user_parts` → `user_performance_roles` 복제
- group member part → performance role 변환
- current group/recruitment post에 role slot 자동 생성
- existing application에 slot 추정

다음 값으로 role을 추론하지 않는다.

- genre name 또는 genre 선택
- bio
- experience level
- portfolio URL
- current instrument part
- group name

### 12.2 Existing row behavior

- existing users: role 0개, `performance_domain` 기존 null 유지
- existing `user_parts`: 그대로 읽고 씀
- existing groups: role join 없음
- existing recruitment posts: part 기반으로 계속 작동
- existing applications: role slot null인 legacy history
- existing public views/RPC: signature 변경 없음

### 12.3 Nullable/constraint rollout

- user-role table은 새 table이므로 FK/unique를 즉시 적용
- 기존 users에 role count requirement를 table-level로 강제하지 않음
- application slot FK는 future migration에서 nullable로 시작
- recruitment capacity는 nullable로 시작
- capacity over-accept hard enforcement는 모든 STAGE write path가 slot-aware가 된 뒤 적용
- legacy cleanup 또는 NOT NULL validation은 telemetry/row audit 이후 별도 migration

### 12.4 Retired role

- role row delete 금지
- `is_active = false`
- 신규 선택 금지
- 기존 assignment는 보존
- public/search v2는 active role만 기본 노출
- self edit UI는 retired assignment를 제거할 수 있도록 명시적 상태를 보여야 함

### 12.5 Compatibility layer 종료 조건

다음이 모두 충족되기 전에는 legacy part 관계를 deprecate/drop하지 않는다.

1. legacy BandMatch route 종료 결정
2. 모든 STAGE profile/recruitment/filter가 role contract 사용
3. existing part-based history 조회 경로 보존
4. rollback release 검증
5. data export/audit
6. 사용자 승인된 cleanup migration

---

## 13. Positive/negative verification plan

Remote DB test는 이 documentation task에서 실행하지 않는다. Future migration은 local/staging에서 아래를 검증한다.

### 13.1 Positive cases

1. **Legacy parts unchanged**
   - 12개 seed의 ID/code/name/sort/active 상태가 전후 동일
   - part join row count와 FK target 동일
2. **Current BandMatch profile**
   - 기존 onboarding/profile edit가 part/genre/area를 그대로 저장
3. **Current group/recruitment**
   - group recruiting parts 및 recruitment post parts가 동일하게 동작
4. **Current member search**
   - `p_part_ids` filter signature/result 유지
5. **Role seed**
   - 정확히 4개 approved code
   - name/domain/sort/active metadata 일치
6. **Role uniqueness**
   - 동일 user/role 중복 불가
   - 한 user의 primary가 2개일 수 없음
7. **Self role write**
   - active user가 자기 role set을 atomic replace
   - explicit dance domain과 dance roles 저장
8. **Public safety**
   - future safe profile은 role code/name/primary만 반환
9. **Retired role**
   - inactive role 신규 선택 불가
   - 기존 row는 삭제되지 않음
10. **Genre isolation before 034**
    - 11개 dance genre 모두 inactive
    - legacy query 결과에 dance 없음
11. **Genre activation after compatibility release**
    - legacy band-filtered query에는 band만
    - STAGE RPC `dance` 결과는 정확히 11개
12. **Web parsing**
    - UUID, JSON/list, nullable field parsing 정상
13. **Future iOS**
    - 같은 Supabase RPC 계약 사용
    - Web-only API 의존 없음
14. **Reapplication**
    - compatible 재실행은 seed ID/row count를 바꾸지 않음
    - metadata drift는 명시적 실패

### 13.2 Negative cases

1. user가 다른 user의 role row를 insert/update/delete할 수 없음
2. anon이 user-role join을 읽을 수 없음
3. inactive/suspended/withdrawn user가 role replace 불가
4. nonexistent 또는 inactive role ID 저장 실패
5. duplicate role ID input 실패
6. primary role이 selected list 밖이면 실패
7. dance domain user에게 future band role을 혼합 저장하면 실패
8. role 선택으로 `group_members.role`이 변하지 않음
9. instructor role 선택으로 `professional_state`가 verified가 되지 않음
10. email, phone, auth UID, birth date, billing, reports, blocks, admin field가 role response에 없음
11. non-admin이 future recruitment slot을 변경할 수 없음
12. 다른 group admin이 slot을 변경할 수 없음
13. applicant가 해당 post에 없는 role slot으로 신청할 수 없음
14. blocked 관계에서 apply/accept 불가
15. suspended/withdrawn applicant apply/accept 불가
16. pending/rejected/closed post에 부적절한 slot mutation/apply 불가
17. legacy unfiltered query가 존재하는 build에서는 activation gate 실패로 처리
18. unexpected 12번째 `dance_*` code가 activation 대상에 포함되지 않음
19. 033 적용으로 기존 RLS/grant/view/RPC signature가 바뀌지 않음
20. migration partial state 또는 named constraint drift가 있으면 silent repair 없이 실패

### 13.3 Drift/preflight checks

033 future SQL은 최소 다음을 확인해야 한다.

- required dependency object와 function 존재
- 같은 이름 table/column/function의 incompatible partial state 없음
- approved role code/name/domain/sort collision 없음
- 기존 `parts`, `genres`, users, relevant view/RPC before/after no-change
- exact seed count
- expected constraint/index/policy/function signature
- grants에 public/anon DML이 없음

034 future SQL은:

- exact 11 dance code/ID/metadata
- 적용 전 모두 inactive
- legacy 18 genres no-change
- unexpected dance code no activation
- RPC projection/signature
- active count와 domain filter 결과

를 확인해야 한다.

---

## 14. Rollback and feature-disable plan

### 14.1 Migration 033

가장 먼저 할 일:

1. STAGE performance-role feature flag off
2. role edit route 비활성
3. existing BandMatch routes 계속 사용

DB:

- user-role data는 삭제하지 않음
- 필요 시 mutation RPC execute를 revoke하는 forward migration
- master read는 무해하므로 유지 가능
- drop은 client dependency와 data export 확인 후 별도 rollback migration

033은 기존 object를 변경하지 않는 additive migration이므로 긴급 drop보다 feature disable이 안전하다.

### 14.2 Migration 034

문제 발생 시:

1. STAGE dance genre feature off
2. exact 11 approved code를 inactive로 되돌리는 forward migration
3. legacy band-filtered client 유지
4. versioned RPC는 old STAGE client rollback window 동안 유지

다음을 하지 않는다.

- dance row delete
- genre ID 재생성
- legacy genre update
- current user genre assignment 자동 삭제

### 14.3 Flutter rollback

- legacy filter는 rollback하지 않는다. `domain = band`는 기존 BandMatch 의미를 더 정확하게 만든다.
- STAGE role/genre UI만 feature flag로 끈다.
- old BandMatch models/services는 compatibility period 동안 유지한다.
- Web/iOS가 같은 repository/service interface를 사용하고 Web-only workaround를 넣지 않는다.

---

## 15. User decisions required

Migration 032에서 이미 확정된 genre 11개, domain/category, professional 2-state, generic experience reuse는 다시 묻지 않는다.

### Decision 1: 초기 role seed

- 질문: MVP role을 `ダンサー`, `振付師`, `インストラクター`, `その他` 4개로 확정할 것인가?
- 권장: 4개 확정
- 대안: dancer만 시작 / support dancer 추가 / instructor 연기
- UI 영향: role selector option과 label
- DB 영향: immutable stable code와 seed count
- 구현 차단: **예, 033 seed를 차단**
- 연기 가능: 아니오

### Decision 2: user role 선택 방식

- 질문: 여러 role + primary 1개를 허용할 것인가?
- 권장: multiple selection, exactly one primary; DB hard maximum 없음
- 대안: single role / multiple without primary / max 3
- UI 영향: chip multi-select와 primary radio/selection
- DB 영향: join table 및 partial unique index, replace RPC
- 구현 차단: **예**
- 연기 가능: 아니오

### Decision 3: role 공개 범위

- 질문: active profile의 선택 role과 primary를 safe public profile에서 공개할 것인가?
- 권장: role 전체와 primary 공개, role별 visibility toggle 없음
- 대안: primary만 공개 / per-role visibility
- UI 영향: member/applicant profile role chips
- DB 영향: future safe projection fields; 033 self storage에는 영향 적음
- 구현 차단: 033 table은 차단하지 않음, public profile v2는 차단
- 연기 가능: **예**

### Decision 4: crew-supported role

- 질문: Crew profile 자체에 supported role을 수동 저장할 것인가?
- 권장: MVP에서는 저장하지 않고 recruitment slots로 수요 표현
- 대안: `group_performance_roles` 추가
- UI 영향: crew edit의 별도 role selector 유무
- DB 영향: group-role join과 admin RLS
- 구현 차단: 033은 차단하지 않음
- 연기 가능: **예**

### Decision 5: recruitment application role

- 질문: applicant가 한 application에서 정확히 한 requested role slot을 선택할 것인가?
- 권장: 정확히 1개; post에 1개면 자동 선택
- 대안: 여러 role / post가 role 하나만 갖도록 제한 / role 선택 없음
- UI 영향: application form과 상태 표시
- DB 영향: slot table, nullable application FK, v2 apply/accept RPC
- 구현 차단: 033은 아님, recruitment integration은 **차단**
- 연기 가능: 033 이후까지 가능

### Decision 6: capacity와 beginner-friendly

- 질문: slot에 nullable requested count와 beginner-friendly를 MVP field로 둘 것인가?
- 권장: 둘 다 column 추가, count는 nullable, hard capacity enforcement는 cutover 뒤
- 대안: 전부 free text / count만 / 즉시 hard enforcement
- UI 영향: remaining count와 beginner-friendly filter
- DB 영향: slot column/check와 후속 acceptance validation
- 구현 차단: 033은 아님, recruitment integration은 **차단**
- 연기 가능: role foundation 이후까지 가능

### Decision 7: dance genre activation gate

- 질문: legacy Web build의 `domain = band` 배포·cache 검증을 034 실행의 필수 gate로 승인할 것인가?
- 권장: 예; versioned domain RPC + activation은 그 이후
- 대안: inactive exception RPC(Option B) / `stage_enabled`(Option C)
- UI 영향: legacy leak 방지와 STAGE genre availability
- DB 영향: 034 실행 시점과 availability semantics
- 구현 차단: 033은 아님, **dance activation은 차단**
- 연기 가능: 033 이후까지 가능

---

## 16. Readiness recommendation

### 16.1 Migration 033

**조건부 준비 완료**다.

기술적 경계, object scope, legacy no-change, RLS 원칙, Flutter contract, rollback, verification은 SQL 구현 사양으로 충분하다. 다만 다음 두 결정을 승인하기 전에는 stable seed와 join constraint를 확정하면 안 된다.

- Decision 1: 초기 4개 role
- Decision 2: multiple + one primary

Decision 3은 public projection을 033에서 제외하면 연기할 수 있다.

### 16.2 Dance activation

**아직 실행 준비가 완료되지 않았다.**

선행 조건:

1. legacy Flutter genre query에 `domain = band`
2. 관련 모든 화면이 공통 filtered service를 사용하는지 검증
3. Web 배포 및 stale cache 확인
4. Option D rollout 승인
5. 034 별도 사양/구현 검토

### 16.3 Recruitment role integration

**설계 방향만 준비되었고 구현 준비는 미완료**다.

Decision 5–6과 capacity enforcement timing을 확정한 뒤 별도 migration spec을 작성한다. 033에 미리 포함하지 않는다.

---

## 17. Recommended exact next Codex task

사용자가 Decision 1과 Decision 2를 승인한 뒤 다음 요청을 사용한다.

> Implement the approved STAGE performance-role foundation on the `stage-redesign` branch.
>
> Create exactly one migration:
>
> `supabase/migrations/033_stage_performance_roles.sql`
>
> Follow `docs/stage-analysis/09_MIGRATION_033_SPEC.md`.
>
> Scope the migration to:
>
> - `performance_roles`
> - `user_performance_roles`
> - the four approved dance-role seeds
> - required constraints, indexes, updated-at triggers, RLS, grants/revokes
> - versioned active-role and self-role RPCs
> - strict preflight, postcondition, drift, and reapplication checks
> - `notify pgrst, 'reload schema'`
>
> Do not:
>
> - activate dance genres
> - modify `parts` or any legacy part join
> - add recruitment role slots
> - change existing Flutter code
> - change existing migrations 001–032
> - change professional verification
> - modify current public profile/search/recruitment/chat contracts
> - execute remote SQL
> - commit or push automatically
>
> Before editing, verify `stage-redesign`, a clean worktree, HEAD, and the 001–032 inventory. After editing, run static SQL/repository checks and confirm that the migration file is the only change.

그 다음 별도 task:

1. legacy Flutter domain-filter compatibility update
2. `034_stage_domain_genre_access_and_activation.sql`의 독립 상세 사양
3. 034 적용 이후 STAGE role/genre Flutter implementation
4. recruitment role slot/application integration spec

Suggested commit message for this specification document:

`docs: define STAGE performance role architecture`

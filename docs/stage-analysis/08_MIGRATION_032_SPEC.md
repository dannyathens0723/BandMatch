# STAGE Migration 032 상세 구현 사양

작성일: 2026-07-29 (JST)

대상 브랜치: `stage-redesign`

기준 HEAD: `a556af5985da874e476b5ff6ed12387feae877b6`

대상 미래 파일명: `032_stage_taxonomy_and_user_profile.sql`

상태: **설계안 — SQL 미작성·미실행**

## 1. Executive recommendation

Migration 032는 기존 BandMatch 데이터와 Flutter 계약을 그대로 유지하면서, STAGE가 이후 마이그레이션에서 사용할 최소 taxonomy/profile 기반만 추가하는 것이 적절하다.

권장 범위는 다음과 같다.

1. `genres`에 `domain`, `category` 두 메타데이터 컬럼을 추가한다.
2. 기존 장르 18개의 ID, code, name, sort order, 활성 상태를 변경하지 않고 `band` / `legacy_music`으로 명시적으로 분류한다.
3. STAGE 댄스 장르 **11개**를 안정 code와 예약 sort order로 삽입한다.
4. 신규 댄스 장르는 Migration 032 적용만으로 현재 BandMatch UI에 노출되지 않도록 모두 `is_active = false`로 seed한다.
5. `users`에는 다음 두 컬럼만 추가한다.
   - nullable `performance_domain`
   - self-declared 상태만 허용하는 `professional_state`
6. 댄스 경험, 활동 빈도, 활동 가능 요일, 활동 지역, 자기소개, 포트폴리오는 기존 구조를 재사용한다.
7. 기존 safe view/RPC 반환형, RLS policy, grant, Flutter 코드는 Migration 032에서 변경하지 않는다.
8. operator-verified professional 값과 증빙·심사 구조는 Migration 035로 미룬다.

이 범위는 현재 앱을 변경하지 않고 적용할 수 있다. 다만 실제 SQL 구현 전 아래 네 가지 제품 결정을 사용자가 승인해야 한다.

- 신규 장르 11개와 일본어 표기
- `STREET`를 장르 row가 아닌 category로 표현하는 방식
- 신규 장르를 032에서는 비활성으로 두는 rollout 방식
- professional foundation을 2단계(`general`, `professional_unverified`)로 먼저 만드는 방식

따라서 Migration 032는 **구현 가능한 수준으로 설계되었지만, 위 결정을 승인하기 전에는 SQL 구현을 시작하지 않는 것**을 권장한다.

---

## 2. Exact in-scope changes

### 2.1 `genres` additive extension

| 컬럼 | 타입 | null | 기본값 | 허용값 | 목적 |
|---|---|---:|---|---|---|
| `domain` | `text` | 불가 | `band` | `band`, `dance` | 기존 음악 장르와 STAGE 댄스 장르를 파괴 없이 분리 |
| `category` | `text` | 불가 | `legacy_music` | `legacy_music`, `commercial`, `street`, `jazz_contemporary`, `entertainment`, `other` | STAGE filter/group heading의 안정적인 상위 분류 |

기존 장르 row에는 기본값을 통해 다음 분류가 적용된다.

- `domain = 'band'`
- `category = 'legacy_music'`

`domain`과 `category`는 사용자 표시명이 아니라 내부 안정 code다. Flutter 일본어 UI는 `genres.name`을 계속 사용한다.

### 2.2 Dance genre seed

- 신규 row 수: **11**
- 모든 신규 row의 `domain`: `dance`
- 모든 신규 row의 최초 `is_active`: `false`
- sort order: 기존 `1`–`18`과 충돌하지 않는 `101`–`111`
- 기존 row의 ID/code/name/sort order/활성 상태: 변경 없음

### 2.3 `users` additive extension

| 컬럼 | 타입 | null | 기본값 | 허용값 | 목적 |
|---|---|---:|---|---|---|
| `performance_domain` | `text` | 허용 | 없음 | `band`, `dance`, `multi_domain` | 사용자가 주로 활동하는 performance 영역. 기존 사용자를 댄서로 추론하지 않기 위해 null 유지 |
| `professional_state` | `text` | 불가 | `general` | `general`, `professional_unverified` | 사용자가 직접 표시할 수 있는 self-declared professional/instructor 기반 |

`professional_verified`는 Migration 032의 허용값에 포함하지 않는다. 따라서 032 적용 후 일반 클라이언트가 verified 상태를 저장할 수 있는 경로 자체가 없다.

### 2.4 Schema reload

새 컬럼이 PostgREST schema cache에 반영되도록 미래 migration 마지막에 schema reload notification을 포함한다. RPC/view 반환 signature는 변경하지 않더라도 table column metadata가 바뀌므로 reload가 필요하다.

---

## 3. Explicit out-of-scope changes

Migration 032는 다음을 구현하지 않는다.

- `performance_roles` 및 user/group/recruitment role join
- 기존 `parts`의 의미 변경, rename, 삭제 또는 댄스 역할로의 자동 변환
- exact nearest station, station master, 노선, 좌표, private location
- professional verification evidence, review, operator audit, verified badge
- 이벤트, organizer, source/review, lesson/workshop
- studio, studio room, facility, recommendation
- practice, attendance, schedule poll, announcement, resource
- recruitment post의 event/role/beginner-friendly 조건
- guardian consent, 최소 연령 또는 미성년자 interaction 정책
- public profile v2, STAGE My Page RPC, STAGE member/crew profile RPC
- 기존 safe view/RPC 반환 컬럼 추가
- 기존 RLS policy, grant 또는 Storage policy 변경
- 새 self-update RPC
- 기존 사용자에 대한 dancer/professional 추론
- 기존 `user_genres` row를 신규 댄스 genre로 복제 또는 이동
- hard delete, table rename, 기존 constraint 제거
- Flutter model/service/screen/router 변경

---

## 4. Existing-object impact matrix

### 4.1 Core objects

| 객체 | 현재 계약 | Migration 032 이후 계약 | 032 변경 | 호환 위험 | 기존 Flutter |
|---|---|---|---|---|---|
| `public.users` | self RLS가 적용된 account/profile 원본. `birth_date`, email, phone, auth/system 필드를 포함 | 기존 컬럼·constraint 유지 + 두 profile foundation 컬럼 | additive column 2개 | 낮음. `select('*')`를 model에 강제 casting하는 코드가 없고 현재 코드는 명시 컬럼만 선택 | 변경 없이 동작 |
| `public.genres` | UUID PK, unique `code`, unique `name`, unique `sort_order`, active flag | 기존 계약 유지 + domain/category | additive column 2개 + inactive seed 11개 | 낮음. 신규 row를 active로 만들면 legacy UI에 나타나는 위험이 있으므로 032에서는 inactive | 변경 없이 동작하고 반환 목록도 그대로 |
| `public.user_genres` | `(user_id, genre_id)` unique, self write, public-visible profile read | 기존 계약 그대로. 향후 band/dance 장르 모두 참조 가능 | 없음 | 없음. 기존 선택을 재분류/복제하지 않음 | 변경 없이 동작 |
| `public.user_purposes` | `recruit`, `join`, `practice` | broad participation intent로 호환 사용 | 없음 | copy 의미는 추후 Flutter에서 조정 필요 | 변경 없이 동작 |
| `public.user_areas` | broad profile area, self direct read/write, safe projection에서 공개 범위 제한 | broad activity area로 계속 사용 | 없음 | exact station을 섞지 않는 한 낮음 | 변경 없이 동작 |
| `public.media_portfolios` | user/group 외부 media, platform은 YouTube/SoundCloud, public flag/RLS | public performance portfolio 기반으로 재사용 | 없음 | provider 종류가 제한적이지만 032 범위에는 영향 없음 | 현재 profile flow 변화 없음 |

### 4.2 Triggers and indexes

| 객체 | 현재 계약 | 032 영향 | 조치 |
|---|---|---|---|
| `set_updated_at` on `users` | user row update 시 `updated_at` 갱신 | 새 profile 컬럼 update에도 자동 적용 | definition 변경 없음 |
| `set_updated_at` on `genres` | genre row update 시 `updated_at` 갱신 | 분류 backfill 또는 향후 activation에도 자동 적용 | definition 변경 없음 |
| `protect_user_system_fields` | auth/email/phone/account/billing 성격의 system field client 변경 방지 | 032의 두 필드는 의도적으로 self-editable이고 verified 값은 아직 존재하지 않음 | 032에서는 변경하지 않음. 035에서 verified 값 추가와 동시에 보호 확장 |
| `users_active_last_login_idx` | active user 최근 로그인 조회 | 새 필드 filter와 무관 | 유지 |
| `user_genres_genre_idx` | genre별 user join 조회 | 신규 genre에도 그대로 유효 | 유지 |
| `genres` unique constraints | code/name/sort order 충돌 방지 | seed preflight가 충돌을 먼저 보고해야 함 | 유지 |

작은 master table인 `genres`에는 032에서 domain/category index를 추가하지 않는다. `users.performance_domain`과 `professional_state`도 현재 RPC가 filter하지 않으므로 032에서 index를 만들지 않는다.

### 4.3 RLS policies

| policy family | 현재 계약 | 032 변경 | 보안 결과 |
|---|---|---|---|
| `genres_read_active` | active genre만 `anon`, `authenticated` read | 없음 | inactive dance seed는 현재 client에 노출되지 않음 |
| `master_data_admin_manage_genres` | authenticated operator/admin만 genre write | 없음 | seed 이후 taxonomy client write 범위가 넓어지지 않음 |
| `users_select_self` | 본인만 full `users` row read | 없음 | 새 user 필드는 타인에게 full-row로 노출되지 않음 |
| `users_insert_self` | auth UID/account/system 기본값 검증 | 없음 | 신규 user는 `performance_domain = null`, `professional_state = general`로 생성 가능 |
| `users_update_self_*` | active 본인 row만 update, phone state 보존 | 없음 | 본인은 domain 및 unverified claim만 변경 가능 |
| `users_admin_manage` | operator/admin 관리 | 없음 | operator 권한 의미 유지 |
| `user_genres_read/write` | 본인 write, active/nonblocked profile의 join read | 없음 | 다른 사용자의 private `users` row를 열지 않음 |

032에서는 기존 policy를 drop/recreate하거나 role을 추가하지 않는다. 따라서 기존 RLS가 넓어지지 않는다.

### 4.4 Safe views and RPCs

| 객체 | 현재 반환/동작 | 032 변경 | 호환 판단 |
|---|---|---|---|
| `user_public_profiles` | age opt-in, public BandMatch profile 필드 | 없음 | signature 그대로 |
| `user_public_areas` | broad/opt-in area projection | 없음 | exact station 추가 없음 |
| `member_search_profiles` | active/nonblocked 다른 사용자와 safe profile/genre names | 없음 | 신규 inactive genre는 결과 변화 없음 |
| `member_public_profile_details` | search projection + artists/gear/frequency/days | 없음 | signature 그대로 |
| `search_member_profiles` | part/genre/area/experience/purpose/name filter | 없음 | 기존 filter와 반환형 그대로 |
| `get_my_page_profile` | 본인 display/avatar/experience/part/genre/area summary | 없음 | signature 그대로 |
| `assert_active_master_ids('genres', …)` | active genre ID만 group/recruitment mutation에 허용 | 없음 | inactive dance seed는 의도적으로 아직 저장 대상이 아님 |

현재 safe view/RPC를 `create or replace`하여 새 필드를 붙이면 PostgREST 반환 signature와 Flutter parser의 release 순서가 결합된다. 032에서는 이를 피하고, 이후 `get_my_stage_profile`/`get_public_stage_profile` 같은 versioned successor를 별도 migration에서 만든다.

### 4.5 Flutter contracts

| Flutter 객체 | 현재 계약 | 032 이후 |
|---|---|---|
| `MasterDataItem` | `id`, `code`, `name`, `sort_order`, optional `level`만 파싱 | 추가 DB 컬럼을 요청하지 않으므로 영향 없음 |
| `MasterDataService` | active `parts`, `genres`, `areas`만 명시 컬럼 select | 신규 genre가 inactive이므로 결과 동일 |
| `ProfileSetupData` / `ProfileEditData` | 기존 purpose/part/experience/genre/area 저장 | 새 user 컬럼 생략 가능. DB null/default 사용 |
| `ProfileService` | 본인 `users`의 명시 컬럼과 self join table만 접근 | 영향 없음 |
| `MemberProfile` / `MemberSearchService` | 현재 safe view/RPC signature 파싱 | signature 미변경으로 영향 없음 |
| `MyPageProfile` / `MyPageService` | `get_my_page_profile` 고정 반환형 파싱 | signature 미변경으로 영향 없음 |
| profile/member/My Page screens | 기존 BandMatch code와 일본어 copy 사용 | 032 적용만으로 UI 변화 없음 |

---

## 5. Proposed genre taxonomy

### 5.1 Classification policy

- `domain`은 하나의 genre row가 속한 performance 영역을 뜻한다.
- 현재 BandMatch의 18개 genre는 음악/밴드 맥락으로 생성되었으므로 모두 `band`로 유지한다.
- 현재의 `hiphop_reggae`, `house_techno`, `jazz_fusion`을 dance genre로 자동 해석하지 않는다.
- `category`는 STAGE filter group을 위한 상위 분류다.
- `STREET`는 개별 춤 장르보다 여러 street dance style의 umbrella에 가깝기 때문에 별도 genre row로 만들지 않고 `category = street`로 표현한다.
- `POP`은 음악 pop과 혼동되므로 안정 code와 표시명 모두 dance style인 `POPPING`을 사용한다.
- `LOCK`은 일본 현장에서 쓰이는 표현과 장기 명확성을 위해 `LOCKING`으로 정규화한다.
- `GIRLS` 단독 표기는 범위가 불명확하므로 `GIRLS HIPHOP`을 사용한다.
- 일본에서 흔히 구분되는 `JAZZ HIPHOP`을 초기 taxonomy에 포함한다.
- alias/search synonym은 실제 검색 요구가 확인될 때 별도 구조로 추가한다. 032에는 alias 컬럼을 추가하지 않는다.

### 5.2 Proposed 032 seed: 11 rows

| sort | stable code | 일본어 표시명 | domain | category | 032 active | 단계 | 근거 |
|---:|---|---|---|---|---:|---|---|
| 101 | `dance_kpop` | `K-POP` | `dance` | `commercial` | false | MVP | 초기 핵심 사용자와 wireframe의 최우선 탐색 축 |
| 102 | `dance_hiphop` | `HIPHOP` | `dance` | `street` | false | MVP | 제품 문서가 명시한 핵심 확장 장르 |
| 103 | `dance_jazz` | `JAZZ` | `dance` | `jazz_contemporary` | false | MVP | 제품 문서가 명시한 주요 장르 |
| 104 | `dance_jazz_hiphop` | `JAZZ HIPHOP` | `dance` | `jazz_contemporary` | false | MVP | 일본 댄스 수업·모집에서 별도 선택 수요가 높은 결합 스타일 |
| 105 | `dance_girls_hiphop` | `GIRLS HIPHOP` | `dance` | `commercial` | false | MVP | 초기 여성/K-POP 인접 타깃에 적합하며 `GIRLS`보다 의미가 명확 |
| 106 | `dance_waack` | `WAACK` | `dance` | `street` | false | MVP | 대표 street style |
| 107 | `dance_locking` | `LOCKING` | `dance` | `street` | false | MVP | `LOCK`보다 안정적이고 명확한 명칭 |
| 108 | `dance_popping` | `POPPING` | `dance` | `street` | false | MVP | 음악 `POP`과의 충돌 방지 |
| 109 | `dance_breaking` | `BREAKING` | `dance` | `street` | false | MVP | 대표 street style이자 국제 표준에 가까운 명칭 |
| 110 | `dance_house` | `HOUSE` | `dance` | `street` | false | MVP | 기존 `house_techno`와 구별되는 dance style |
| 111 | `dance_other` | `その他（ダンス）` | `dance` | `other` | false | MVP | 초기 taxonomy 밖의 사용자를 배제하지 않기 위한 fallback |

### 5.3 Considered but not seeded in 032

| 후보 | 판단 | 이유 |
|---|---|---|
| `STREET` | 불필요한 genre row | umbrella category로 표현. 별도 row를 만들면 HIPHOP/WAACK/LOCKING 등과 의미가 중복 |
| `CONTEMPORARY` | future | 제품 문서의 초기 핵심 filter에는 없고, 실제 모집/lesson 데이터가 생길 때 추가해도 기존 구조를 변경할 필요 없음 |
| `THEME_PARK` | future | 일본 시장에서 유효할 수 있으나 초기 crew recruitment 핵심 taxonomy로는 근거가 부족 |
| `GIRLS` | 이름 수정 후 포함 | `GIRLS HIPHOP`으로 seed |
| `LOCK` | 이름 수정 후 포함 | `LOCKING`으로 seed |
| `POP` | 이름 수정 후 포함 | `POPPING`으로 seed |

`CONTEMPORARY`와 `THEME_PARK`를 나중에 추가할 수 있도록 category check에는 각각 사용할 수 있는 `jazz_contemporary`, `entertainment` 값을 미리 허용한다. 두 genre row 자체는 032에서 만들지 않는다.

### 5.4 Activation strategy

032에서 11개 seed를 inactive로 두는 이유는 현재 `MasterDataService`가 domain filter 없이 모든 active genre를 읽기 때문이다. 신규 row를 즉시 active로 만들면 기존 BandMatch onboarding/profile edit에 댄스 장르가 갑자기 섞인다.

권장 cutover 순서는 다음과 같다.

1. 032에서 inactive seed와 domain/category 기반을 만든다.
2. STAGE용 master-data query/RPC가 `domain = dance`를 명시하도록 구현한다.
3. 해당 Flutter release와 함께 별도 작은 activation migration에서 승인된 MVP row만 active로 전환한다.
4. legacy BandMatch path가 남아 있다면 `domain = band` filter를 추가한 뒤 activation한다.

032에는 별도 `is_default` 또는 `stage_enabled` 컬럼을 추가하지 않는다. 기존 `is_active`와 app release 순서로 충분하다.

---

## 6. Proposed user-field plan

| 요구 | 분류 | 032 처리 | 현재/미래 계약 |
|---|---|---|---|
| performance domain | **새 nullable 컬럼** | `users.performance_domain` 추가 | 기존 사용자는 null. STAGE onboarding에서 명시적으로 선택 |
| dance experience | **기존 컬럼을 새 UI 의미로 재사용** | `experience_level` definition 변경 없음 | `beginner_new`, `beginner`, `experienced`, `pro_oriented` 유지. `pro_oriented`는 verified 의미가 아님 |
| activity frequency | **기존 컬럼 그대로 재사용** | 변경 없음 | `monthly_1_2`, `weekly_1_2`, `daily` |
| activity days / availability | **기존 컬럼을 새 UI 의미로 재사용** | `activity_days` 변경 없음 | profile 표시용 free text. 구조화된 일정 가능성은 practice/poll domain에서 별도 설계 |
| activity area | **기존 join 그대로 재사용** | `user_areas` 변경 없음 | broad public area만. exact station 금지 |
| public professional/instructor state | **새 컬럼** | self-declared 2단계 `professional_state` 추가 | verified 값·badge·evidence는 035 |
| profile introduction | **기존 컬럼 그대로 재사용** | `bio` 변경 없음 | 최대 1000자, safe projection을 통해 공개 |
| public portfolio URL | **기존 관계 재사용** | `media_portfolios` 변경 없음 | user-owned public external media. provider 확장은 별도 media/profile task |
| beginner-friendly preference | **Migration 038로 연기** | users에 추가하지 않음 | 사람의 영구 속성보다 recruitment condition에 적합 |
| desired participation style | **기존 `user_purposes`를 broad intent로 재사용** | check 변경 없음 | recruit/join/practice copy만 STAGE UI에서 조정. project/permanent 구분은 제품 결정 후 recruitment/role domain |
| dance role/position | **Migration 033으로 연기** | 추가하지 않음 | `performance_roles`, `user_performance_roles` 사용 |
| exact nearest station | **Migration 034로 연기** | 추가하지 않음 | private location table/RPC |
| verification evidence/review | **Migration 035로 연기** | 추가하지 않음 | client direct select 불가, operator workflow 필요 |
| event participation history | **Migration 036 이후로 연기** | 추가하지 않음 | event/crew lifecycle 구조에서 관리 |

### 6.1 Why no new dance-experience column

현재 `experience_level`은 generic profile field이며 기존 public view, search RPC, Flutter dropdown과 이미 연결되어 있다. 032에서 `dance_experience_level`을 추가하면 동일 개념이 둘로 갈라지고 기존 사용자의 값 mapping이 필요해진다.

초기 STAGE에서는 현재 네 값을 일본어 dance copy로 재사용한다. 정확한 연차, 수업 경력, 무대 횟수처럼 더 구조화된 요구가 확인되면 기존 값을 파괴하지 않는 별도 field/model을 추가한다.

`pro_oriented`는 자기 지향성일 뿐 `professional_state` 또는 operator verification을 의미하지 않는다.

### 6.2 Why no new availability structure

`activity_frequency`와 `activity_days`가 현재 공개 상세에 이미 존재한다. 초기 profile 표시에는 충분하다. 특정 요일·시간대 검색이나 crew 일정 매칭은 practice/schedule poll 요구와 함께 구조화해야 하며 032에서 미리 column을 늘리지 않는다.

---

## 7. Professional-state recommendation

### 7.1 Recommended option: self-declared foundation only

세 가지 후보 중 **2번: public self-declared state foundation만 032에 추가**를 권장한다.

032의 허용 상태:

- `general`
- `professional_unverified`

035에서 추가할 상태:

- `professional_verified`

### 7.2 Security impact

- 032의 check constraint에 `professional_verified` 문자열이 없으므로 일반 사용자, Flutter 버그, 직접 REST 호출 모두 verified를 저장할 수 없다.
- 기존 self-update RLS는 본인 active row에만 적용되므로 타인의 상태를 변경할 수 없다.
- `professional_unverified`는 이름 그대로 자기 신고 상태이므로 self update를 허용해도 operator 신뢰를 사칭하지 않는다.
- 035에서 verified 값을 check에 추가할 때는 같은 transaction에서 `protect_user_system_fields` 또는 verified 전용 operator RPC를 반드시 강화해야 한다.
- 035 적용 후 일반 사용자는 `general ↔ professional_unverified`만 변경할 수 있고 `professional_verified` 설정·해제는 operator만 수행해야 한다.

### 7.3 Operator workflow impact

- 032에는 신청, 증빙, 검토, 반려, 취소, 만료, 운영자 메모가 없다.
- 운영자는 032의 self-declared 값을 인증 완료로 해석해서는 안 된다.
- 035에서 evidence metadata, review status, reviewed actor/time/reason, 취소/만료 audit를 추가한다.
- evidence 원문 보관 기간과 허용 형식은 제품·법률 결정 후 정의한다.

### 7.4 Flutter impact

- 032에서는 기존 Flutter가 이 컬럼을 읽거나 쓰지 않아도 된다.
- STAGE profile UI는 향후 versioned self-profile RPC에서 `general` 또는 `professional_unverified`를 편집한다.
- public badge UI는 035와 public profile v2가 완료되기 전에는 표시하지 않는다.
- `experience_level = pro_oriented`와 professional badge를 연결하지 않는다.

### 7.5 Migration-order impact

- 032: 2단계 self-declared foundation
- 035: constraint를 3단계로 확장 + evidence/review table + operator-only verified mutation + audit
- 043: verified instructor/organizer의 lesson/workshop write 조건에 사용
- 048: public/member/operator projection과 negative access test 최종 고정

### 7.6 Rejected alternatives

| 대안 | 미권장 이유 |
|---|---|
| 032에서 professional field를 전혀 만들지 않음 | taxonomy/profile foundation과 STAGE onboarding 설계가 다시 035에 강하게 결합됨 |
| 032에서 완전한 3-state field를 즉시 추가 | 현재 broad self-update policy/trigger를 함께 변경해야 하고, evidence/operator workflow 없이 verified state만 먼저 존재하게 됨 |
| boolean `is_professional` | self-declared와 operator-verified를 구별할 수 없어 badge 신뢰 경계가 무너짐 |

---

## 8. Public/private visibility matrix

“authenticated public profile”은 full `users` select를 뜻하지 않는다. 명시적으로 제한된 safe view/RPC만을 뜻한다.

| 데이터 | self-only | authenticated public profile | same-crew only | crew leader only | operator only | 032 포함 |
|---|---:|---:|---:|---:|---:|---:|
| `display_name` | 예 | 예, 기존 safe projection | 아니오 | 아니오 | 관리 목적 | 기존 |
| `avatar_url` | 예 | 예, 기존 safe projection | 아니오 | 아니오 | 관리 목적 | 기존 |
| `bio` | 예 | 예, 기존 safe projection | 아니오 | 아니오 | 관리 목적 | 기존 |
| `performance_domain` | 예 | **향후 STAGE safe profile v2에서만** | 아니오 | 아니오 | 관리 목적 | 새 컬럼 |
| `experience_level` | 예 | 예, 기존 safe projection | 아니오 | 아니오 | 관리 목적 | 기존 |
| `activity_frequency` | 예 | 예, 기존 detail projection | 아니오 | 아니오 | 관리 목적 | 기존 |
| `activity_days` | 예 | 예, 기존 detail projection | 아니오 | 아니오 | 관리 목적 | 기존 |
| `user_genres` / genre names | 예 | 예, 기존 safe projection | 아니오 | 아니오 | 관리 목적 | 기존 + taxonomy |
| broad `user_areas` | 예 | 공개 허용 범위만 | 아니오 | 아니오 | 관리 목적 | 기존 |
| `professional_state` | 예 | **향후 STAGE safe profile v2에서만** | 아니오 | 아니오 | 상태 관리 | 새 컬럼 |
| public `media_portfolios` | 예 | RLS를 통과한 public item만 | 아니오 | 아니오 | 관리 목적 | 기존 |
| age | 예 | `show_age = true`일 때 계산된 age만 | 아니오 | 아니오 | 관리 목적 | 기존 |
| exact `birth_date` | 예 | **아니오** | 아니오 | 아니오 | 정당한 운영 목적 | 기존 private |
| email | Auth/self account section | **아니오** | 아니오 | 아니오 | 정당한 운영 목적 | 기존 private |
| phone / `phone_verified` | self account/verification | **아니오** | 아니오 | 아니오 | 정당한 운영 목적 | 기존 private |
| `auth_uid` | 내부/self mapping | **아니오** | 아니오 | 아니오 | 예 | 기존 private |
| billing/subscription | 본인 제한 view 가능 | **아니오** | 아니오 | 아니오 | 예 | 기존 private |
| admin/system fields | 아니오 | **아니오** | 아니오 | 아니오 | 예 | 기존 private |
| exact nearest station | 미래 self | **아니오** | 미래 active same-crew 제한 | 필요하더라도 동일한 최소 범위 | 운영 정책상 제한 | **032 미포함** |
| professional evidence | 미래 신청자 제한 | **아니오** | 아니오 | 아니오 | 예 | **032 미포함** |

032에서는 현재 safe views/RPCs를 그대로 둔다. 새 두 user field는 table에는 존재하지만 public projection에는 아직 포함되지 않는다. public 노출은 Flutter와 DB 계약을 함께 버전 관리하는 후속 migration에서 수행한다.

---

## 9. Age and minor-user boundary

### 9.1 Conservative compatibility approach

- `users.birth_date`는 기존대로 `date not null`이며 self/private 원본이다.
- 032는 birth date constraint, `show_age`, age 계산식을 변경하지 않는다.
- public profile은 exact birth date를 반환하지 않는다.
- 기존 projection의 age는 `show_age = true`일 때 서버에서 계산된 정수만 반환한다.
- 향후 STAGE profile v2는 법률/제품 결정이 완료되기 전까지 exact age 대신 age band를 반환할 수 있다.
- age band도 DB가 birth date에서 계산해야 하며 client에 원본 date를 전달해 계산하게 하지 않는다.

### 9.2 Decisions that block production profile launch

다음은 032 schema foundation을 막지는 않지만, STAGE public profile/지원/메시지를 실제 출시하기 전 반드시 확정해야 한다.

- 최소 가입 연령
- 보호자 동의 필요 여부와 consent versioning
- 성인-미성년자 메시지 제한
- 미성년자의 crew 지원 및 offline 연습 안전 안내
- age 또는 age band의 공개 기본값
- exact location과 same-crew 공유 범위
- 신고 대응 기준과 운영 SLA

032는 guardian/parent 컬럼을 미리 만들지 않는다. 최종 정책 없이 nullable field를 추가하면 수집 근거와 보존 정책이 불명확해진다.

---

## 10. Backfill and seed plan

### 10.1 Preflight report

미래 SQL은 변경 전에 다음을 조회·검증하고 예상 밖 데이터가 있으면 transaction을 실패시켜야 한다.

1. 현재 `genres`의 row 수, ID, code, name, sort order, active 상태
2. 기존 code/name/sort order 중 신규 11개 seed와 충돌하는 값
3. 동일 code가 예상하지 않은 name/domain/category를 가진 경우
4. `user_genres`의 FK orphan 또는 중복 여부
5. 기존 `users`의 account status 분포
6. 기존 `experience_level`, `activity_frequency` 값 분포
7. 현재 public views/RPC의 반환 column signature
8. 032 컬럼이 일부만 존재하는 비정상 partial-apply 환경인지 여부

unique/FK/check가 이미 많은 이상을 막지만, 운영 DB에 SQL Editor hotfix가 있었을 가능성을 배제하지 않고 명시적으로 report한다.

### 10.2 Existing genre classification

- 기존 row의 ID/code/name/sort order/active 상태는 변경하지 않는다.
- 새 컬럼 추가 시 기존 row를 `band` / `legacy_music`으로 분류한다.
- 이름이 dance와 유사하다는 이유로 `hiphop_reggae`, `house_techno`, `jazz_fusion`의 domain을 dance로 바꾸지 않는다.
- 기존 `user_genres` row는 그대로 해당 기존 genre ID를 참조한다.
- 기존 사용자 선택을 신규 dance genre로 자동 복제하지 않는다.

### 10.3 Idempotent dance seed

권장 실행 의미:

- stable `code`를 conflict key로 사용한다.
- code가 없으면 신규 row를 삽입한다.
- code가 이미 있고 모든 immutable metadata가 예상값과 같으면 no-op으로 취급한다.
- code는 같지만 name/domain/category/sort order가 다르면 조용히 덮어쓰지 않고 실패·보고한다.
- name 또는 sort order가 다른 code에 이미 사용 중이면 실패·보고한다.
- 재실행 시 기존 seed ID는 유지된다.

Migration file은 보통 한 번만 적용하지만, SQL Editor 재실행이나 환경 복구 시 동작을 예측할 수 있어야 한다. “무조건 update” 방식보다 drift를 보고하는 방식이 taxonomy 운영 변경을 덮어쓰지 않아 안전하다.

### 10.4 User backfill/defaults

- 기존 사용자 `performance_domain`: **null 유지**
- 기존 사용자 `professional_state`: `general`
- 신규 사용자 `performance_domain`: 명시 선택 전 null
- 신규 사용자 `professional_state`: `general`
- `experience_level`, `activity_frequency`, `activity_days`, `bio`, `user_areas`, `user_genres`: 변경 없음

기존 사용자를 다음과 같이 추론하지 않는다.

- `user_parts`에 `dancer`가 있다고 dance domain으로 설정하지 않음
- genre 이름에 hiphop/house/jazz가 있다고 dance domain으로 설정하지 않음
- `experience_level = pro_oriented`라고 professional로 설정하지 않음
- `bio`, favorite artists, gear 또는 portfolio URL로 professional을 추론하지 않음

---

## 11. Constraint and index plan

### 11.1 Proposed constraints

| 대상 | constraint | 이유 |
|---|---|---|
| `genres.domain` | text check: `band`, `dance`; not null; default `band` | 기존 seed SQL과 legacy insert 호환, 명시적 domain |
| `genres.category` | text check: 승인된 category code; not null; default `legacy_music` | filter vocabulary drift 방지 |
| `users.performance_domain` | null 또는 `band`, `dance`, `multi_domain` | existing user null 호환, user domain 명확화 |
| `users.professional_state` | `general`, `professional_unverified`; not null; default `general` | self-declared와 일반 상태만 허용하고 verified 사칭 차단 |

PostgreSQL enum type은 만들지 않는다. repository convention인 `text + CHECK`를 사용한다.

### 11.2 Existing uniqueness

- `genres.code` unique 유지
- `genres.name` unique 유지
- `genres.sort_order` unique 유지
- `user_genres(user_id, genre_id)` unique 유지

새 taxonomy table이나 alias table은 만들지 않으므로 UUID PK/FK를 추가할 필요가 없다.

### 11.3 Index decision

032에서 새 index는 **0개**가 적절하다.

- `genres`는 기존 18개 + seed 11개의 작은 master table이다.
- 현재 legacy query는 `is_active` + `sort_order`이며 table scan 비용이 미미하다.
- STAGE query는 향후 `domain`, `is_active`, `sort_order`를 사용하지만 row 수가 작다.
- `user_genres_genre_idx`가 이미 genre 기반 membership/filter join을 지원한다.
- 현재 search RPC는 `performance_domain` 또는 `professional_state`로 filter하지 않는다.

향후 실제 query가 active user를 `performance_domain` 또는 verified professional로 대량 filter할 때 execution plan을 확인하고 partial/composite index를 별도 migration에 추가한다.

---

## 12. RLS, grants, triggers, and RPC impact

### 12.1 RLS and grants

032는 새 table/view/function을 만들지 않으므로 새 RLS policy나 grant가 필요 없다.

- `genres_read_active` 유지
- `master_data_admin_manage_genres` 유지
- `users_*` self/admin policies 유지
- `user_genres_*` policies 유지
- `public`, `anon`, `authenticated` 권한 변경 없음

inactive seed 전략 덕분에 `anon` master read 결과도 적용 전과 동일하다.

### 12.2 Triggers

- 기존 `set_updated_at` trigger가 `users`와 `genres`의 새 컬럼 update를 자동 처리한다.
- 새 trigger를 만들지 않는다.
- `protect_user_system_fields`는 032에서 변경하지 않는다.

`professional_state`에 verified 값이 없으므로 032 시점에는 system-field trigger에 추가할 필요가 없다. Migration 035가 `professional_verified`를 허용하는 순간에는 다음을 하나의 transaction으로 처리해야 한다.

1. check constraint 확장
2. 일반 사용자의 verified 전환/해제 차단
3. operator-only verification RPC
4. evidence/review audit
5. negative SQL test

### 12.3 RPC and safe projection

032는 새 self-update RPC나 safe profile RPC를 만들지 않는다.

이유:

- 현재 Flutter는 새 필드를 사용하지 않는다.
- 기존 RPC signature를 늘리면 DB 적용과 Flutter release 순서가 결합된다.
- 본인 row update는 기존 RLS로 안전하게 제한된다.
- public 노출은 STAGE profile UI와 함께 versioned RPC로 설계하는 편이 안전하다.

후속 권장 이름:

- `get_my_stage_profile`
- `update_my_stage_profile`
- `get_public_stage_profile`

위 함수는 032가 아니라 role/professional/public profile 요구가 확정된 후 추가한다.

### 12.4 PostgREST

미래 032는 마지막에 PostgREST schema reload notification을 포함한다. 이는 새 table column metadata 반영을 위한 것이며 RLS/grant 확대를 뜻하지 않는다.

---

## 13. Future dependency boundary

| migration | 032가 준비하는 것 | 032가 하지 않는 것 |
|---|---|---|
| 033 performance roles | user domain과 dance genre taxonomy 제공 | roles master와 user/group/recruitment joins 생성 안 함 |
| 034 private station | broad `user_areas`와 exact location의 경계를 명확히 유지 | station/master/private location/RPC 생성 안 함 |
| 035 professional verification | self-declared `professional_state` 기반 제공 | verified 값, evidence, review, operator audit 생성 안 함 |
| 036 events and sources | dance taxonomy를 event/lesson filter에 재사용 가능 | event/organizer/source/publish workflow 생성 안 함 |
| 038 recruitment/event/role integration | dance genre와 user domain을 recruitment v2에서 참조 가능 | post event FK, role slots, beginner-friendly 조건 생성 안 함 |

032는 이후 domain의 FK/table을 미리 당기지 않는다. 특히 roles, station, verification, event가 profile column 하나에 섞이지 않도록 경계를 유지한다.

---

## 14. Ordered future SQL outline

아래는 실행 SQL이 아니라 미래 파일의 순서와 실패/rollback 계약이다.

| 순서 | 섹션 | 목적 | transaction | 주요 실패 조건 | rollback/disable |
|---:|---|---|---|---|---|
| 1 | Preflight assertions | 현재 schema version, 18개 legacy genre identity, seed conflict, partial apply 감지 | transaction 시작 후 read/assert | 예상 밖 code/name/sort, 일부 컬럼만 존재, constraint drift | 오류로 전체 transaction 중단 |
| 2 | Additive `genres` extensions | domain/category 컬럼과 named check 추가 | 예 | 기존 데이터가 새 check를 만족하지 않음, 동일 이름 constraint drift | transaction rollback |
| 3 | Existing genre classification | legacy row를 band/legacy_music으로 명시 | 예 | 예상 legacy identity 불일치 | transaction rollback; ID/name을 수정하지 않음 |
| 4 | Dance seed | 11개 inactive row를 stable code로 삽입 | 예 | code/name/sort 충돌, 기존 row metadata drift | transaction rollback; 기존 row overwrite 금지 |
| 5 | Additive `users` extensions | performance domain과 2-state professional foundation 추가 | 예 | 동일 column의 type/default/check drift | transaction rollback |
| 6 | Constraint verification | null/default/allowed values 확인 | 예 | invalid row 또는 constraint 미적용 | transaction rollback |
| 7 | System-field protection decision | 032에서는 trigger definition no-change를 assert | 예 | 예상 `protect_user_system_fields` trigger가 없음 | transaction rollback 또는 사전 복구 요구 |
| 8 | Index decision | 새 index를 만들지 않았음을 명시 | 예 | 해당 없음 | 해당 없음 |
| 9 | RLS/grant decision | 기존 policy/grant no-change를 확인 | 예 | RLS disabled 또는 핵심 policy 누락 | transaction rollback, 별도 보안 복구 선행 |
| 10 | Verification queries/assertions | ID 불변, seed 수/상태, user defaults, signature 확인 | 예 | 어느 assertion이라도 불일치 | commit 금지 |
| 11 | PostgREST schema reload | 새 column metadata refresh | transaction 끝부분 | notification 자체는 데이터 변경 실패 원인이 아님 | 재-notify 가능 |
| 12 | Commit | 모든 변경을 원자적으로 확정 | 예 | preflight/DDL/verification 실패 | DB가 적용 전 상태로 유지 |

이미 적용 후 앱에서 문제가 발견되어도 신규 dance rows는 inactive이고 기존 RPC는 unchanged이므로 feature flag 또는 old Flutter release로 즉시 돌아갈 수 있다. 적용된 user/genre 컬럼을 급히 drop하지 않는다.

---

## 15. SQL verification plan

이 섹션은 미래 migration/QA에서 실행할 test 설계이며, 이 문서 작업에서는 실행하지 않는다.

### 15.1 Positive cases

1. **Legacy genre identity**
   - 적용 전후 기존 18개 row의 `id`, `code`, `name`, `sort_order`, `is_active`가 동일하다.
2. **Legacy classification**
   - 기존 row가 모두 `domain = band`, `category = legacy_music`이다.
3. **Seed count**
   - 정확히 11개의 `dance_*` code가 존재한다.
4. **Seed metadata**
   - 각 seed의 name/domain/category/sort가 사양 표와 일치한다.
5. **Safe rollout**
   - 11개 seed가 모두 inactive다.
   - active master-data query 결과가 적용 전과 동일하다.
6. **Current onboarding**
   - 기존 Flutter insert payload가 새 user row를 생성한다.
   - 결과는 `performance_domain = null`, `professional_state = general`이다.
7. **Existing self profile**
   - 기존 사용자의 self `users` read/update가 계속 동작한다.
8. **Current safe profiles**
   - `member_search_profiles`, `member_public_profile_details`, `search_member_profiles`, `get_my_page_profile`의 column signature와 결과 parsing이 유지된다.
9. **Genre joins**
   - 기존 `user_genres` row 수와 FK target이 동일하다.
10. **Legacy status**
    - active/suspended/withdrawn 사용자 수와 visibility가 변하지 않는다.
11. **Null compatibility**
    - 기존 Flutter models가 새 nullable field를 요청하지 않아 parsing error가 없다.
12. **Migration re-execution**
    - 동일 metadata 상태에서 두 번째 실행은 ID/row count를 변경하지 않는다.
13. **Legacy seed replay**
    - 002의 기존 genre upsert를 다시 실행해도 new column default/not-null 때문에 실패하지 않고 domain/category를 덮어쓰지 않는다.
14. **Schema cache**
    - reload 후 PostgREST가 새 column metadata를 인식한다.

### 15.2 Negative cases

1. `genres.domain`에 허용되지 않은 값을 저장하면 실패한다.
2. `genres.category`에 허용되지 않은 값을 저장하면 실패한다.
3. seed code/name/sort가 다른 row와 충돌하면 조용히 변경하지 않고 migration이 실패한다.
4. ordinary user가 자신의 `professional_state`를 `professional_verified`로 설정하면 check constraint로 실패한다.
5. ordinary user가 다른 사용자의 `performance_domain` 또는 `professional_state`를 update하면 RLS로 실패한다.
6. ordinary user가 account/system field를 함께 변경하려 하면 기존 trigger/RLS로 실패한다.
7. `anon`이 inactive dance seed를 active master query로 읽지 못한다.
8. authenticated non-owner가 full `users` row를 직접 읽지 못한다.
9. public safe projection에 email, phone, `auth_uid`, `phone_verified`, birth date, billing, admin field가 나타나지 않는다.
10. public safe projection에 exact station이나 professional evidence가 나타나지 않는다.
11. withdrawn/suspended profile이 현재 public search에 다시 나타나지 않는다.
12. invalid/nonexistent genre ID를 `user_genres`에 넣으면 FK로 실패한다.
13. legacy row가 존재하는 DB에서도 신규 not-null/default/check가 안전하게 적용된다.
14. RLS policy definition/count에 의도하지 않은 변경이 없다.
15. current master/profile/member/My Page Flutter test fixture가 추가 DB column 때문에 실패하지 않는다.

### 15.3 Recommended pre/post evidence

실제 implementation PR에서는 다음 결과를 artifact 또는 PR 설명에 기록한다.

- migration filename inventory (`001`–`032`)
- legacy genre identity checksum 또는 ordered export
- before/after genre counts와 active counts
- before/after `user_genres` counts
- account status별 user counts
- view/RPC signature snapshot
- policy/grant diff가 없다는 catalog query 결과
- ordinary authenticated user와 다른 사용자로 수행한 negative update 결과

---

## 16. Rollback and feature-disable approach

### 16.1 Before commit

032의 모든 DDL/backfill/seed/assertion은 하나의 transaction에서 수행한다. 실패하면 전체 rollback하며 partial schema를 남기지 않는다.

### 16.2 After migration is applied

문제가 생겼을 때 우선순위:

1. STAGE profile/taxonomy feature flag를 끈다.
2. 기존 Flutter와 기존 safe RPC/view를 계속 사용한다.
3. dance seed는 inactive 상태를 유지한다.
4. 새 user field를 읽거나 쓰는 STAGE route를 비활성화한다.
5. PostgREST cache만 문제라면 schema reload를 다시 수행한다.

신규 column 또는 seed row를 즉시 drop/delete하지 않는다. 이미 사용자가 값을 저장한 뒤 물리 rollback을 하면 데이터 손실이 생긴다.

### 16.3 Physical rollback

물리 drop은 다음 조건을 모두 만족할 때만 별도 승인 migration에서 고려한다.

- 신규 Flutter release가 아직 해당 컬럼을 사용하지 않음
- 모든 환경에서 user-written 값이 없음
- seed가 계속 inactive이고 참조 join row가 없음
- export/count가 기록됨
- 사용자가 명시적으로 승인함

그 외에는 additive schema를 유지하고 기능만 disable한다.

---

## 17. Decisions required from the user

| 번호 | 결정 | 권장안 | 032 구현 차단 |
|---:|---|---|---:|
| 1 | genre seed 수와 명칭 | 본 문서의 11개 | 예 |
| 2 | `STREET` 처리 | genre row 없이 `street` category | 예 |
| 3 | dance seed activation | 032에서는 전부 inactive, STAGE query 준비 후 별도 activation | 예 |
| 4 | category vocabulary | `legacy_music`, `commercial`, `street`, `jazz_contemporary`, `entertainment`, `other` | 예 |
| 5 | user domain values | nullable `band`, `dance`, `multi_domain` | 예 |
| 6 | professional foundation | 032는 `general`/`professional_unverified`, verified는 035 | 예 |
| 7 | experience model | 현재 `experience_level` 4값 재사용, `pro_oriented`는 인증과 무관 | 예 |
| 8 | desired participation style | `user_purposes` broad reuse, 세부 project/permanent 구분은 연기 | 아니오 |
| 9 | 최소 연령·보호자 정책 | 별도 제품/법률 결정 | 032는 아니지만 production profile launch는 차단 |
| 10 | CONTEMPORARY/THEME_PARK | 032에는 seed하지 않고 실제 데이터 요구 시 추가 | 아니오 |

---

## 18. Readiness recommendation

### 현재 판단

**조건부 준비 완료**다.

기술적 범위, compatibility, privacy, seed, constraint, rollout, rollback, verification 경계는 SQL 구현을 시작할 수 있을 만큼 구체적이다. 그러나 taxonomy와 professional state는 제품에 노출되는 안정 code이므로 Section 17의 1–7을 사용자 승인 없이 확정하면 안 된다.

### 승인 후 권장 다음 작업

다음 Codex 작업은 이 문서를 source of truth로 사용해 `032_stage_taxonomy_and_user_profile.sql` **한 파일만** 작성하는 것이다. 그 작업에서는:

- 적용 전 catalog assertion
- transaction
- additive columns
- drift-safe inactive seed
- no RLS/grant/RPC signature changes
- verification assertions
- PostgREST reload

까지만 구현하고 Flutter 변경은 별도 task로 유지한다.

---

## 19. No-change record for this specification task

이 문서 작성 작업에서는 다음을 수행하지 않는다.

- SQL migration 생성 또는 실행
- Supabase 변경
- 기존 migration `001`–`031` 수정
- Flutter source/model/service/screen/router 변경
- RLS/grant/RPC/trigger 변경
- dependency 변경
- commit 또는 push

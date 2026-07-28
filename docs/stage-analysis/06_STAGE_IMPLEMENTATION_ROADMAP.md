# STAGE 단계별 구현 로드맵

## 1. 원칙

- 안정 BandMatch 기능을 한 번에 교체하지 않는다.
- 한 task는 한 화면 flow 또는 한 DB capability로 제한한다.
- DB/RLS contract를 먼저 고정하고 Flutter는 safe projection/RPC만 사용한다.
- Web route/deep link를 설계하되 iOS navigation/back/file-picker 호환을 함께 확인한다.
- frontend collaborator는 권한·mutation 계약을 변경하지 않는다.

## Phase 0 — 기준선 보존

### 사용자 가치

회귀 시 돌아갈 수 있는 검증 가능한 기준선을 만든다.

### 범위

- `stage-redesign` 브랜치와 `031` 최신 migration 고정
- 현재 QA/권한/navigation 반환 계약 보존
- 이 `docs/stage-analysis` 세트 review

### 재사용/신규

- 기존 전체 app을 그대로 유지
- 신규 Flutter/DB 없음

### 테스트

`dart analyze`, `flutter test`, `flutter build web`, smoke QA, Supabase migration ledger 비교.

### 위험·exit criteria

- main 또는 `001`–`031` 수정이 없어야 한다.
- 7개 문서와 open decision owner가 합의되면 종료.

## Phase 1 — STAGE 시각 토큰과 navigation shell

### 사용자 가치

STAGE 브랜드와 5개 핵심 목적지가 일관되게 보인다.

### 화면

login/onboarding shell, `ホーム`, `クルー`, `ステージ`, `スタジオ`, `マイページ`, top notification/message.

### 재사용

`AuthGate`, auth screens, My Page, current notification/message entry, 공통 loading/error pattern.

### 신규 Flutter

- `StageDesignTokens`
- typed route constants
- `go_router` 기반 `StatefulShellRoute.indexedStack`
- branch별 placeholder/root와 unavailable/permission screen
- auth/profile-incomplete redirect + validated `next`

### DB/migration

원칙적으로 없음. taxonomy/profile 계획이 확정되면 `032` 설계만 별도 task로 시작.

### 테스트

- 5 tab stack retention/reselect
- browser URL/back/refresh/direct entry
- iOS back gesture 시나리오
- auth/profile redirect와 expired callback 회귀

### 위험·exit criteria

- 기존 기능 route를 잃지 않고 shell 뒤에서 열 수 있어야 한다.
- production route map과 deep-link allowlist가 test로 고정되어야 한다.

## Phase 2 — crew 발견·모집 core

### 사용자 가치

미소속 사용자가 이벤트 기반 crew를 찾고 개인 지원하며, leader가 승인할 수 있다.

### 화면

`home_a`, `crew_top`, filter, recruitment detail, application form/done, share, create, applicants/profile, My Apps.

### 재사용

public recruitment list/detail, post edit, application service/RPC, approval/member activation, group screens, profile/safety.

### 신규 Flutter

- STAGE recruitment card/filter
- event context 표시
- canonical recruitment deep link/share
- auth/onboarding 후 원 detail 복귀
- leader/applicant role-aware actions

### DB

`032`–`039`: taxonomy, roles, events, crew target history, recruitment linkage/projection.

### RLS/RPC

개별 지원, target event, block, active profile/group, leader 권한, duplicate pending을 DB에서 검증.

### 테스트

unregistered deep link, own group, member, former member, blocked, closed/expired post, repeated application, approval atomicity.

### exit criteria

“공개 모집 → 가입 → My Crew”가 mock state 없이 end-to-end 동작하고 legacy BandMatch 모집도 손실 없이 읽힌다.

## Phase 3 — crew 활동 관리

### 사용자 가치

crew가 LINE을 대체하지 않으면서 연습·출결·공지·자료·활동 이력을 한곳에서 관리한다.

### 화면

`home_b`, crew switcher/home/members, practice list/detail/create, poll, notices, resources, target event, archive.

### 재사용

group membership/admin, avatar/public profile, badge refresh pattern, external media URL pattern.

### 신규 Flutter

crew context provider/repository, practice/attendance/poll forms, announcement/resource UI, archive read-only mode.

### DB

`040`–`042`: practice/attendance, poll, announcements/resources/activity events.

### 테스트

leader/member/former member/non-member matrix, poll finalization race, attendance self-only, archived crew read-only, multiple crew switch.

### exit criteria

두 crew를 가진 사용자도 crew별 상태가 섞이지 않고, mutation 후 올바른 화면과 badge가 갱신된다.

## Phase 4 — Stage event와 lesson/workshop

### 사용자 가치

검증 가능한 이벤트/대회와 레슨을 찾고 관련 crew 모집으로 연결된다.

### 화면

Stage top, event list/filter/detail, lesson list/detail, external application.

### 재사용

recruitment card/detail, public profile/professional badge, block/report.

### 신규 Flutter

source/last-verified 표기, expired/unavailable state, external URL confirm, related crew route.

### DB

`035`, `036`, `043`, `047`: professional verification, events/source, lessons, moderation/audit.

### 테스트

draft/published/expired, malicious URL, unverified/verified professional badge, source stale state, operator-only mutation.

### exit criteria

사용자는 출처와 확인 시각을 알 수 있고, 미검수 수집 정보가 public에 노출되지 않는다.

## Phase 5 — Studio catalog와 recommendation

### 사용자 가치

Shinjuku studio를 조건/지도에서 찾고 외부 예약하며 crew 연습에 연결한다.

### 화면

Studio top, map/list/filter/detail, recommendation input/result, practice link.

### 재사용

areas/master fetch, practice create, external URL safety component.

### 신규 Flutter

map abstraction, studio cards/detail, external booking, recommendation criteria/result reason.

### DB

`034`, `044`, `045`: station privacy, studio catalog/access/facilities, recommendation.

### 테스트

non-member denial, member private station visibility, result에 station leak 없음, external API timeout/fallback, Shinjuku data quality.

### 위험

map/route API dependency, cost, API key, privacy, iOS permission 오해. MVP에서는 기기 GPS 권한이 필요하지 않다.

### exit criteria

근사 방식으로도 end-to-end 결과를 만들 수 있고, route API는 method adapter 뒤에 교체 가능해야 한다.

## Phase 6 — safety/privacy hardening과 release

### 사용자 가치

미성년자와 offline meeting이 있는 서비스에서 예측 가능한 안전/권한/복구를 제공한다.

### 범위

- age/minor 정책 반영
- exact station RLS/감사
- blocked chat/request hardening
- notification/badge v2
- deep link/404/permission/closed content
- responsive Web와 iOS device validation

### DB

`046`–`049`; `050` cleanup은 별도 승인 이후.

### 테스트

- role×status×block 권한 matrix
- direct RPC negative test
- Web refresh/back/deep link
- iOS cold start/app link/back gesture/image picker
- accessibility, text scale, narrow width
- migration upgrade snapshot과 legacy data regression

### exit criteria

P0/P1 QA 0건, private station/public field schema test 통과, Web/iOS critical flow 통과, rollback runbook review.

## 2. 권장 Codex task 단위

좋은 task 예:

1. “STAGE design token만 추가하고 app 동작은 feature flag로 유지”
2. “5-tab shell과 placeholder route만 구현”
3. “recruitment canonical route/deep-link read-only만 구현”
4. “`036` event safe read model만 migration+service+test”
5. “crew practice read-only list만 구현”
6. “attendance self upsert RPC와 한 화면만 구현”

피해야 할 task:

- “STAGE 전체 구현”
- 여러 migration/domain과 UI를 한 PR에 혼합
- UI redesign과 RLS signature 변경을 동시 수행
- legacy cleanup을 기능 cutover와 동시 수행

각 task handoff에는 변경 파일, SQL 적용 순서, positive/negative test, rollback, 하지 않은 범위를 명시한다.

## 3. 프런트엔드 협업 분담

### primary developer

- schema/migration/RLS/RPC
- service/model
- AuthGate/router redirect
- permission/role/closed/archive state
- approval/finalize/safety mutation
- unread/badge invalidation
- nearest-station/recommendation privacy

### UI collaborator

- token/typography/color/spacing/radius
- shell, responsive layout
- pure presentation card/chip/section
- loading/empty/error skeleton
- event/lesson/studio/recruitment list visual

### 공동 review가 필요한 화면

applicant approval, group member removal/leave, profile private station, recommendation, message unread, notification, blocked/report, external URL, auth/deep link.

UI component는 callback/data object를 주입받고 내부에서 Supabase를 직접 호출하지 않는 것이 안전하다.

## 4. test strategy

### 단위

- model parsing/null/unknown enum
- URL allowlist
- route redirect
- role/status action resolver
- age/public field formatting
- recommendation score adapter

### widget

- home_a/home_b와 crew switch
- tab stack/reselect
- loading/empty/error
- leader/member CTA 차이
- archived/closed/unavailable
- Japanese text narrow width

### DB/RLS

- owner/member/former member/non-member/admin
- blocked 양방향
- suspended/withdrawn
- self vs other station
- pending/accepted/rejected/closed
- direct table/RPC attacks

### integration/manual

- shared recruitment link → auth → onboarding → same detail
- individual apply → leader accept → crew home
- poll → final practice → attendance
- event/lesson external link
- studio recommend → detail → practice
- leave/remove/archive 후 access

## 5. iOS validation timing

- Phase 1: route/back/text scale 최소 device smoke
- Phase 2: universal/app link와 auth callback
- Phase 3: lifecycle resume 및 form keyboard
- Phase 4/5: external URL, map SDK/permission, avatar picker
- Phase 6: full device matrix와 cold start

Web 완성 뒤 한 번에 iOS를 확인하면 route/link/file picker 문제가 누적되므로 각 phase 종료 때 최소 검증한다.

## 6. 첫 실제 구현 task 권장

**단 하나의 첫 task:** 기존 BandMatch route를 그대로 유지한 채, compile-time preview flag 뒤에 `StageDesignTokens`와 데이터 호출 없는 5-tab `StageShellPreview`를 추가한다.

포함:

- STAGE brand/color/type/spacing token
- `ホーム/クルー/ステージ/スタジオ/マイページ` placeholder
- active tab과 좁은 Web/mobile layout widget test

제외:

- Supabase/migration
- 기존 AuthGate redirect 교체
- 실제 screen/data 연결
- deep link와 mutation

이렇게 하면 시각 협업을 시작하면서 현재 MVP 동작을 위험에 노출하지 않는다.


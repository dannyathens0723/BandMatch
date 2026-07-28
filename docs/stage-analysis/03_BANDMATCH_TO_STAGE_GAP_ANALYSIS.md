# BandMatch → STAGE 갭 분석

## 1. 요약

STAGE는 BandMatch를 전부 버리고 다시 만드는 프로젝트가 아니다. 현재의 인증, 안전한 profile projection, 그룹/모집/지원, 멤버십 권한, 1:1 문의/채팅, 차단/신고는 높은 재사용 가치가 있다.

가장 큰 차이는 다음 네 영역이다.

1. 홈과 내비게이션: 단일 기능 launcher → role/crew 상태 기반 5-tab shell
2. 그룹: 일반 밴드 그룹 → 이벤트 목표와 활동 이력을 가진 クルー
3. 운영 기능: 연습, poll, 출결, 공지, 자료, archive
4. 신규 catalog: 이벤트/대회, 레슨/워크숍, 스튜디오/추천

## 2. 화면별 재사용 분류

| 현재 Flutter 화면 | 분류 | STAGE 대응과 필요한 변경 |
|---|---|---|
| `AuthScreen` | 시각/copy 변경 후 재사용 | magic link/password/session 방어 재사용. LINE/Apple provider는 별도 결정/구현 |
| `PasswordResetDialog` | 대부분 그대로 재사용 | STAGE styling/copy만 변경 |
| `PasswordSetupScreen` | 대부분 그대로 재사용 | recovery callback 계약 보존 |
| `ProfileSetupScreen` | data-model 변경 후 재사용 | dance 경험/역할, 최寄駅, 연령 안전, professional 상태 추가 |
| `HomeScreen` | 대규모 refactor | `home_a`/`home_b`, crew switcher, 현재 활동 요약, 5-tab shell로 교체 |
| `MyPageScreen` | 시각/copy 변경 후 재사용 | STAGE My Page 항목으로 재배치; 현재 reload/logout 계약 보존 |
| `ProfileEditScreen` | data-model 변경 후 재사용 | public area와 private station 분리, professional 표시, 외부 URL portfolio |
| `MemberListScreen` | 교체 후 deprecate 후보 | 일반 멤버 browse는 STAGE 핵심이 아님. leader/applicant 탐색용으로 제한하거나 제거 |
| `MemberDetailScreen` | data-model 변경 후 재사용 | leader/applicant/public profile 공통 화면으로 전환; safety action 보존 |
| `ReceivedMessageRequestsScreen` | 제품 결정 필요 | 모집 문의 승인형 DM을 계속 쓸지 결정. STAGE prototype은 모집 문의 thread를 보여줌 |
| `ChatRoomsScreen` | 시각/copy 변경 후 재사용 | 상단 메시지 icon 경로, low-frequency inquiry 용도 명확화 |
| `ChatRoomScreen` | 시각/copy 변경 후 재사용 | 참가자/RLS/unread 로직 보존. LINE 대체 group chat으로 확장하지 않음 |
| `MyGroupsScreen` | data-model 변경 후 재사용 | `マイクルー`; current target/event/archive/activity 상태 표시 |
| `GroupEditScreen` | 대규모 refactor | crew 생성과 event-target recruitment 흐름을 분리/연결 |
| `GroupMembersScreen` | data-model 변경 후 재사용 | `クルーメンバー`; active membership, leader action, station privacy-aware projection |
| `RecruitmentPostsScreen` | data-model 변경 후 재사용 | event 연결, publish/close 상태, applicant badge |
| `RecruitmentPostEditScreen` | data-model 변경 후 재사용 | target event 선택, dance role/level/cost/date 조건, shareable URL |
| `RecruitmentApplicationsScreen` | 시각/copy 변경 후 재사용 | 개인 지원/승인/거절 atomicity와 role guard 보존 |
| `PublicRecruitmentPostsScreen` | data-model 변경 후 재사용 | STAGE `クルー` 찾기, event/genre/level/period/cost filter |
| `PublicRecruitmentPostDetailScreen` | data-model 변경 후 재사용 | target event, leader profile, share/deep link, inquiry context |
| `BlockedUsersScreen` | 대부분 그대로 재사용 | My Page 49 대응; unblock 계약 보존 |

### 새 구현이 필요한 STAGE 화면

- 5-tab shell과 독립 tab stack
- 미소속/소속 home, multiple crew switcher
- crew home
- practice list/detail/create, attendance
- schedule poll/options/responses
- announcement list/detail/create
- crew resources, song/reference/practice-video URL form
- target event와 past activity archive
- Stage top, event list/filter/detail
- lesson/workshop list/detail
- Studio top, map/list/filter/detail
- crew studio recommendation input/result
- notification list/settings와 support/legal individual routes

## 3. 기능 재사용 분류

| 기능 | 분류 | 근거 |
|---|---|---|
| Auth/session/recovery | 유지·확장 | Web callback 방어와 profile gate가 안정적 |
| 안전한 public profile | 유지·확장 | private `users` 대신 view/RPC projection 패턴이 적합 |
| master data fetch | 유지·확장 | `areas`, `genres` 사용 가능; dance role은 새 master 권장 |
| 멤버 검색 | 대체 후 축소 | STAGE의 첫 CTA는 사람보다 crew recruitment |
| 메시지 요청 | 제품 결정 후 재사용 | 일반 DM 승인 gate는 안전하지만 recruitment inquiry UX와 중복 가능 |
| 1:1 chat/unread | 유지·시각 변경 | 문의/승인 후 대화에 적합, group activity chat은 scope 밖 |
| 그룹 생성/멤버십 | 유지·확장 | `groups`/`group_members`를 crew technical base로 사용 |
| 그룹 탈퇴/제외 이력 | 유지 | STAGE crew lifecycle에도 필요 |
| 모집 글/개인 지원 | 높은 재사용 | 고정된 “개별 지원” 요구와 현재 모델이 일치 |
| 승인 시 멤버 활성화 | 유지 | 현재 atomic RPC 구조 재사용 |
| avatar/외부 media URL | 유지·확장 | full video storage 금지 요구와 `media_portfolios` 방향이 일치 |
| 차단/신고 | 유지·확장 | offline meeting/미성년자 도메인에서 더 중요 |
| badge RPC | 분리/확장 | 현재 request/application/chat + STAGE action counts 필요 |
| practice/poll/attendance | 신규 | 현재 DB/Flutter에 없음 |
| announcements/resources | 신규 | `notifications`/`media_portfolios`와 목적이 달라 별도 entity 필요 |
| events/lessons | 신규 | catalog, source 검증, 운영자 review 필요 |
| studios/recommendation | 신규 | 위치/설비/외부 예약/민감 station 계산 필요 |

## 4. 용어 전환

| BandMatch 기술/화면 용어 | STAGE UI 용어 | 권장 기술 처리 |
|---|---|---|
| BandMatch | STAGE | app-level brand 변경; DB rename 불필요 |
| group/band | クルー | `groups`를 당분간 유지하고 UI/model alias 사용 |
| member search | クルーを探す | home primary CTA를 recruitment로 변경 |
| part/instrument | ダンス役割/募集枠 | 기존 `parts` 의미를 덮지 말고 새 performance-role master |
| genre | ジャンル | `genres`에 domain/category를 추가해 재사용 |
| area | 活動エリア | 현재 broad public area 유지 |
| message request | 問い合わせ/メッセージ開始 | 제품 범위를 정한 뒤 copy 변경 |
| group recruitment | クルー募集 | target event 연결 추가 |
| joined/admin group | 参加中/管理中のクルー | membership role/status 유지 |

`groups`를 즉시 DB에서 `crews`로 rename하면 모든 FK, RLS, RPC, Flutter service가 동시에 깨진다. 기술명은 compatibility period 동안 유지하는 것이 안전하다.

## 5. 기존 개념별 STAGE mapping 결정

| 기존 개념 | 권장 | 대안 | 이유·영향 |
|---|---|---|---|
| `users` | 유지·확장 | `stage_users` 신규 | auth/self-RLS와 데이터 보존. 신규 table은 동기화 위험 |
| `parts`/instrument joins | legacy 유지 + `performance_roles` 신규 | `parts`를 generic role로 의미 변경 | 밴드 확장을 보존하면서 dance 역할을 명확히 함. Flutter filter 교체 필요 |
| `genres` | `domain`, `category` 추가 후 재사용 | dance 전용 master | K-POP/HIPHOP/JAZZ와 미래 band를 한 taxonomy로 관리. seed/backfill 필요 |
| `areas` | broad activity area로 유지 | 외부 행정 master 교체 | 현재 public projection 재사용. exact station과 절대 혼합하지 않음 |
| `groups` | technical name 유지·확장 | 물리 rename `crews` | migration risk 최소. UI/model에서 Crew로 표현 |
| `group_members` | 유지·확장 | `crew_members` 신규 | role/status/history가 이미 존재. nearest-station 조회 권한의 기준 |
| `recruitment_posts` | target event FK/조건 확장 | event별 별도 post table | 현재 application/RPC 재사용. open post는 원칙적으로 event 필요 |
| `recruitment_applications` | 유지 | 신규 application domain | 개인 지원/승인/member upsert가 고정 요구와 일치 |
| message request/room/messages | inquiry/1:1로 유지 | recruitment별 comment thread | 검증된 안전/RLS 재사용. STAGE가 LINE 대체 group chat이 되지 않게 범위 제한 |
| `blocks`/`reports` | 유지·content target 확장 | 신규 moderation schema | user safety 기반은 유지; event/lesson/studio 신고는 확장 필요 |
| `notifications` | delivery inbox로 확장 | activity log와 통합 | 알림과 crew archive/audit는 수명·권한이 달라 분리 권장 |
| badge RPC | 기존 RPC 확장 또는 domain RPC 합성 | 하나의 거대 query | shell badge는 aggregation API가 필요하나 domain별 timeout/권한을 분리해야 함 |
| safe profile views/RPC | 유지·버전 확장 | full `users` select | private field 노출 방지 패턴을 유지 |

## 6. 이벤트와 crew lifecycle

권장 관계:

```text
groups(crew)
  ├─ crew_event_targets ── stage_events
  ├─ recruitment_posts ─── stage_events
  └─ practices / polls / announcements / resources
```

- crew는 event 종료 후에도 존재한다.
- `crew_event_targets`는 과거/현재 목표의 history이다.
- 한 crew의 active target은 동시에 하나로 제한하는 partial unique index가 적합하다.
- recruitment post는 생성 시 target event를 참조하고, draft 동안만 임시 null을 허용할 수 있다.
- event 종료 시 post를 자동 삭제하지 않는다. open 여부를 close하고 detail/history는 읽기 전용으로 유지한다.
- crew가 다음 target을 선택하면 새 history row를 추가하고 이전 row를 completed/archive 처리한다.

`groups.current_event_id`만 두는 대안은 단순하지만 past event history와 당시 활동 자료 연결을 잃으므로 권장하지 않는다.

## 7. 프로필·최寄駅·professional gap

현재 profile은 broad `user_areas`와 음악 중심 `parts`, `experience_level`을 가진다. STAGE에 필요한 추가점:

- public dance genre/role/experience/availability
- private nearest station
- broad activity area와 exact station의 명확한 분리
- general / professional-unverified / operator-verified 상태
- professional verification 신청/검토 audit
- 외부 performance video URL

exact station은 `users`, `user_areas`, public profile view에 추가하면 안 된다. 별도 sensitive table과 SECURITY DEFINER RPC를 사용하고:

- 본인은 읽기/수정 가능
- active same-crew member만 필요한 범위에서 읽기 가능
- public/모집/일반 member search는 broad area만 반환
- recommendation RPC는 계산에 사용하되 결과에 개인 station을 반환하지 않음

## 8. 내비게이션 gap

현재 `MaterialPageRoute` push 방식은 다음을 지원하지 않는다.

- bottom tab별 stack retention
- canonical Web URL
- browser back/deep link
- auth 후 원래 공개 content 복귀
- unavailable/permission route

권장 방향은 `go_router` + `StatefulShellRoute.indexedStack`이다. router redirect는 세 단계로 고정한다.

1. session 없음 → login, validated `next` 저장
2. session 있음 + profile incomplete → onboarding, `next` 유지
3. session + profile complete → 원래 canonical route 또는 role-safe fallback

현재 mutation 화면의 result/reload 계약은 route-level refresh signal 또는 repository invalidation으로 옮기되 기능별로 명시적으로 보존한다.

## 9. 안전·프라이버시 gap

### MVP 필수

- birth date를 public에 반환하지 않고 age/age band만 공개
- minor/adult interaction 안내와 신고/차단의 항상 접근 가능한 경로
- organizer/source URL/last verified date
- 외부 URL domain 표시와 경고
- exact station 격리
- active same-crew 확인을 RPC와 RLS 양쪽에서 수행
- leader/operator identity와 professional verification 표시를 구분
- soft close/archive와 audit timestamp

### 별도 보안 fix가 필요한 현재 발견 사항

1. **중간 심각도: 차단 후 과거 chat 직접 조회**
   - `my_chat_rooms`는 차단 방을 숨기고 `send_room_message`는 차단 시 전송을 막는다.
   - `get_room_messages`는 accepted room의 active participant를 검사하지만 차단 관계를 별도로 검사하지 않는다.
   - room ID를 아는 차단 당사자가 직접 RPC를 호출하면 과거 메시지 조회가 가능할 수 있다.
   - 정책 결정 후 별도 최소 범위 migration/RPC fix가 필요하다. 이 문서 작업에서 수정하지 않는다.

2. **중간 심각도: 차단 전 pending message request의 직접 승인**
   - 최종 `accept_message_request`는 receiver/active party를 확인하지만 현재 정의에는 block 재검사가 없다.
   - UI inbox projection에서는 차단 sender가 숨겨질 수 있으나 알려진 request ID 직접 RPC는 별도 검증이 필요하다.
   - acceptance 시점 block check를 추가하는 별도 보안 task를 권장한다.

### 법률/제품 결정 필요

- 서비스 최소 연령과 보호자 동의
- minor profile/DM/오프라인 모임 제한
- 신고 SLA와 긴급 대응
- organizer/professional verification 증거 보관 기간
- AI 수집 event/lesson 정보의 고지와 정정 절차

## 10. 주요 migration/data-loss risk

| 위험 | 수준 | 대응 |
|---|---|---|
| `groups` 물리 rename | 높음 | UI alias 후 매우 늦은 cleanup |
| `parts` 의미 덮어쓰기 | 높음 | 신규 role master + explicit mapping |
| 기존 recruitment에 event 강제 | 높음 | nullable compatibility → backfill → validation → constraint |
| station을 public profile에 추가 | 매우 높음 | sensitive table/RPC로 격리 |
| notification과 activity archive 통합 | 중간 | 서로 다른 table 유지 |
| 새 shell 한 번에 교체 | 높음 | feature flag/branch별 migration |
| 기존 URL 없는 상태에서 deep link 도입 | 중간 | canonical path와 redirect test 먼저 |
| event/lesson 자동 수집 publish | 높음 | draft/review/source/last-verified 필드 강제 |

## 11. 프런트엔드 협업 경계

### UI 협업자가 안전하게 맡기 좋은 범위

- design token, typography, spacing, radius, color
- static card/list/empty/loading/error component
- recruitment/event/lesson/studio card presentation
- responsive layout와 tablet/desktop constraints
- shell tab icon/label의 시각 표현

### primary developer가 소유해야 하는 민감 범위

- AuthGate/router redirect/deep link resume
- approval/rejection/member upsert
- role/permission에 따른 CTA
- unread/badge invalidation
- block/report
- nearest-station 조회와 recommendation data
- leader-only create/edit/remove
- archive/closed/unavailable state
- 모든 Supabase service/model/RPC contract

UI PR은 service/RPC 호출과 Navigator/router result 계약을 변경하지 않는 것이 기본 규칙이다.


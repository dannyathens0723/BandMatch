# STAGE 후속 마이그레이션 순서

## 1. 불변 기준

- 현재 적용 기준은 `031_unread_chat_message_counts.sql`이다.
- `001`–`031`은 수정, rename, squash하지 않는다.
- `011_rollback_chat_feature.sql`도 적용 이력의 일부이므로 삭제/재번호화하지 않는다.
- 아래 파일명/번호는 제안이며 이 문서 작업에서는 생성하거나 실행하지 않는다.
- 각 migration은 가능한 한 additive해야 한다. Flutter cutover와 backfill 검증 전 legacy column/table을 drop하지 않는다.

## 2. 제안 순서

| 번호/제안 파일 | 목적 | 선행 조건 | backfill·호환성 | rollback 고려 |
|---|---|---|---|---|
| `032_stage_taxonomy_and_user_profile.sql` | `genres` domain/category, STAGE user public profile 필드, dance seed | 제품 taxonomy code | 기존 genre는 `band/legacy`로 명시; 신규 column nullable/default | seed/column을 즉시 drop하지 않고 app flag off |
| `033_performance_roles.sql` | `performance_roles`, user/group/recruitment role join | 032 | 기존 `parts`는 보존; 확실한 mapping만 backfill | 신규 read path만 비활성화 |
| `034_private_station_foundation.sql` | station master, line/access join, `user_private_locations`, self RPC | station source/provider 결정 | `user_areas`는 broad area로 유지; exact station 없는 사용자는 null | sensitive table은 데이터 존재 후 drop 금지; grant 철회로 기능 중지 |
| `035_professional_verification.sql` | 3단계 public state와 verification audit | evidence/운영 workflow 결정 | 기존 사용자는 `general`; verified 자동 backfill 금지 | public badge 비노출로 기능 중지 |
| `036_stage_events_and_sources.sql` | organizer, event, source/review/last-verified | status/taxonomy 결정 | legacy recruitment와 아직 연결하지 않음 | published flag off; catalog 보존 |
| `037_crew_event_target_history.sql` | `crew_event_targets`, active target uniqueness, archive metadata | 036 | 기존 group은 target 없음 허용; 관리자 선택 후 채움 | active target clear RPC 제공, history delete 금지 |
| `038_recruitment_event_and_roles.sql` | post→event, 새 role 조건, safe public projection/RPC v2 | 033, 036, 037 | 기존 post는 nullable event로 호환; open 신규 post부터 event 요구 | old RPC/view 유지하며 v2 flag off |
| `039_recruitment_backfill_validation.sql` | event/role backfill 검증, 신규 open-post constraint | 038 + 운영 backfill 완료 | orphan report가 0일 때만 validate | constraint `NOT VALID`/validation 단계 분리 |
| `040_crew_practices_and_attendance.sql` | practices, attendance, studio nullable link | 037 | 기존 데이터 없음; additive | status로 비활성화, 행 보존 |
| `041_schedule_polls.sql` | poll/options/responses/finalize RPC | 040 | finalized option→practice link는 transaction | finalize function 교체 rollback, data 보존 |
| `042_crew_announcements_and_resources.sql` | 공지, 외부 song/reference/practice video URL, activity events | 037 | full video migration 없음; URL만 | hide/archive, hard delete 금지 |
| `043_lessons_workshops.sql` | lesson/workshop catalog, instructor/organizer/source review | 035, 036의 source pattern | imported row는 draft/review | publish off |
| `044_studio_catalog.sql` | studio, room, facility, station access, external booking | 034 | Shinjuku seed source/version 기록 | inactive 처리, seed 삭제 금지 |
| `045_studio_recommendation.sql` | criteria/run/result, private calculation RPC, method/version | 034, 044 | raw station을 결과에 복제하지 않음 | execute revoke/feature flag off |
| `046_stage_notifications_and_badges.sql` | STAGE action notification type, tab badge aggregation | 038–045의 action 정의 | 기존 3개 badge field 유지; 새 v2 응답/optional parsing | old `get_my_badge_counts` 유지 |
| `047_content_safety_and_audit.sql` | event/lesson/studio/content report, operator audit, expiry review | 036, 043, 044 | 기존 `reports` 보존; 명확한 target migration만 | moderation row 보존 |
| `048_stage_safe_projection_hardening.sql` | public/member/leader projection, station/RLS negative path, block consistency | 모든 domain | Flutter cutover 전에 새 RPC 계약 고정 | legacy safe views 유지 |
| `049_stage_backfill_and_constraint_validation.sql` | FK/status/not-null validation, 데이터 품질 보고 | cutover와 QA 완료 | validation-only 단계; 실패 row report | 실패 시 transaction rollback |
| `050_legacy_cleanup_after_cutover.sql` | 사용 중지된 part joins/view/RPC cleanup 후보 | 최소 한 release 호환 기간 + telemetry/QA | export/backup 및 zero-call 확인 | 가장 위험; 별도 승인, 필요 없으면 실행하지 않음 |

번호는 migration 작업을 실제로 시작할 때 repository의 최신 번호를 다시 확인하여 조정한다.

## 3. dependency graph

```text
032 taxonomy/profile
 ├─ 033 performance roles ──────────────┐
 ├─ 034 private stations ── 044 studios ├─ 045 recommendation
 └─ 035 professional ────── 043 lessons │

036 events ── 037 crew target history ── 038 recruitment v2 ── 039 validation
                         ├─ 040 practices ── 041 polls
                         └─ 042 announcements/resources

038–045 ── 046 notifications/badges
036/043/044 ── 047 content safety/audit
all domains ── 048 projection/RLS hardening ── 049 validation ── 050 optional cleanup
```

## 4. compatibility period

각 domain은 다음 순서를 따른다.

1. 새 table/nullable column/RPC v2 추가
2. 기존 Flutter와 기존 RPC를 그대로 유지
3. deterministic한 row만 backfill
4. backfill audit query와 count 비교
5. 새 Flutter path를 feature flag 또는 작은 화면 단위로 전환
6. Web/iOS/RLS negative QA
7. 한 release 이상 legacy read 유지
8. 호출 0과 data export를 확인한 뒤 cleanup을 별도 승인

### 모집 예시

- `recruitment_posts.target_event_id`를 처음부터 `NOT NULL`로 만들지 않는다.
- 기존 post는 `legacy/unlinked`로 계속 읽을 수 있어야 한다.
- 신규 STAGE open post는 RPC에서 event를 요구한다.
- event가 없는 legacy post를 사용자/운영자가 연결하도록 한다.
- 모든 active post가 연결된 뒤 constraint를 validate한다.

### role 예시

- `parts` name을 dance role로 일괄 치환하지 않는다.
- 새 `performance_roles`를 seed한다.
- legacy part가 명확히 같은 의미일 때만 mapping row를 둔다.
- Flutter가 신규 role join으로 전환된 후 legacy join은 read-only compatibility가 된다.

## 5. transaction과 RPC 경계

다음 작업은 여러 write가 함께 성공해야 하므로 SECURITY DEFINER RPC가 적합하다.

- crew 생성 + creator active admin membership + initial target event
- recruitment publish + target/role/area validation
- application approval + membership activation
- target event 종료 + history archive + 다음 target 활성화
- schedule poll finalize + practice 생성/연결
- attendance self upsert
- professional/operator verification
- recommendation run + ranked result 생성

함수는 `search_path = public, pg_temp`, schema-qualified table, current user/role/status/block 검사를 사용하고 최소 필드만 반환한다.

## 6. backfill 체크리스트

- source/target row count와 orphan count 기록
- 중복 role/genre/active target 확인
- existing active group/admin membership 확인
- 기존 open recruitment 중 event 연결 불가능 row 목록
- station normalization 실패/중복 station code 목록
- professional verified를 추론하지 않았는지 확인
- private station이 public view/RPC에 포함되지 않는지 schema test
- legacy/post-v2 결과가 compatibility period 동안 같은 사용자에게 일관적인지 확인

## 7. RLS·grant 순서

한 migration 안에서 신규 table을 만들 때:

1. table 생성
2. RLS enable
3. index/FK/check
4. owner/self/member/operator helper 또는 RPC
5. 최소 policy
6. `public, anon` revoke
7. 필요한 `authenticated` execute/select만 grant
8. `notify pgrst, 'reload schema'`
9. SQL-level positive/negative test 계획 기록

station/verification evidence는 authenticated에도 direct table select를 grant하지 않는다.

## 8. rollback 원칙

- 이미 저장된 user/crew/activity data를 rollback 명목으로 삭제하지 않는다.
- 문제가 생기면 feature flag, publish status, execute grant, Flutter route를 먼저 되돌린다.
- function/view는 이전 signature와 호환되게 교체하거나 v2 이름으로 병행한다.
- irreversible backfill 전에 export/count/checksum을 기록한다.
- cleanup migration은 기능 migration과 같은 PR에 넣지 않는다.
- Supabase SQL Editor에서 임시 hotfix를 실행했다면 repository migration으로 즉시 기록하고 환경별 적용 순서를 맞춘다.

## 9. 별도 선행 보안 migration 후보

STAGE 신규 기능과 섞지 않고 작은 보안 작업으로 먼저 검토할 수 있다.

- blocked relationship인 기존 room의 `get_room_messages` 정책
- block 이후 과거 pending `accept_message_request` 직접 호출

이 두 항목은 데이터 모델 migration과 별개로 재현 test와 제품 정책을 먼저 확정해야 한다.


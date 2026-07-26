# BandMatch 권한 매트릭스

최종 점검일: 2026-07-26

기준 마이그레이션: 001–031

## 1. 읽는 방법

이 표는 현재 저장소의 RLS, view, RPC, Flutter 서비스 호출을 기준으로 한다.
실제 배포 프로젝트에 마이그레이션이 모두 적용되었는지는 별도 확인이 필요하다.

표시:

- `허용`: 코드 또는 SQL에서 직접 허용 확인
- `조건부 허용`: 대상 상태, 관계, 리소스 소속 조건을 만족할 때만 허용
- `거부`: 코드 또는 SQL에서 직접 거부 확인
- `관리자만`: 대상 그룹의 active `admin`만 허용
- `활성 멤버만`: 대상 그룹/방의 active member/participant만 허용
- `연기`: 기능이 사용자 흐름에 아직 없음
- `확인 필요`: 코드만으로 사용자 경험 전체를 확정하기 어렵거나 수동 검증 필요
- `(추론)`: 여러 조건을 조합해 도출했으며 전용 테스트로 확인해야 함

## 2. 역할·상태 정의

| 약어 | 역할/상태 | 이 문서의 가정 |
|---|---|---|
| G | Guest | Supabase 세션 없음 |
| U | Authenticated profile | `public.users.account_status = active`인 일반 로그인 사용자 |
| A | Member A | A→C 메시지 요청을 보내는 사용자 |
| C | Member C | A의 요청을 받는 사용자 |
| GA | Group owner/admin | 대상 그룹의 active `group_members.role = admin` |
| GM | Regular group member | 대상 그룹의 active `role = member` |
| NM | Non-member | 대상 그룹의 active 멤버가 아님 |
| BR | Blocker | 상대를 차단한 사용자 |
| BD | Blocked user | 상대에게 차단된 사용자 |
| FM | Left/removed former member | `membership_status = left` 또는 `removed` |

역할은 서로 배타적이지 않다. 예를 들어 A가 동시에 GA일 수 있다. 표의 A/C는
메시지 요청 시나리오, GA/GM/NM/FM은 대상 그룹 시나리오를 강조한다.

## 3. 전체 권한표

| # | Action | G | U | A | C | GA | GM | NM | BR | BD | FM |
|---:|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 멤버 목록 보기 | 거부 | 허용 | 허용 | 허용 | 허용 | 허용 | 허용 | 상대는 거부 | 상대는 거부 | 허용 |
| 2 | 멤버 상세 보기 | 거부 | 허용 | 허용 | 허용 | 허용 | 허용 | 허용 | 상대는 거부 | 상대는 거부 | 허용 |
| 3 | 메시지 요청 보내기 | 거부 | 조건부 허용 | 발송 후 거부 | incoming이면 거부 | 조건부 허용 | 조건부 허용 | 조건부 허용 | 거부 | 거부 | 조건부 허용 |
| 4 | 요청 승인/거절 | 거부 | 수신자만 | 거부 | pending 수신자면 허용 | 수신자일 때만 | 수신자일 때만 | 수신자일 때만 | 차단 전 요청은 확인 필요 | 차단 전 요청은 확인 필요 | 수신자일 때만 |
| 5 | 채팅 메시지 보내기 | 거부 | 조건부 허용 | 방 참가자면 허용 | 방 참가자면 허용 | 1:1 방 참가자면 허용 | 1:1 방 참가자면 허용 | 거부 | 상대 방은 거부 | 상대 방은 거부 | 방 active 참가자 여부에 따름 |
| 6 | 채팅방 보기 | 거부 | 활성 멤버만 | 방 참가자면 허용 | 방 참가자면 허용 | 1:1 방 참가자면 허용 | 1:1 방 참가자면 허용 | 거부 | UI 목록 거부 | UI 목록 거부 | `left_at` 있으면 거부 |
| 7 | unread 채팅 배지 보기 | 거부 | 허용 | 허용 | 허용 | 허용 | 허용 | 허용 | 상대 메시지는 0 | 상대 메시지는 0 | 다른 활성 방만 허용 |
| 8 | 그룹 만들기 | 거부 | 허용 | 허용 | 허용 | 허용 | 허용 | 허용 | 허용 | 허용 | 허용 |
| 9 | 그룹 편집 | 거부 | 거부 | 관계에 따름 | 관계에 따름 | 관리자만 | 거부 | 거부 | 관리자 여부에 따름 | 관리자 여부에 따름 | 거부 |
| 10 | 그룹 멤버 보기 | 거부 | 거부 | 소속에 따름 | 소속에 따름 | 활성 멤버만 | 활성 멤버만 | 거부 | 소속에 따름 | 소속에 따름 | 거부 |
| 11 | 그룹 탈퇴 | 거부 | 거부 | 소속에 따름 | 소속에 따름 | 거부 | active 일반 멤버만 | 거부 | 소속에 따름 | 소속에 따름 | 이미 거부 |
| 12 | 그룹 멤버 제외 | 거부 | 거부 | 관리자 여부에 따름 | 관리자 여부에 따름 | 관리자만 | 거부 | 거부 | 관리자면 허용 | 관리자면 허용 | 대상이 active가 아니므로 거부 |
| 13 | 모집 글 만들기 | 거부 | 거부 | 관계에 따름 | 관계에 따름 | 관리자만 | 거부 | 거부 | 관리자 여부에 따름 | 관리자 여부에 따름 | 거부 |
| 14 | 모집 글 편집 | 거부 | 거부 | 관계에 따름 | 관계에 따름 | 관리자만 | 거부 | 거부 | 관리자 여부에 따름 | 관리자 여부에 따름 | 거부 |
| 15 | 모집 글 지원 | 거부 | 조건부 허용 | 조건부 허용 | 조건부 허용 | 자기 그룹은 거부 | active 멤버는 거부 | 조건부 허용 | 소유자와 차단이면 거부 | 소유자와 차단이면 거부 | 재지원 허용 |
| 16 | 지원 승인/거절 | 거부 | 거부 | 관리자 여부에 따름 | 관리자 여부에 따름 | 관리자만 | 거부 | 거부 | 승인만 차단 조건 추가 | 승인만 차단 조건 추가 | 거부 |
| 17 | pending 지원 배지 | 거부 | 관리 그룹 없으면 0 | 관리자 여부에 따름 | 관리자 여부에 따름 | 허용 | 거부 | 거부 | 관리자 여부에 따름 | 관리자 여부에 따름 | 거부 |
| 18 | 사용자 차단 | 거부 | 조건부 허용 | 허용 | 허용 | 허용 | 허용 | 허용 | 이미 차단했으므로 UI상 거부 | 역방향 차단은 허용 | 허용 |
| 19 | 사용자 차단 해제 | 거부 | 자기 block만 | 자기 block만 | 자기 block만 | 자기 block만 | 자기 block만 | 자기 block만 | 허용 | 거부 | 자기 block만 |
| 20 | 사용자 신고 | 거부 | 조건부 허용 | 허용 | 허용 | 허용 | 허용 | 허용 | 허용 | 허용 | 허용 |

## 4. 액션별 직접 근거와 조건

### 4.1 멤버 목록·상세

직접 확인:

- `member_search_profiles`: authenticated만 SELECT, 본인·비활성·차단 관계 제외
- `member_public_profile_details`: 안전한 상세 필드만 반환
- `search_member_profiles(...)`: 동일 제외 조건과 필터 적용
- Flutter는 `MemberSearchService`에서 위 view/RPC만 사용

비공개 필드인 `email`, `phone`, `auth_uid`, `phone_verified`, 결제/구독,
관리자 정보는 반환 projection에 없다.

### 4.2 메시지 요청

직접 확인:

- `send_message_request(p_target_user_id uuid, p_note text)`
  - 로그인·활성 상태 검사
  - 자기 자신 요청 금지
  - 차단 관계 금지
  - 1~300자
- `prevent_duplicate_open_direct_message_requests()` trigger
  - 양방향 `pending`/`accepted` 중복 금지
- `get_member_relationship_state(p_target_user_id uuid)`
- `accept_message_request(p_request_id uuid)`
  - receiver party 검증
  - pending/accepted만 처리
  - 방과 참가자를 idempotent하게 생성
- 거절: `message_requests` update + `requests_reject_recipient` RLS

확인 필요:

- 차단 전에 생성된 pending 요청은 inbox projection에서 검색/배지 제외가 적용되지만,
  승인 RPC 자체의 최종 정의에 차단 조건이 포함되는지는 실제 적용 DB에서
  수동 검증한다.

### 4.3 채팅방·메시지

직접 확인:

- `my_chat_rooms`
  - 현재 사용자의 active participant 행 필요
  - 요청 상태 `accepted`
  - 상대 active
  - 차단 관계 없음
- `is_active_accepted_room_participant(p_room_id uuid)`
- `get_room_messages(p_room_id uuid)`
  - active participant + accepted request 확인
- `send_room_message(p_room_id uuid, p_body text)`
  - active profile
  - active participant + accepted request
  - 차단 관계 없음
  - 1~1000자
- `mark_chat_room_read(p_room_id uuid)`
  - active participant만 본인 `last_read_at` 갱신

주의:

- 차단 관계의 방은 `my_chat_rooms`에서 숨겨지고 전송은 거부된다.
- 현재 `get_room_messages`는 active participant와 accepted 상태는 확인하지만
  `room_has_block_relationship`를 직접 확인하지 않는다. 따라서 room ID를 알고
  RPC를 직접 호출한 기존 참가자의 과거 메시지 읽기는 허용될 수 있다.
  이는 현재 코드로 직접 확인되는 제한이며, 제품 정책이 “차단 후 과거 대화도
  읽기 금지”라면 새 마이그레이션이 필요하다.
- 그룹 채팅은 구현되지 않았다. GA/GM 셀의 채팅 권한은 개인 1:1 방의 참가자인
  경우만 의미한다.

### 4.4 그룹

직접 확인:

- `create_my_group_profile(...)`: active profile 필요, 생성자를 admin으로 추가
- `update_my_group_profile(...)`: `is_group_admin` 필요
- `get_my_group_profiles()`: active `admin`/`member` membership만 반환
- `get_group_members(p_group_id uuid)`: 대상 그룹의 active 멤버만 호출
- `leave_group(p_group_id uuid)`: active 일반 member만 `left`
- `remove_group_member(p_group_id uuid, p_member_user_id uuid)`:
  active admin만 active 일반 member를 `removed`

상태/역할:

- `group_members.role`: `admin`, `member`
- `group_members.membership_status`: `active`, `left`, `removed`
- 관리자의 탈퇴, 역할 변경, 소유권 이전은 현재 거부/미구현이다.

### 4.5 모집 글·지원

직접 확인:

- 모집 글 생성·편집 RPC는 `is_group_admin` 검사
- 공개 목록은 active 그룹의 `open` 글만 반환
- `apply_to_recruitment_post(p_post_id uuid, p_message text)`
  - active profile, active group, open 글
  - 자기 그룹 admin/active member 금지
  - 그룹 `created_by`와 차단 관계 금지
  - pending 중복 금지
  - 메시지 최대 500자
- `accept_recruitment_application(p_application_id uuid)`
  - active group admin
  - pending
  - active applicant
  - 그룹 소유자와 차단 관계 없음
  - 지원자를 active member로 추가/재활성화
- `reject_recruitment_application(p_application_id uuid)`
  - group admin + pending
- `get_my_badge_counts()`
  - active admin membership이 있는 그룹의 pending 지원만 계산

추론:

- left/removed former member는 active membership 검사에 걸리지 않고 partial
  unique index가 pending만 막으므로 다시 지원 가능하다. 이 동작은 migration
  028의 명시적 목적이지만 실제 UI 회귀 테스트가 필요하다.

### 4.6 차단·신고

직접 확인:

- `block_user(p_blocked_user_id uuid)`: active 본인/대상, self 금지, idempotent
- `unblock_user(p_blocked_user_id uuid)`: 현재 사용자가 만든 block만 삭제
- `get_my_blocked_users()`: 현재 사용자가 차단한 대상만 안전한 요약으로 반환
- `report_user(p_reported_user_id uuid, p_reason text, p_note text)`
  - active 본인/대상
  - self 금지
  - 지정 사유만 허용
  - 메모 최대 1000자
  - `reports.status = open`

신고에는 차단 관계 금지 조건이 없으므로 차단 중에도 신고할 수 있다. 관리자
moderation dashboard와 자동 제재는 연기 상태다.

## 5. 민감 데이터·키 점검

- Flutter 초기화는 `SUPABASE_URL`과 `SUPABASE_ANON_KEY`만 사용한다.
- `Supabase.initialize(..., publishableKey: AppConfig.supabaseAnonKey)`로 연결한다.
- Flutter 소스에 `service_role` 또는 secret key 사용은 확인되지 않았다.
- 채팅 화면은 `public.users` 전체 테이블을 직접 조회하지 않는다.
- 다른 사용자 프로필은 제한된 view/RPC를 사용한다.
- 본인 프로필 설정·편집만 RLS가 적용된 `users`와 본인 join table에 접근한다.
- 관리자·결제·구독·신고·차단 원본 데이터는 공개 projection에 포함되지 않는다.

## 6. 필수 수동 보안 테스트

1. D 세션으로 A/C room ID에 `get_room_messages`와 `send_room_message` 호출:
   모두 거절되어야 한다.
2. C가 `left_at`이 있는 room participant인 테스트 데이터에서 동일 호출:
   모두 거절되어야 한다.
3. GM 세션으로 그룹 편집·모집 글 생성·지원 승인 RPC 호출:
   모두 거절되어야 한다.
4. NM/D 세션으로 `get_group_members` 호출:
   거절되어야 한다.
5. A가 C를 차단한 뒤 양쪽에서 새 메시지 요청·채팅 전송·모집 지원:
   거절되어야 한다.
6. C가 탈퇴/제외된 뒤 같은 open 글에 재지원:
   새 pending 1건만 허용되어야 한다.
7. 브라우저 Network 응답에서 email/phone/auth_uid/결제/관리자 필드가 없는지 확인한다.

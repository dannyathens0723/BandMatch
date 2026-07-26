# BandMatch MVP 현황

최종 점검일: 2026-07-26

대상: Flutter Web 우선 MVP, 향후 iOS 지원 예정

DB 기준: `supabase/migrations/001_initial_schema.sql`부터
`031_unread_chat_message_counts.sql`까지 적용된 상태

## 1. 요약

BandMatch MVP에는 인증, 개인 프로필, 멤버 검색, 메시지 요청, 1:1 채팅,
미확인 건수 배지, 그룹/밴드, 모집 글/지원, 차단/신고의 기본 흐름이 구현되어
있다. 현재 단계는 기능 회귀 테스트와 권한 검증, 프런트엔드 UI/UX 개선을
병행할 수 있는 상태다.

이 문서는 저장소의 실제 Flutter 화면·서비스·모델 및 Supabase 마이그레이션을
기준으로 작성했다. 실제 Supabase 프로젝트의 설정이나 운영 데이터가 필요한
항목은 수동 QA가 필요하다.

## 2. 구현된 사용자·계정 기능

- `AuthGate`가 앱 시작 시 현재 세션과 `public.users` 프로필 존재 여부를 확인한다.
- 세션 없음: `AuthScreen`
- 세션 있음 + 프로필 없음: `ProfileSetupScreen`
- 세션 있음 + 프로필 있음: `HomeScreen`
- 이메일 매직 링크 로그인
- 이메일/비밀번호 로그인
- 비밀번호 설정·재설정 및 recovery callback 처리
- 만료되거나 잘못된 인증 링크 파라미터를 안전하게 처리하고 Web URL을 정리
- 로그아웃 후 `AuthScreen`으로 복귀
- Supabase 연결값은 `SUPABASE_URL`, `SUPABASE_ANON_KEY`를
  `--dart-define`으로 전달

근거:

- `app/lib/app.dart`
- `app/lib/screens/auth_screen.dart`
- `app/lib/screens/password_reset_dialog.dart`
- `app/lib/screens/password_setup_screen.dart`
- `app/lib/services/auth_callback.dart`
- `app/lib/config/app_config.dart`

## 3. 구현된 프로필 기능

- 최초 프로필 설정: 표시 이름, 생년월일, 목적, 파트, 경력, 장르, 지역
- 본인 프로필 편집: 표시 이름, 경력, 목적, 파트, 장르, 지역
- 프로필 이미지 업로드
  - Storage bucket: `avatars`
  - 허용 형식: JPEG, PNG, WebP
  - 최대 크기: 5 MiB
  - 본인의 `public.users.id` 폴더에만 쓰기 가능
- `MyPageScreen`에서 본인의 안전한 공개 프로필 요약과 Auth 이메일 표시
- 프로필 편집 완료 후 My Page가 즉시 다시 로드됨
- 다른 사용자가 보는 목록·상세 화면에도 수정 결과가 반영됨

근거:

- `ProfileSetupScreen`, `ProfileEditScreen`, `MyPageScreen`
- `ProfileService`, `ProfileAvatarService`, `MyPageService`
- `get_my_page_profile()`
- `update_my_avatar_url(p_avatar_url text)`

주의: 현재 이미지 선택 구현은 Web 전용 파일 선택기와 비-Web stub으로 분리되어
있다. iOS 파일/사진 선택 구현은 아직 추가되지 않았다.

## 4. 구현된 멤버 검색·상세 기능

- 활성 사용자 목록과 상세 화면
- 현재 로그인한 본인, 비활성/탈퇴 사용자, 차단 관계 사용자 제외
- 공개 허용 필드만 반환
  - 표시 이름, 공개 설정된 나이·성별, 경력, 목적, 파트, 장르, 지역, 소개
  - 상세 화면의 좋아하는 아티스트, 장비, 활동 빈도·요일
- 파트, 장르, 지역, 경력, 목적, 표시 이름 키워드 필터
- 최대 60건 반환
- Flutter에서 다른 사용자의 `public.users` 전체 행을 직접 조회하지 않음

근거:

- `MemberListScreen`, `MemberDetailScreen`
- `member_search_profiles`
- `member_public_profile_details`
- `search_member_profiles(p_part_ids, p_genre_ids, p_area_ids,`
  `p_experience_levels, p_purposes, p_keyword)`

## 5. 구현된 메시지 요청 기능

- 다른 활성 사용자에게 1~300자의 메시지 요청 전송
- 받은 요청 목록 조회
- 수신자만 pending 요청을 승인 또는 거절
- 같은 두 사용자 사이의 양방향 pending/accepted 중복 요청 방지
- 관계 상태:
  - `none`
  - `outgoing_pending`
  - `incoming_pending`
  - `accepted`
  - `room_exists`
  - `rejected`
- 승인 시 하나의 `message_rooms` 행과 양쪽 `room_participants` 행을 원자적으로 생성
- 같은 요청을 다시 승인해도 방이 중복 생성되지 않음
- 차단 관계에서는 새 요청 전송 제한

근거:

- `MemberDetailScreen`, `ReceivedMessageRequestsScreen`
- `MessageRequestService`, `ReceivedMessageRequestService`
- `get_member_relationship_state(p_target_user_id uuid)`
- `send_message_request(p_target_user_id uuid, p_note text)`
- `accept_message_request(p_request_id uuid)`
- `received_message_requests_view`

거절은 `ReceivedMessageRequestService`가 `message_requests`를 직접 갱신하며,
수신자만 갱신 가능한 RLS 정책의 보호를 받는다.

## 6. 구현된 채팅 기능

- 승인된 1:1 요청으로 생성된 채팅방 목록
- 활성 참가자만 채팅방 목록, 메시지 조회, 메시지 전송 가능
- 메시지를 시간순으로 조회
- 1~1000자의 text 메시지 전송
- DB 전송 성공 후 반환된 메시지를 현재 화면에 추가
- 채팅방을 열면 해당 참가자의 `last_read_at` 갱신
- 차단 관계가 생기면 새 채팅 메시지 전송 제한
- 채팅방 목록 복귀 시 해당 방의 미확인 배지를 즉시 0으로 표시한 후 서버 값 재조회

근거:

- `ChatRoomsScreen`, `ChatRoomScreen`
- `my_chat_rooms`
- `get_room_messages(p_room_id uuid)`
- `send_room_message(p_room_id uuid, p_body text)`
- `mark_chat_room_read(p_room_id uuid)`
- `is_active_accepted_room_participant(p_room_id uuid)`

현재 채팅은 수동 화면 진입·재조회 방식이다. Realtime과 자동 polling은 없다.

## 7. 구현된 배지·건수 기능

`get_my_badge_counts()`는 현재 사용자에게 필요한 다음 세 건수를 반환한다.

- `pending_message_request_count`
- `pending_recruitment_application_count`
- `unread_chat_message_count`

표시 위치:

- Home: 받은 메시지 요청, 미확인 채팅 메시지
- My Page: 관리 중인 그룹의 pending 지원
- 모집 글/지원 목록: 관리 중인 그룹의 pending 지원
- 채팅방 목록: 방별 `unread_count`

자신이 보낸 메시지는 자신의 unread 건수에 포함되지 않는다. 방을 열어
`mark_chat_room_read`가 성공하면 이후 메시지만 unread로 계산한다.

근거:

- `BadgeCountService`, `BadgeCounts`, `CountBadge`
- `030_in_app_badge_counts.sql`
- `031_unread_chat_message_counts.sql`

## 8. 구현된 그룹·밴드 기능

- 그룹 프로필 생성·편집
- 그룹 이름, 소개, 장르, 모집 파트, 활동 지역 저장
- My Groups에서 관리자인 그룹과 일반 멤버로 가입한 그룹을 구분해 표시
- 그룹 관리자만 그룹 프로필과 모집 글 편집 가능
- 활성 그룹 멤버만 멤버 목록 조회 가능
- 일반 멤버의 그룹 탈퇴
- 활성 관리자에 의한 일반 멤버 제외
- 관리자 본인의 탈퇴, 관리자 역할 변경, 소유권 이전은 미지원
- 탈퇴·제외 이력을 `group_members`에 보존
  - `membership_status`: `active`, `left`, `removed`
  - `left_at`
  - `removed_by`

근거:

- `MyGroupsScreen`, `GroupEditScreen`, `GroupMembersScreen`
- `get_my_group_profiles()`
- `create_my_group_profile(...)`
- `update_my_group_profile(...)`
- `get_group_members(p_group_id uuid)`
- `leave_group(p_group_id uuid)`
- `remove_group_member(p_group_id uuid, p_member_user_id uuid)`

## 9. 구현된 모집 글·지원 기능

- 그룹 관리자의 모집 글 생성·편집
- 모집 글 상태: `draft`, `open`, `closed`
- 활성 그룹의 `open` 글을 로그인 사용자에게 안전한 공개 목록·상세로 제공
- 일반 사용자의 지원 메시지: 최대 500자
- 그룹 관리자만 지원 목록 조회 및 승인·거절 가능
- 지원 상태: `pending`, `accepted`, `rejected`
- 승인 시 지원자를 `group_members`의 활성 `member`로 추가
- 탈퇴·제외된 사용자는 동일 글에 다시 지원 가능
- 동일 사용자·동일 글의 pending 지원만 중복 방지
- 그룹 소유자와 지원자 사이에 차단 관계가 있으면 지원 및 승인 제한
- 관리 중인 그룹의 pending 지원 건수 배지

근거:

- `RecruitmentPostsScreen`, `RecruitmentPostEditScreen`
- `PublicRecruitmentPostsScreen`, `PublicRecruitmentPostDetailScreen`
- `RecruitmentApplicationsScreen`
- `get_my_group_recruitment_posts(p_group_id uuid)`
- `create_my_group_recruitment_post(...)`
- `update_my_group_recruitment_post(...)`
- `get_public_recruitment_posts()`
- `get_my_recruitment_application_state(p_post_id uuid)`
- `apply_to_recruitment_post(p_post_id uuid, p_message text)`
- `get_my_group_recruitment_applications(p_group_id uuid)`
- `accept_recruitment_application(p_application_id uuid)`
- `reject_recruitment_application(p_application_id uuid)`

## 10. 구현된 안전 기능

- 사용자 차단
- 본인이 차단한 사용자 목록
- 차단 해제
- 사용자 신고
- 신고 사유:
  - `harassment`
  - `inappropriate_profile`
  - `impersonation`
  - `other`
- 신고 상세 메모 최대 1000자
- 신고 생성 상태: `open`
- 차단 관계가 멤버 검색, 요청, 새 채팅 전송, 모집 지원/승인에 반영

근거:

- `MemberDetailScreen`, `BlockedUsersScreen`, `UserReportDialog`
- `get_user_safety_state(p_target_user_id uuid)`
- `block_user(p_blocked_user_id uuid)`
- `unblock_user(p_blocked_user_id uuid)`
- `report_user(p_reported_user_id uuid, p_reason text, p_note text)`
- `get_my_blocked_users()`

## 11. 의도적으로 연기한 기능

- 계정 탈퇴/비활성화 UI와 운영 절차
  - 초기 스키마에 `withdraw_current_user()`가 존재하지만 현재 My Page의
    「アカウント削除」는 placeholder이며 MVP 사용자 흐름으로 연결되지 않음
- 이메일 알림
- Push 알림
- Realtime
- 자동 polling
- 메시지별 읽음 확인 UI
- 읽음 체크 표시
- 입력 중 표시
- 그룹 채팅
- 그룹 이미지 업로드
- 관리자 moderation dashboard
- 자동 제재
- 고급 UI polish 및 전체 UI/UX 재설계
- iOS 빌드 및 실기기 테스트

## 12. 주요 제한과 확인 필요 사항

- 자동화 테스트는 인증 callback, 배지 모델/위젯, 채팅방 요약 모델 중심이다.
  전체 Supabase 통합 흐름은 수동 회귀 테스트가 필요하다.
- 현재 Flutter 앱의 다른 사용자 프로필 조회는 안전한 뷰/RPC를 사용하지만,
  본인 프로필 편집은 RLS로 제한된 `users`와 join table을 직접 조회·갱신한다.
- `my_chat_rooms`와 여러 공개 projection은 `security_invoker = false` 뷰다.
  클라이언트 권한은 `authenticated`로만 grant되고 내부 조건으로 현재 사용자,
  활성 상태, 차단 관계를 제한한다. 새 필드를 추가할 때는 반드시 노출 범위를
  다시 검토해야 한다.
- avatar bucket은 공개 읽기다. URL은 공개 프로필에 노출되는 데이터로 취급한다.
- iOS에서는 avatar 선택기가 현재 unsupported stub을 사용한다.
- 배지는 Realtime/polling이 아니므로 화면 진입·복귀·새로고침 시점에 갱신된다.
- 신고는 저장만 하며 관리자 검토 UI와 자동 제재가 없다.
- 관리자는 그룹을 탈퇴할 수 없고, 역할 변경·소유권 이전도 없다.
- `ReceivedMessageRequestsScreen`의 승인 완료 후 채팅 진입 UX는 다른 채팅
  진입 경로와 함께 수동 QA로 확인해야 한다.

## 13. 권장 다음 단계

1. `MANUAL_QA_CHECKLIST.md`의 A/C 계정 회귀 테스트를 완료한다.
2. `PERMISSION_MATRIX.md`의 비참가자, 차단 양방향, 탈퇴/제외 후 재지원 항목을
   실제 Supabase 프로젝트에서 검증한다.
3. UI/UX 작업은 `FRONTEND_HANDOFF.md`의 안전한 화면부터 분리한다.
4. 프런트엔드 변경 후 좁은 화면과 데스크톱 화면을 모두 검증한다.
5. iOS 작업을 시작할 때 avatar picker의 플랫폼 구현과 인증 redirect 설정을
   별도 작업으로 다룬다.
6. Realtime/read receipt UI 같은 상태 동기화 기능은 현재 수동 갱신 기준을
   먼저 회귀 테스트한 뒤 독립 단계로 설계한다.

## 14. 마이그레이션 인덱스

최신 번호: **031**

| 범위 | 내용 |
|---|---|
| 001–004 | 초기 스키마, 마스터 데이터, RLS, 로그인 전 마스터 조회 |
| 005–010 | 안전한 멤버 projection, 요청 inbox, 요청 승인·관계 상태 |
| 011–016 | 실험 채팅 롤백 기록, 채팅방·메시지 조회/전송, 채팅 권한 강화 |
| 017–019 | 멤버 필터, My Page 요약, avatar Storage |
| 020–025 | 그룹, 모집 글, 공개 모집, 지원, 가입 그룹, 멤버 목록 |
| 026–028 | 그룹 탈퇴·제외, 차단/신고, 활성 멤버십 이력·재지원 |
| 029 | 본인이 차단한 사용자 목록 |
| 030 | 메시지 요청·모집 지원 배지 건수 |
| 031 | 채팅 미확인 건수, 방별 unread, `mark_chat_room_read` |

최근 중요 마이그레이션:

- `027_user_block_and_report_safety.sql`: 차단·신고와 차단 시 상호작용 제한
- `029_my_blocked_users.sql`: 본인의 차단 목록
- `030_in_app_badge_counts.sql`: 메시지 요청·모집 지원 배지
- `031_unread_chat_message_counts.sql`: 채팅 unread와 읽음 시점

### 마이그레이션 운영 원칙

- Supabase에 이미 적용한 마이그레이션 파일은 수정하지 않는다.
- 기존 정의를 바꿔야 하면 다음 번호의 새 마이그레이션을 추가한다.
- RPC signature, 반환 컬럼, grant/revoke, RLS 영향을 함께 검토한다.
- SQL Editor 실행 전 대상 프로젝트와 이전 마이그레이션 적용 여부를 확인한다.

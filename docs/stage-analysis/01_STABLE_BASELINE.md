# STAGE 전환 기준선

작성 기준: 2026-07-29 (JST)

## 1. 범위와 결론

이 문서는 STAGE 전환 작업을 시작하기 전 BandMatch의 안정 상태를 고정한다. 조사 대상은 실제 Flutter 소스, `supabase/migrations/001`–`031`, 기존 QA/권한/프런트엔드 문서, 로컬 `docs/STAGE.html`이다.

- 현재 Git 브랜치: `stage-redesign`
- 조사 시점 HEAD: `fdf4c09` (`rename`)
- 실제 최신 마이그레이션: `031_unread_chat_message_counts.sql`
- 이 분석 작업은 Flutter, 테스트, 기존 마이그레이션, 의존성, 테마, 내비게이션 동작을 변경하지 않는다.
- 이후 DB 변경은 반드시 `032_*.sql`부터 새 마이그레이션으로 추가해야 한다. `001`–`031`은 수정하지 않는다.

## 2. Flutter 구조

앱은 `app/lib/main.dart`에서 Supabase를 초기화하고 `BandMatchApp`을 실행한다. `MaterialApp.home`은 `AuthGate`이며 named route/router 패키지는 사용하지 않는다.

| 영역 | 현재 파일/수 | 역할 |
|---|---:|---|
| 앱 진입·세션 | `main.dart`, `app.dart` | `--dart-define`, Supabase 초기화, 세션/프로필/recovery 분기 |
| 설정 | `config/app_config.dart` | `SUPABASE_URL`, `SUPABASE_ANON_KEY` |
| 화면 | 21개 screen 파일 | 인증, 프로필, 멤버, 요청, 채팅, 그룹, 모집, 안전 |
| 서비스 | 23개 service 파일 | Supabase table/view/RPC/Storage 경계(플랫폼 stub 포함) |
| 모델 | 18개 model 파일 | 안전한 응답 projection과 화면 상태 |
| 공통 위젯 | 5개 | 배지, 멤버 카드, 마스터 데이터, 요청/신고 dialog |
| 테마 | `theme/app_theme.dart` | BandMatch yellow `#FFC629`, soft background, rounded card |
| 자동 테스트 | 3개 파일 | Auth callback/config widget, badge, chat room model |

### 화면 인벤토리

`auth_screen`, `password_reset_dialog`, `password_setup_screen`, `profile_setup_screen`, `home_screen`, `my_page_screen`, `profile_edit_screen`, `member_list_screen`, `member_detail_screen`, `received_message_requests_screen`, `chat_rooms_screen`, `chat_room_screen`, `my_groups_screen`, `group_edit_screen`, `group_members_screen`, `recruitment_posts_screen`, `recruitment_post_edit_screen`, `recruitment_applications_screen`, `public_recruitment_posts_screen`, `public_recruitment_post_detail_screen`, `blocked_users_screen`.

### 서비스 인벤토리

`auth_callback`, platform-specific `auth_url_cleaner_*`, platform-specific `avatar_file_picker_*`, `master_data_service`, `profile_service`, `profile_avatar_service`, `my_page_service`, `member_search_service`, `message_request_service`, `received_message_request_service`, `chat_room_service`, `chat_room_message_service`, `badge_count_service`, `group_profile_service`, `group_member_service`, `recruitment_post_service`, `public_recruitment_post_service`, `recruitment_application_service`, `user_safety_service`, `blocked_user_service`.

### 모델 인벤토리

`BadgeCounts`, `BlockedUser`, `ChatRoomMessage`, `ChatRoomSummary`, `EditableProfile`/`ProfileEditData`, `GroupMember`, `MasterDataItem`/`MasterData`, `MemberProfile`, `MemberRelationship`, `MemberSearchFilters`, `MyGroupProfile`/`GroupEditData`, `MyPageProfile`, `PickedAvatarFile`, `UserProfile`/`ProfileSetupData`, `ReceivedMessageRequest`, recruitment post/application models, `UserSafetyState`.

## 3. 현재 인증·플랫폼 기준선

`AuthGate`의 분기는 다음과 같다.

1. `auth.currentSession == null` → `AuthScreen`
2. 유효 세션 + `public.users` 행 없음 → `ProfileSetupScreen`
3. password recovery callback → `PasswordSetupScreen`
4. 유효 세션 + 프로필 존재 → `HomeScreen`
5. 조회 실패 → 빈 화면 대신 오류 카드와 재시도

Web callback URL 정리는 `auth_url_cleaner_web.dart`, avatar 파일 선택은 `avatar_file_picker_web.dart`에 격리되어 있고 각각 비-Web stub이 있다. 향후 iOS 구현은 같은 추상 경계를 유지해야 한다.

Flutter에는 `SUPABASE_URL`과 publishable/anon key인 `SUPABASE_ANON_KEY`만 전달된다. `service_role`/secret key 사용은 발견되지 않았다.

## 4. 구현 기능 기준선

### 계정·프로필

- 이메일 magic link 및 이메일/비밀번호 로그인
- password setup/reset callback
- 최초 프로필 생성과 본인 프로필 편집
- Web avatar 업로드(`avatars` bucket)
- My Page 안전 요약과 로그아웃

### 탐색·상호작용

- 안전한 멤버 목록/상세 projection
- 파트, 장르, 지역, 경력, 목적, 이름 필터
- 양방향 중복을 막는 메시지 요청과 관계 상태
- 받은 요청 조회, 승인/거절, 승인 시 방/참가자 생성
- 1:1 채팅방, 메시지 조회/전송, 방 단위 unread 처리

### 그룹·모집

- 그룹 생성/편집, 관리자/일반 멤버 구분
- active/left/removed 멤버십 이력
- 멤버 목록, 일반 멤버 탈퇴, 관리자 멤버 제외
- 그룹 모집 글 생성/편집, 공개 open 목록/상세
- 개인 단위 지원, 관리자 승인/거절, 승인 시 멤버 활성화
- 탈퇴/제외 후 재지원, pending 중복 방지

### 안전·상태

- 사용자 차단/해제/신고
- 본인이 차단한 사용자 목록
- 받은 메시지 요청, 관리 그룹의 pending 지원, unread chat 배지
- 비활성 프로필/그룹, 차단 관계, 역할에 따른 RPC/RLS 제한

## 5. 현재 내비게이션 기준선

현재 앱은 `Navigator.push` + `MaterialPageRoute` 방식이다. URL을 표현하는 route tree, 각 탭의 독립 stack, Web deep link는 없다. 따라서 STAGE의 5-tab shell과 Web/iOS deep link 요구에는 구조적 교체가 필요하다.

보존해야 할 현재 반환/재조회 계약은 다음과 같다.

| 호출 화면 → 대상 | 반환값 | 복귀 시 계약 |
|---|---|---|
| My Page → Profile Edit | `true` | My Page 프로필 즉시 재조회 |
| My Groups → Group Edit(create) | `'created'` | 그룹 목록 재조회 |
| My Groups → Group Edit(edit) | `'updated'` | 그룹 목록 재조회 |
| Recruitment Posts → Post Edit(create) | `'created'` | 모집 글 목록 재조회 |
| Recruitment Posts → Post Edit(edit) | `'updated'` | 모집 글 목록 재조회 |
| My Groups → Group Members | `'left'` | My Groups 재조회 |
| Chat Rooms → Chat Room | 없음 | 해당 카드 unread를 즉시 0으로 반영 후 서버 재조회 |
| Member Detail → Request Inbox | 없음 | 관계 상태 재조회 |
| Home/My Page → badge 영향 화면 | 없음 | 화면 복귀 후 `get_my_badge_counts` 재조회 |

STAGE router로 바꾸더라도 “mutation 성공 → canonical 화면으로 복귀 → 영향 범위만 재조회”라는 계약은 유지해야 한다.

## 6. 데이터 접근 기준선

Flutter가 직접 접근하는 주요 공개 계약은 다음과 같다.

- master: `parts`, `genres`, `areas`
- self-only: `users`, `user_purposes`, `user_parts`, `user_genres`, `user_areas`
- safe views: `member_search_profiles`, `member_public_profile_details`, `received_message_requests_view`, `my_chat_rooms`
- 주요 RPC: `current_user_id`, `search_member_profiles`, `get_member_relationship_state`, `send_message_request`, `accept_message_request`, `get_room_messages`, `send_room_message`, `mark_chat_room_read`, `get_my_badge_counts`, `get_my_page_profile`, `update_my_avatar_url`, 그룹/모집/지원/안전 RPC

Chat/검색/My Page Flutter 화면은 타인의 전체 `users` 행을 직접 조회하지 않는다. `ProfileService`의 `users` 접근은 현재 사용자의 onboarding/edit에 한정되고 RLS 및 system-field trigger의 보호를 받는다.

## 7. 자동 검증 기준선

| 검사 | 결과 |
|---|---|
| Dart analyzer | `No issues found!` |
| Flutter test | 7 tests passed |
| Flutter Web build | 성공, `app/build/web` 생성 |
| Web Wasm dry run | 성공 안내 |

환경의 Flutter batch wrapper가 SDK lockfile에서 대기하여 analyzer는 동일 SDK의 `dart.exe analyze`로 실행했다. Flutter test/build는 SDK cache 접근 권한을 허용한 뒤 `--no-pub`으로 통과했다. 의존성은 변경하지 않았다.

## 8. STAGE 전환 시 반드시 보존할 것

- Auth callback 오류가 앱을 blank로 만들지 않는 방어 로직
- 본인/관리자/참가자 검증을 Flutter UI가 아니라 DB에서도 강제하는 구조
- 공개 profile projection과 private account 필드의 분리
- 양방향 중복 요청 및 지원 pending 중복 방지
- 그룹 멤버십 이력과 승인 atomicity
- 차단/신고 접근 경로
- Web 구현과 stub으로 분리된 플랫폼 경계
- 현재 안정 기능이 새 STAGE shell 개발 중에도 실행 가능한 compatibility period

# BandMatch 프런트엔드 인수인계

최종 점검일: 2026-07-26

대상 협업자: Hongo 및 UI/UX 담당자

범위: Flutter 화면·공통 위젯의 시각 개선. DB/RPC/RLS 변경은 별도 협의.

## 1. 현재 프런트엔드 구조

```text
app/lib/
├─ main.dart                 # Supabase 초기화, 앱 시작
├─ app.dart                  # MaterialApp, AuthGate
├─ config/
│  └─ app_config.dart        # --dart-define 환경값
├─ screens/                  # 화면과 화면 로컬 상태
├─ services/                 # Supabase query/RPC/Storage 경계
├─ models/                   # 화면/서비스용 DTO와 상태 모델
├─ widgets/                  # 재사용 UI
└─ theme/
   └─ app_theme.dart         # 색상, 카드, chip, AppBar
```

현재는 별도 라우터 패키지나 named route 없이 `Navigator`와
`MaterialPageRoute`를 사용한다. 각 화면이 필요한 service를 직접 만들고,
`FutureBuilder` 또는 로컬 state로 loading/error/data 상태를 관리한다.

### 앱 시작과 인증

흐름:

```text
main.dart
  → Supabase.initialize
  → BandMatchApp
  → AuthGate
      ├─ session 없음 → AuthScreen
      ├─ session 있음 + profile 없음 → ProfileSetupScreen
      ├─ password recovery → PasswordSetupScreen
      └─ session 있음 + profile 있음 → HomeScreen
```

`AuthGate`는 Web callback URL을 읽고 정리하며, auth state stream을 구독한다.
이 흐름은 UI 작업 중에도 구조를 바꾸지 않는 것이 안전하다.

## 2. 주요 화면 파일

| 영역 | 화면 파일 | 역할 |
|---|---|---|
| 인증 | `auth_screen.dart` | 매직 링크, 이메일/비밀번호 로그인 |
| 인증 | `password_reset_dialog.dart` | 재설정 이메일 입력 팝업 |
| 인증 | `password_setup_screen.dart` | recovery 후 새 비밀번호 설정 |
| 온보딩 | `profile_setup_screen.dart` | 최초 프로필 생성 |
| 홈 | `home_screen.dart` | 주요 기능 진입, 배지, 마스터 데이터 |
| 프로필 | `my_page_screen.dart` | 본인 요약, 계정 액션, 그룹/차단 진입 |
| 프로필 | `profile_edit_screen.dart` | 프로필·avatar 편집 |
| 멤버 | `member_list_screen.dart` | 목록과 필터 |
| 멤버 | `member_detail_screen.dart` | 공개 상세, 요청, 차단·신고 |
| 요청 | `received_message_requests_screen.dart` | 받은 요청 승인·거절 |
| 채팅 | `chat_rooms_screen.dart` | 채팅방과 방별 unread |
| 채팅 | `chat_room_screen.dart` | 메시지 조회·전송·읽음 처리 |
| 그룹 | `my_groups_screen.dart` | 관리 그룹/가입 그룹 카드 목록 |
| 그룹 | `group_edit_screen.dart` | 그룹 생성·편집 |
| 그룹 | `group_members_screen.dart` | active 멤버, 탈퇴·제외 |
| 모집 관리 | `recruitment_posts_screen.dart` | 그룹의 모집 글 관리 |
| 모집 관리 | `recruitment_post_edit_screen.dart` | 모집 글 생성·편집 |
| 모집 관리 | `recruitment_applications_screen.dart` | 지원 승인·거절 |
| 모집 공개 | `public_recruitment_posts_screen.dart` | open 모집 목록 |
| 모집 공개 | `public_recruitment_post_detail_screen.dart` | 상세·지원 |
| 안전 | `blocked_users_screen.dart` | 차단 목록과 해제 |

별도의 `GroupDetailScreen`은 없다. 현재 `MyGroupsScreen`의 카드가 그룹 요약과
액션 허브 역할을 하며, 상세에 가까운 멤버 정보는 `GroupMembersScreen`에서
확인한다.

## 3. 주요 서비스와 DB 경계

프런트엔드 담당자는 service/RPC 연결을 유지하고 화면 표현만 바꾸는 것을
기본 원칙으로 한다.

| Service | 주요 데이터 경계 |
|---|---|
| `MasterDataService` | `parts`, `genres`, `areas`의 active 행 |
| `ProfileService` | 본인 `users` 및 본인 join table |
| `ProfileAvatarService` | `avatars` Storage, `update_my_avatar_url` |
| `MyPageService` | `get_my_page_profile` |
| `MemberSearchService` | `member_search_profiles`, 상세 view, 검색 RPC |
| `MessageRequestService` | 관계 상태, 요청 전송 RPC |
| `ReceivedMessageRequestService` | inbox view, 승인 RPC, RLS 기반 거절 update |
| `ChatRoomService` | `my_chat_rooms` |
| `ChatRoomMessageService` | 메시지 조회·전송·읽음 RPC |
| `BadgeCountService` | `get_my_badge_counts` |
| `GroupProfileService` | 내 그룹 조회·그룹 생성·편집 RPC |
| `GroupMemberService` | 멤버 조회·탈퇴·제외 RPC |
| `RecruitmentPostService` | 그룹 모집 글 조회·생성·편집 RPC |
| `PublicRecruitmentPostService` | 안전한 공개 모집 RPC |
| `RecruitmentApplicationService` | 지원 상태·지원·승인·거절 RPC |
| `UserSafetyService` | 안전 상태·차단·해제·신고 RPC |
| `BlockedUserService` | 본인의 차단 목록 RPC |

### 서비스 오류 처리

대부분의 service는 `PostgrestException`의 `message`, `code`, `details`, `hint`를
debug console에 기록하고 다시 throw한다. 화면은 사용자에게 일본어의 친절한
오류만 표시한다. UI 리팩터링 시 raw DB 오류를 화면에 노출하지 않는다.

## 4. 모델

| 영역 | 모델 |
|---|---|
| 마스터 | `MasterDataItem`, `MasterData` |
| 프로필 | `ProfileSetupData`, `EditableProfile`, `MyPageProfile`, `PickedAvatarFile` |
| 멤버 | `MemberProfile`, `MemberSearchFilters`, `MemberRelationship` |
| 요청 | `ReceivedMessageRequest` |
| 채팅 | `ChatRoomSummary`, `ChatRoomMessage` |
| 배지 | `BadgeCounts` |
| 그룹 | `MyGroupProfile`, `GroupEditData`, `GroupMember` |
| 모집 | `RecruitmentPost`, `PublicRecruitmentPost`, `RecruitmentPostEditData`, `RecruitmentApplication`, `RecruitmentApplicationState` |
| 안전 | `UserSafetyState`, `BlockedUser` |

JSON field 이름은 SQL view/RPC 반환 컬럼과 직접 연결된다. model field나
`fromJson` key를 바꾸면 백엔드 계약이 깨질 수 있으므로 협의 없이 변경하지 않는다.

## 5. 공통 위젯

- `CountBadge`
  - 0이면 숨김
  - 큰 수는 `99+`
  - semantic label 포함
- `MemberCard`
  - 안전한 공개 멤버 요약
- `MasterDataSection`
  - Home의 파트/장르 요약
- `MessageRequestSheet`
  - 메시지 요청 입력과 전송
- `UserReportDialog`
  - 신고 사유와 메모 입력

새로운 카드 스타일을 만들기 전에 이 위젯으로 통합 가능한지 확인한다.

## 6. 현재 시각 방향

- 서비스명: BandMatch
- 주색: yellow `#FFC629`
- 배경: soft warm background `#FFFCF5`
- 카드: 흰색, elevation 0, radius 20
- chip: 연한 노랑 `#FFF3CA`, pill 형태
- Material 3
- 사용자 UI 언어: 일본어
- 현재 우선 대상: Flutter Web
- 향후 대상: iOS
- 레이아웃: 중앙 `ConstrainedBox`, 넓은 화면/좁은 화면을 모두 고려

브랜드 노랑은 주요 CTA와 선택 상태에 사용하되, 경고·삭제·차단 같은 위험
액션은 같은 강조도로 보이지 않도록 시각 계층을 구분한다.

## 7. 플랫폼 호환 경계

Web API는 다음처럼 조건부 import 뒤에 격리되어 있다.

- 인증 URL 정리:
  - `auth_url_cleaner_web.dart`
  - `auth_url_cleaner_stub.dart`
- avatar 파일 선택:
  - `avatar_file_picker_web.dart`
  - `avatar_file_picker_stub.dart`

새 Web 전용 API를 화면 파일에 직접 추가하지 않는다. 동일한 web/stub 또는
향후 mobile 구현 경계를 사용한다. 현재 avatar 선택은 비-Web에서
`UnsupportedError`이므로 iOS 지원 시 별도 구현이 필요하다.

## 8. UI polish가 비교적 안전한 화면

아래 작업은 service 호출, 반환값, 권한 버튼 조건을 유지한다면 비교적 안전하다.

- `HomeScreen`
  - 기능 카드 시각 계층, 주요 CTA 정리, 마스터 요약 축약
- `MemberListScreen`
  - 필터 패널, 카드 간격, 좁은 화면 chip 배치
- `MemberDetailScreen`
  - 공개 정보 섹션 순서·가독성
  - 단, 메시지/차단/신고 버튼 조건은 민감 영역
- `MyPageScreen`
  - 프로필 요약, 설정 그룹, placeholder 표현
- `MyGroupsScreen`
  - 관리 그룹과 가입 그룹의 시각 구분
- `GroupMembersScreen`
  - 멤버 카드 정보 계층
  - 단, 탈퇴/제외 버튼은 민감 영역
- `PublicRecruitmentPostsScreen`
  - 모집 카드 비교 가능성
- `PublicRecruitmentPostDetailScreen`
  - 본문, 파트, 장르, 지역 가독성
  - 단, 지원 상태/버튼은 민감 영역
- `ChatRoomsScreen`
  - 상대 정보, 시간, unread 배지 정렬
- `ChatRoomScreen`
  - bubble, 시간, 입력 영역의 시각 개선
  - 단, send/read 상태 로직은 유지

## 9. 수정에 주의할 화면

### 인증·세션

- `AuthScreen`
- `PasswordResetDialog`
- `PasswordSetupScreen`
- `ProfileSetupScreen`
- `AuthGate`

주의 이유: callback URL, recovery event, current session, profile 존재 여부가
화면 전환을 결정한다.

### 승인·거절

- `ReceivedMessageRequestsScreen`
- `RecruitmentApplicationsScreen`

주의 이유: 버튼 활성 상태와 처리 중 잠금이 중복 DB 작업과 권한 오류를 막는다.

### 권한에 따라 버튼이 달라지는 화면

- `MemberDetailScreen`
  - 관계 상태, safety 상태, room ID
- `MyGroupsScreen`
  - `membershipRole == admin`
- `GroupMembersScreen`
  - 관리자/일반 멤버, 자기 탈퇴, 다른 멤버 제외
- `RecruitmentPostsScreen`
  - 그룹 관리자 전용
- `PublicRecruitmentPostDetailScreen`
  - `none`, `pending`, `own_group`, `group_member`, `blocked`, `closed`
- `BlockedUsersScreen`, `UserReportDialog`

권한 버튼을 단순히 숨기는 것만으로 보안을 대체할 수 없다. 서버 검증은 유지하되,
UI도 잘못된 액션을 노출하지 않아야 한다.

## 10. 반드시 보존할 navigation 반환 계약

화면 복귀 후 즉시 갱신되는 기능은 `Navigator.push`의 결과값에 의존한다.

| From → To | 반환값 | 호출자의 동작 |
|---|---|---|
| My Page → Profile Edit | `true` | My Page 프로필 재조회 |
| My Groups → Group Edit(create) | `'created'` | 그룹 목록 재조회 |
| My Groups → Group Edit(edit) | `'updated'` | 그룹 목록 재조회 |
| Recruitment Posts → Post Edit(create) | `'created'` | 모집 글 재조회 |
| Recruitment Posts → Post Edit(edit) | `'updated'` | 모집 글 재조회 |
| My Groups → Group Members | `'left'` | My Groups 재조회 |
| Chat Rooms → Chat Room | 반환값 없음 | 해당 unread를 0으로 반영 후 목록 재조회 |
| Member Detail → Request Inbox | 반환값 없음 | 관계 상태 재조회 |
| My Page → My Groups/Blocked Users | 반환값 없음 | 필요한 배지/프로필 상태 재조회 |

화면을 modal, bottom sheet, router로 바꿀 때 이 결과 계약과 `await`를 잃지 않는다.
과거 stale 화면 버그가 바로 이 복귀 재조회 누락에서 발생했다.

## 11. 프런트엔드 협업 규칙

1. service/RPC 호출 이름과 parameter를 협의 없이 바꾸지 않는다.
2. model field/JSON key를 협의 없이 바꾸지 않는다.
3. `service_role`, secret, 사용자 비밀번호를 Flutter나 Git에 넣지 않는다.
4. Flutter는 publishable/anon key만 사용한다.
5. Web 전용 API는 플랫폼별 파일과 stub 뒤에 격리한다.
6. 일본어 UI 라벨은 의도적인 copy 변경이 아니면 유지한다.
7. loading, empty, loaded, error 상태를 서로 구분한다.
8. 빈 목록을 오류로 표시하지 않는다.
9. raw Supabase/Postgres 오류를 사용자에게 노출하지 않는다.
10. 저장·전송·승인 버튼은 처리 중 비활성화해 중복 요청을 막는다.
11. 화면 복귀 후 reload 계약을 유지한다.
12. 배지는 0일 때 숨기고 숫자가 있을 때만 표시한다.
13. 좁은 모바일 폭에서 일본어 라벨이 잘리지 않는지 확인한다.
14. avatar URL 외의 private user 필드를 UI에 추가하지 않는다.
15. UI 변경 PR에는 desktop Web과 mobile-like 폭 스크린샷을 함께 남긴다.

## 12. 권장 작업 분담

### 현재 개발자가 계속 소유할 영역

- Supabase schema와 새 migration
- RLS, grant/revoke, security definer 함수
- RPC/view signature와 데이터 projection
- Auth/session/callback 로직
- 메시지 요청 관계 상태와 승인 트랜잭션
- unread/read-state 계산
- 그룹 role/membership 상태
- 모집 지원 승인·재가입 상태
- 차단/신고 정책
- 서비스·모델 계약 변경
- 통합 테스트와 보안 회귀

### 프런트엔드 협업자가 맡기 좋은 영역

- 디자인 토큰 보강과 일관된 spacing
- 카드, section header, empty/error state 컴포넌트화
- Home 정보 구조
- 멤버·모집 목록 카드 가독성
- 멤버·모집 상세의 정보 계층
- My Page 설정 그룹화
- 관리 그룹/가입 그룹 구분
- 채팅 목록과 bubble 시각 정리
- 좁은 폭 responsive 배치
- 접근성: tooltip, semantic label, 터치 영역, 색 대비

## 13. Hongo에게 권장하는 첫 UI/UX 작업

작은 PR 단위로 아래 순서를 권장한다.

1. **공통 spacing audit**
   - 화면 좌우 padding, 카드 내부 padding, section 간격을 표로 정리
   - 동작 변경 없이 적용
2. **빈 상태 통일**
   - 멤버, 요청, 채팅, 그룹, 모집, 차단 목록의 icon/title/body/button 구조 통일
3. **버튼 체계**
   - Primary, tonal, outlined, destructive 액션 규칙 정의
   - 처리 중 spinner 크기와 disabled 상태 통일
4. **멤버 카드**
   - 이름, 경력, 파트/장르, 지역의 우선순위 개선
   - 좁은 화면 chip wrap 확인
5. **모집 카드와 상세**
   - 그룹명/제목/모집 파트/지역을 빠르게 비교 가능하게 개선
   - 긴 본문 가독성 개선
6. **My Page**
   - 공개 프로필, 계정, 그룹, 안전, 향후 기능을 섹션으로 구분
7. **관리 그룹과 가입 그룹**
   - role badge와 가능한 액션을 시각적으로 명확히 구분
8. **채팅**
   - 방 카드 unread 강조
   - 내/상대 bubble, timestamp, 입력창의 desktop/mobile 균형 조정
9. **responsive QA**
   - 약 360, 768, 1280px 폭에서 overflow와 일본어 clipping 확인

각 단계는 `dart analyze`, `flutter test`, `flutter build web`을 통과한 뒤 합친다.

## 14. 아직 건드리지 않을 영역

- DB schema와 기존 migration
- Supabase RPC/view/table/policy
- AuthGate와 auth callback URL 처리
- RLS/security-definer 로직
- unread/read-state 계산 및 `last_read_at`
- 메시지 요청 중복/양방향 방지
- 그룹 membership 이력·재가입 규칙
- 차단/신고 enforcement
- Realtime, polling
- 이메일/Push 알림
- 메시지 읽음 체크, 입력 중 표시
- 그룹 채팅
- 그룹 이미지 업로드
- 계정 삭제/비활성화
- 관리자 moderation dashboard와 자동 제재
- 전체 navigation 프레임워크 교체

## 15. PR 체크리스트

- [ ] service/RPC/model 계약을 바꾸지 않았다.
- [ ] navigation 반환값과 복귀 reload를 유지했다.
- [ ] 일본어 문구가 잘리지 않는다.
- [ ] 0건은 empty state이며 error state가 아니다.
- [ ] 처리 중 버튼이 비활성화된다.
- [ ] desktop Web과 mobile-like 폭을 확인했다.
- [ ] Web 전용 API를 공용 screen에 직접 추가하지 않았다.
- [ ] private field와 secret을 추가하지 않았다.
- [ ] `dart analyze` 통과
- [ ] `flutter test` 통과
- [ ] `flutter build web` 통과
- [ ] 관련 `MANUAL_QA_CHECKLIST.md` 항목 통과

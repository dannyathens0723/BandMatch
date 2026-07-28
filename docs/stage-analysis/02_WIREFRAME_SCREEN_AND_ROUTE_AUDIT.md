# STAGE 와이어프레임 화면·전이 감사

## 1. 조사 방법과 증거 수준

source of truth는 로컬 `docs/STAGE.html`이다. 파일 안의 bundled template을 UTF-8로 해제하여 다음을 검사했다.

- `Component.state`, `go(id)`, `renderVals()`
- 50개 `screen` ID와 `sc-if` screen container
- 모든 `sc-camel-on-click` binding
- mock collection의 `go` destination
- role/crew/segment/attendance/poll/decision state handler
- `href`, `window`, `history`, `location`, hash/query 사용 여부

가벼운 로컬 static server도 준비했으나 이 실행 환경에서 연결 가능한 브라우저가 0개로 확인되어 실제 click automation은 수행하지 못했다. 아래에서 **확인**은 HTML/JavaScript handler로 확인된 전이, **시각 전용**은 버튼/설명은 있지만 handler가 없는 항목, **권장**은 production 규칙을 뜻한다.

중요한 사실:

- prototype은 URL router가 아니라 `state.screen` 교체만 사용한다.
- `go(id)`는 `setState({screen:id})`만 수행한다.
- `history`, `location`, hash, query, deep-link parser가 없다.
- 외부 링크용 실제 `href/target`도 없다. 발견된 유일한 `href`는 Google Fonts preconnect이다.
- 화면 좌측 인덱스는 50개 모든 screen으로 직접 이동하므로 실제 사용자 권한 흐름을 우회할 수 있다.
- role switch는 시뮬레이션일 뿐 권한 검사가 아니다.

## 2. prototype state

| state | 초기값 | 변경 handler | 의미 |
|---|---|---|---|
| `screen` | `login` | `go`, `goHome`, 여러 `nav.*` | 현재 보이는 screen |
| `role` | `null` → `guest` | `setGuest`, `setMember`, `setLeader` | 미소속/멤버/리더 UI |
| `crewIdx` | `0` | `toggleCrew` | 2개 mock crew 전환 |
| `seg` | `find` | `segFind`, `segMine` | クルー의 찾기/내 크루 segment |
| `resSeg` | `song` | `resSong`, `resVid` | 자료 종류 segment |
| `att` | `未回答` | `attGo`, `attMaybe`, `attNo` | 연습 출결 |
| `v1`–`v3` | `－` | `vc1`–`vc3` | poll 응답 `－→○→△→×→○` |
| `dec` | `null` | `decideOk`, `decideNg` | 지원 승인/거절 결과 문구 |

`decideOk`는 결과 문구만 바꾸며 실제 crew membership 상태/화면을 바꾸지 않는다. `confirmPoll`만 `schedule_list`로 이동한다. `doApply`는 `apply_done`으로 이동한다.

## 3. 전체 screen inventory

| 구역 | ID | 화면 |
|---|---|---|
| A 공통/홈 | `login` | 1 ログイン／新規登録 |
|  | `onboarding` | 2 初回プロフィール設定 |
|  | `home_a` | 3 ホーム(クルー未所属) |
|  | `home_b` | 4 ホーム(クルー所属) |
|  | `notif` | 5 通知一覧 |
|  | `messages` | 6 メッセージ一覧 |
|  | `msg_thread` | 6b メッセージスレッド |
| B 크루 모집 | `crew_top` | 7 クルータブ(募集一覧/マイクルー) |
|  | `recruit_filter` | 8 募集検索・フィルター |
|  | `recruit_detail` | 9 募集詳細 |
|  | `apply_form` | 10 応募フォーム |
|  | `apply_done` | 10b 応募完了 |
|  | `share` | 11 共有シート |
|  | `recruit_create` | 12 クルー作成・募集投稿 |
|  | `applicants` | 13 応募者一覧 |
|  | `applicant_profile` | 14–15 応募者確認・承認/見送り |
| C 크루 페이지 | `crew_home` | 16 クルーホーム |
|  | `crew_members` | 17 クルーメンバー |
|  | `schedule_list` | 18 練習予定一覧 |
|  | `schedule_detail` | 19+22 練習予定詳細・出欠 |
|  | `schedule_create` | 20 練習予定作成 |
|  | `poll` | 21 日程調整投票 |
|  | `notices` | 23 お知らせ一覧 |
|  | `notice_detail` | 23b お知らせ詳細 |
|  | `notice_create` | 24 お知らせ作成 |
|  | `resources` | 25 練習資料 |
|  | `resource_song` | 26 曲・参考動画登録 |
|  | `resource_video` | 27 練習動画URL登録 |
|  | `crew_event` | 28 目標イベント |
|  | `crew_studio` | 29 スタジオ連携 |
| D 스테이지 | `stage_top` | 30 ステージトップ |
|  | `events` | 31 イベント一覧 |
|  | `event_filter` | 32 イベントフィルター |
|  | `event_detail` | 33 イベント詳細 |
|  | `lessons` | 34 レッスン/ワークショップ一覧 |
|  | `lesson_detail` | 35 レッスン詳細 |
| E 스튜디오 | `studio_top` | 36 スタジオトップ |
|  | `studio_map` | 37 地図+リスト |
|  | `studio_filter` | 38 スタジオフィルター |
|  | `studio_detail` | 39 スタジオ詳細 |
|  | `reco_input` | 40 クルー向け推薦条件 |
|  | `reco_result` | 41 推薦結果 |
| F 마이페이지 | `mypage` | 42 マイページ |
|  | `profile_view` | 43 プロフィール |
|  | `profile_edit` | 44 プロフィール編集 |
|  | `my_crews` | 45 管理/参加クルー |
|  | `my_apps` | 46 応募中 |
|  | `past_crews` | 47 過去活動 |
|  | `settings_notif` | 48 通知設定 |
|  | `blocked` | 49 ブロック済みユーザー |
|  | `stub` | 50–53 お知らせ/問い合わせ/規約/退会 stub |

## 4. 실제 확인 전이: 등록·홈·상단

| 출발 | 조작 | 도착/상태 | 필요 상태·전달 데이터 | 뒤로 |
|---|---|---|---|---|
| 전역 header | 未所属/クルー所属/リーダー | `home_a`/`home_b`, `role` 변경 | prototype role만 | 없음 |
| 좌측 screen index | 임의 screen | 해당 `screen` | 없음; 권한 우회 가능 | 없음 |
| `login` | LINE/Apple/메일 등록 | `onboarding` | provider/return URI는 전달하지 않음 | 없음 |
| `login` | 등록済み login | role에 따른 `home_a`/`home_b` | 세션은 mock | 없음 |
| `onboarding` | あとで設定 / STAGEをはじめる | role에 따른 home | 입력값은 보존하지 않음 | 없음 |
| `home_a` | 알림/메일 icon | `notif` / `messages` | 없음 | `goHome` |
| `home_a` | 모집 CTA/모집 card/전체 | `crew_top` 또는 `recruit_detail` | card ID는 전달하지 않음 | 화면별 고정 |
| `home_a` | 이벤트 CTA | `stage_top` | 없음 | tab |
| `home_b` | crew switcher | `crewIdx` 토글 | Prism Beat/Lumière mock | 동일 화면 |
| `home_b` | target/next/poll/notice/resource | `crew_event`, `schedule_detail`, `poll`, `notice_detail`, `resources` | 실제 crew/item ID 없음 | 대부분 `crew_home` 또는 고정 목록 |
| `home_b` | クルーページを開く | `crew_home` | 현재 `crewIdx`는 목적 화면 데이터에 연결되지 않음 | `goHome` |
| `notif` | notification card | `crew_home`, `poll`, `notice_detail`, `my_apps` | notification reference는 mock `go`에 고정 | home |
| `messages` | thread card | `msg_thread` | room/thread ID 미전달 | messages |

상단 🔔/✉️ line에는 한 줄에 두 handler가 있어 두 icon이 각각 `notif`, `messages`로 binding된다. 어느 텍스트 영역이 어느 handler인지는 template engine의 binding 순서에 의존한다.

## 5. 실제 확인 전이: 크루 탐색·지원·리더

| 출발 | 조작 | 도착/상태 | 역할/데이터 | 뒤로 |
|---|---|---|---|---|
| `crew_top` | さがす/マイクルー | `seg=find/mine` | role별 conditional card | 동일 |
| `crew_top` | filter | `recruit_filter` | 현재 filter 보존 없음 | `crew_top` |
| `recruit_filter` | 검색/clear/back | `crew_top` | filter 결과/쿼리 미전달 | `crew_top` |
| `crew_top`/`home_a` | recruitment card | `recruit_detail` | 선택 post ID 미전달 | `crew_top` |
| `crew_top` | ＋ create | `recruit_create` | leader 검증 없음 | `crew_top` |
| `crew_top` mine | crew card | `crew_home` | crew ID 미전달 | home |
| `crew_top` mine | pending applications | `applicants` | group/post ID 미전달 | `crew_top` |
| `recruit_detail` | event | `event_detail` | event ID 미전달 | `events`로 고정 |
| `recruit_detail` | leader profile | `profile_view` | leader ID 미전달 | `mypage`로 고정되어 origin 손실 |
| `recruit_detail` | 応募 | `apply_form` | post ID/조건 snapshot 미전달 | detail |
| `apply_form` | 応募を送信 | `apply_done` | `screen`만 변경 | detail로 직접 back 없음 |
| `apply_done` | share/other/status | `share`/`crew_top`/`my_apps` | application ID 미전달 | 각 고정 |
| `recruit_detail` | share | `share` | share URL 없음 | detail |
| `recruit_detail` | leader question | `msg_thread` | 문의 context가 화면 문구에만 존재 | messages |
| `recruit_create` | 이벤트再選択 | `events` | 선택 이벤트/return context 없음 | stage top 기준 |
| `recruit_create` | publish | `applicants` | 저장/publish state 없음 | `crew_top` |
| `applicants` | applicant card | `applicant_profile` | applicant ID 미전달 | applicants |
| `applicant_profile` | 承認/見送る | `dec` 문구만 변경 | leader 시각 상태; membership 변화 없음 | applicants |

공유 화면은 LINE/Instagram/link copy UI를 설명하지만 실제 handler가 있는 조작은 `閉じる`뿐이다. 등록 전 recipient → auth → 원래 모집 상세 복귀는 설명(`as`)에만 있고 구현되어 있지 않다.

## 6. 실제 확인 전이: 크루 활동

| 출발 | 조작 | 도착/상태 | 역할/데이터 | 뒤로 |
|---|---|---|---|---|
| `crew_home` | event/schedules/poll/notices/resources/members/studio | 각 C 화면 | crew ID 미전달 | `crew_home` |
| `crew_home` | leader menu | `applicants` | `isLeader` UI 조건 | applicants의 back은 `crew_top` |
| `crew_home` | past archive | `past_crews` | 없음 | `mypage`로 고정 |
| `crew_members` | applicant management | `applicants` | leader용 설명이나 handler 자체 role guard 없음 | applicants |
| `schedule_list` | item/＋ | `schedule_detail`/`schedule_create` | schedule ID 미전달 | list/home |
| `schedule_detail` | studio/resources | `studio_detail`/`resources` | 연관 ID 미전달 | studio back은 map으로 origin 손실 |
| `schedule_detail` | 参加/未定/不参加 | `att` 변경 | 현재 사용자만이라는 검증 없음 | 동일 |
| `schedule_create` | confirm/create | `schedule_list` | form/selected studio 미전달 | list |
| `schedule_create` | poll | `poll` | candidate dates 미전달 | poll back은 crew home |
| `schedule_create` | studio search/recommend | `studio_map`/`reco_input` | schedule draft return context 없음 | studio 경로 |
| `poll` | candidate | `v1`–`v3` cycle | 개별 사용자 mock | 동일 |
| `poll` | leader confirm | `schedule_list` | leader 검증/option link 없음 | list |
| `notices` | item/＋ | `notice_detail`/`notice_create` | notice/crew ID 미전달 | notices |
| `notice_create` | 投稿 | `notices` | 저장 없음 | notices |
| `resources` | song/video segment | `resSeg` 변경 | 없음 | 동일 |
| `resources` | add | `resource_song`/`resource_video` | crew/practice ID 미전달 | resources |
| resource form | 登録 | `resources` | URL/metadata 저장 없음 | resources |
| `crew_event` | detail/new target | `event_detail`/`events` | archive/current target 상태 없음 | crew home |
| `crew_studio` | studio/recommend | `studio_detail`/`reco_input` | crew/schedule context 미전달 | crew home 또는 reco |

## 7. 실제 확인 전이: 스테이지·스튜디오·마이페이지

| 출발 | 조작 | 도착/상태 | 역할/데이터 | 뒤로 |
|---|---|---|---|---|
| `stage_top` | event/lesson list 또는 card | `events`/`event_detail`, `lessons`/`lesson_detail` | 선택 ID 없음 | stage |
| `events` | filter/card | `event_filter`/`event_detail` | query/ID 없음 | events/stage |
| `event_filter` | 검색 | `events` | 조건 보존 없음 | events |
| `event_detail` | related recruitments | `crew_top` | event filter 미전달 | 일반 crew top |
| `event_detail` | create recruitment | `recruit_create` | target event 미전달 | crew top |
| `lessons` | card | `lesson_detail` | lesson ID 없음 | lessons |
| `lesson_detail` | related crew | `recruit_detail` | post ID 없음 | detail의 고정 back |
| `studio_top` | search/filter/map/card/recommend | `studio_filter`, `studio_map`, `studio_detail`, `reco_input` | 검색/crew/ID 없음 | 각 고정 |
| `studio_map` | marker/list card | `studio_detail` | studio ID 없음 | studio map |
| `studio_filter` | 검색 | `studio_map` | 조건 보존 없음 | map |
| `studio_detail` | practice create | `schedule_create` | crew/selected studio 미전달 | schedule list |
| `reco_input` | 계산 | `reco_result` | input snapshot 저장 없음 | crew studio |
| `reco_result` | candidate/recalculate | `studio_detail`/`reco_input` | candidate studio ID 없음 | input |
| `mypage` | profile/crew/app/archive/settings/blocked/stub | 해당 F 화면 | user/item ID 없음 | mypage |
| `profile_view` | edit | `profile_edit` | 본인/타인 문맥 구분 없음 | mypage |
| `profile_edit` | save | `profile_view` | 저장 없음 | profile |
| `my_crews` | crew/archive | `crew_home`/`past_crews` | crew ID 없음 | mypage |
| `my_apps` | application card | `recruit_detail` | application/post ID 없음 | mypage |
| `past_crews` | archive card | `crew_home` | read-only archive state 없음 | mypage |
| settings/blocked/stub | back | `mypage` | 없음 | mypage |

## 8. bottom navigation 동작

고정 tab은 `ホーム`, `クルー`, `ステージ`, `スタジオ`, `マイページ`다.

- Home: `goHome`; role이 guest면 `home_a`, 아니면 `home_b`
- Crew: 항상 `crew_top`
- Stage: 항상 `stage_top`
- Studio: 항상 `studio_top`
- My Page: 항상 `mypage`
- `login`, `onboarding`, `share`에서는 bottom tab을 숨긴다.
- 그 외 화면은 `tabOf()`의 고정 목록으로 active color만 결정한다.
- tab별 navigation stack과 state restoration은 없다.
- 현재 tab을 다시 눌러도 root로 state가 바뀔 뿐 scroll-to-top/refresh 규칙은 없다.

### production 권장 규칙

Flutter Web과 iOS 모두에 `go_router`의 `StatefulShellRoute.indexedStack` 같은 구조를 사용한다.

- 5개 tab마다 독립 `Navigator` stack 유지
- tab 전환은 기존 branch stack 복원
- active tab 재탭은 해당 branch root로 pop; 이미 root면 scroll-to-top 또는 명시적 refresh
- top notification/message는 shell 위의 global route
- AppBar back은 `context.pop()`, Web browser back은 URL history, iOS back gesture는 현재 branch stack을 사용
- canonical path 예: `/home`, `/crew`, `/crew/recruitments/:postId`, `/crews/:crewId/schedules/:id`, `/stage/events/:id`, `/studio/:id`, `/me`

## 9. deep link·auth·back 감사

| 항목 | prototype 현재 | production 권장 |
|---|---|---|
| Browser history | 없음 | screen마다 canonical URL push/replace |
| AppBar back | 각 화면에 고정 destination | origin stack pop; direct-entry면 안전한 tab root |
| iOS back | prototype 대상 아님 | nested Navigator stack/gesture |
| Deep link | 없음 | recruitment/event/lesson/studio 공개 path |
| Auth redirect | mock login → home/onboarding | 원래 internal URI를 검증·보존 후 resume |
| Profile incomplete | 없음 | auth 이후 `/onboarding?next=...` |
| 권한 거부 | 없음 | 정보 누출 없는 403/안내 후 허용 root |
| 삭제/비공개 | 없음 | 404/利用できません + safe fallback |
| 외부 URL return | 없음 | 앱 stack 유지; 필요 시 app link로 canonical detail 복귀 |
| blocked interaction | 일부 visual menu뿐 | 목록 projection/RPC/UI 모두 제한 |

공유 deep link는 unregistered recipient가 로그인/프로필 설정을 끝낸 뒤 원래 `postId`로 돌아오도록 해야 한다. `next`는 외부 URL을 허용하지 않고 앱 내부 canonical path만 allowlist한다.

## 10. 시각 전용·dead end

다음은 화면에는 있으나 실제 동작이 없다.

- share의 LINE/Instagram/link-copy 및 deep-link return
- `msg_thread` 메시지 입력/전송과 overflow 안전 메뉴
- 모집 생성 preview의 독립 동작
- applicant approval가 DB membership/화면 권한에 반영되는 동작
- crew member overflow, remove 관리
- schedule edit/delete, notice edit/unpin
- poll 일반 사용자의 `回答を送信`
- lesson `元の募集投稿・申込ページへ`
- studio `外部予約ページへ`
- blocked user `解除`
- notification setting toggle의 저장
- support/legal/logout/withdrawal의 개별 목적지(`stub` 하나로 합쳐짐)
- event/recruitment/studio/filter form 값과 선택 ID 전달
- archive read-only mode

## 11. 요구된 주요 flow 판정

| flow | prototype 판정 |
|---|---|
| A 등록 → onboarding → 미소속 home | **확인**, 실제 auth/data 저장 없음 |
| B 미소속 home → 모집 → filter/detail/apply/done/My Apps | **확인**, ID와 application state 없음 |
| C share → 외부 → 미등록 auth → 원 post 복귀 | **설명만 존재**, 구현 없음 |
| D event 선택 → 모집 생성 → applicant 승인 | 화면 이동 일부 **확인**, publish/승인 state는 mock |
| E crew activity | 모든 주요 화면 이동 **확인**, 저장·권한·archive 미구현 |
| F event → related recruitment/create | **확인**, event context 전달 없음 |
| G lesson → 외부 신청/related crew | related crew만 **확인**, 외부 신청은 dead end |
| H studio → map/filter/detail/booking/schedule | 화면 이동 **확인**, 외부 booking dead end |
| I crew recommendation | input/result/detail **확인**, 알고리즘/민감정보 경계 미구현 |
| J My Page | 주요 화면 **확인**, support/legal/account actions는 stub |

## 12. 역할·상태·전달 데이터 계약

HTML은 권한을 강제하지 않으므로 아래 “필요 역할”은 production에서 검사해야 할 조건이다. prototype의 좌측 screen index를 사용하면 이 조건을 모두 우회할 수 있다.

| 전이/상태 변경 | 필요 사용자 상태·역할 | 다음 화면에 필요한 데이터 | prototype 구현 수준 |
|---|---|---|---|
| login → onboarding/home | 비로그인 → 인증 완료 | validated `next`, auth callback 결과, profile completeness | 화면 교체만 확인 |
| home_a → recruitment detail | 인증·profile 완료, crew 미소속이 기본 | `postId`, origin, filter snapshot | 고정 mock card 전이 |
| recruitment detail → apply | active user, own group/member가 아님, 미차단 | `postId`, post 상태/조건 snapshot | form 전이만 확인 |
| apply → complete/My Apps | 개별 applicant | `applicationId`, `postId`, 결과 상태 | mock screen/state |
| recruitment create/publish | active crew leader | `crewId`, `targetEventId`, draft data | 역할 UI만 있고 권한 강제 없음 |
| applicant accept/reject | 해당 crew leader, pending application | `applicationId`, decision, updated membership | `dec` UI state만 변경 |
| crew switch | 둘 이상 active crew membership | `crewId`; 모든 crew-scoped query key | `crewIdx` mock만 변경 |
| practice/poll/announcement/resource mutation | active member 또는 leader별 권한 | `crewId` + resource ID + mutation result | 화면 또는 local mock state |
| exact station 사용 | 본인 또는 승인된 same-crew active member | public profile과 분리된 station projection | prototype에 권한/data 없음 |
| event detail → recruitment create | active leader | `eventId`, origin, optional crew draft | 화면 전이만 확인 |
| studio detail/recommendation → schedule | active crew member/leader 정책 | `crewId`, `studioId`, schedule draft | context 전달 구현 없음 |
| My Apps → recruitment detail | 본인 application | `applicationId`, `postId`, status | 고정 detail 전이 |
| archived crew/activity | current/former member 정책 미결 | `crewId`, archive mode, historical event ID | read-only 표시만 추론 |
| message/inquiry thread | 허용된 관계와 미차단 상태 | `roomId` 또는 recruitment inquiry context | mock thread 전이 |

state-only interaction도 production에서는 명시적 model로 분리해야 한다.

| prototype control | 현재 state 변화 | production 저장 범위 |
|---|---|---|
| guest/member/leader switch | `role` | 저장 대상 아님; session/profile/membership에서 계산 |
| crew switcher | `crewIdx` | 선택 crew ID를 session/local preference로 저장 가능 |
| find/mine segment | `seg` | 화면 local state 또는 query parameter |
| song/video segment | `resSeg` | 화면 local state |
| attendance buttons | `att` | practice attendance self-upsert RPC |
| poll ○/△/× | `v1`–`v3` | option별 self response |
| applicant approve/reject | `dec` | transactional decision RPC와 membership 결과 |

## 13. mutation·예외 이후 production 이동 규칙

| 상황 | 권장 이동/복구 규칙 |
|---|---|
| create 성공 | 생성된 canonical detail로 replace 또는 list로 pop하면서 해당 list만 invalidate |
| update 성공 | detail로 pop하고 최신 entity를 reload; 실패 시 edit form과 입력 유지 |
| delete/close 성공 | 삭제된 detail을 stack에서 제거하고 소유 list로 이동 |
| application 승인 | applicant list를 reload하고 승인된 사용자의 My Crew/Home action을 갱신 |
| crew 가입 | 현재 tab stack을 보존하되 Home을 소속 상태로 재평가하고 새 crew를 선택 가능하게 함 |
| 자발적 탈퇴 | 해당 crew stack을 제거하고 My Crews 또는 남은 active crew Home으로 이동 |
| leader에 의해 제외 | 열린 crew route를 permission/unavailable 화면으로 replace하고 private cache 폐기 |
| event archive | 같은 canonical detail을 archive read-only mode로 표시; 새 target 선택 CTA는 leader에게만 제공 |
| recruitment close | detail은 조건/history를 읽을 수 있으나 apply CTA를 제거하고 list cache를 갱신 |
| 외부 URL 복귀 | 원래 detail stack 유지; cold return은 canonical URL로 복원 |
| deep-link 진입 | 공개 preview → auth → profile completion → 검증된 원래 route 순으로 resume |
| permission denied | 민감 데이터는 표시하지 않고 해당 tab root 또는 안전한 public detail로 이동 |
| 삭제/비공개 content | 공통 unavailable 화면과 origin tab fallback 제공 |
| blocked interaction | 기존 detail/thread의 CTA와 cache를 즉시 무효화하고 안전한 list로 복귀 |

router 구현 시 `next`는 내부 canonical path allowlist만 허용하고, 외부 URL이나 임의 redirect 문자열을 그대로 실행하지 않는다.

# BandMatch 수동 QA 체크리스트

최종 점검일: 2026-07-26

## 사용 방법

- 설명은 한국어, 실제 조작 대상 UI 라벨은 일본어로 적었다.
- 각 케이스의 결과를 `[ ] Pass / [ ] Fail / [ ] Blocked`로 기록한다.
- 권장 테스트 계정:
  - A: `Mooyeon_test`
  - C: `Mooyeon_test2`
  - D: 어느 그룹·채팅방에도 속하지 않은 별도 비참가자 계정
- Hongo의 이메일로 만든 계정은 개발 테스트에 사용하지 않는다.
- 이메일, 비밀번호, anon key를 이 문서나 이슈에 기록하지 않는다.
- Supabase Table Editor/SQL 확인은 운영 데이터가 아닌 테스트 프로젝트에서 한다.
- 날짜·건수 검증 전 브라우저와 DB의 타임존 차이를 고려한다.

공통 실행 예:

```powershell
cd app
flutter run -d chrome --web-port 3000 `
  --dart-define=SUPABASE_URL=... `
  --dart-define=SUPABASE_ANON_KEY=...
```

## 1. Auth 및 프로필

### AUTH-01 이메일/비밀번호 로그인

| 항목 | 내용 |
|---|---|
| Preconditions | 비밀번호가 설정된 A 계정, 로그아웃 상태 |
| Test steps | 1. `/` 접속<br>2. 이메일 입력<br>3. 「パスワード」 선택<br>4. 비밀번호 입력 후 로그인 |
| Expected result | 로딩 후 `HomeScreen`이 표시되고 빈 화면이 발생하지 않는다. |
| Notes / edge cases | 잘못된 비밀번호에는 친절한 일본어 오류가 표시되어야 한다. `[ ] Pass [ ] Fail [ ] Blocked` |

### AUTH-02 매직 링크 로그인 및 만료 링크

| 항목 | 내용 |
|---|---|
| Preconditions | 로그아웃 상태, 수신 가능한 테스트 이메일 |
| Test steps | 1. 「メールリンク」 선택<br>2. 「サインイン用リンクを送る」 실행<br>3. 새 링크로 로그인<br>4. 로그아웃 후 만료된 예전 링크도 열어 본다. |
| Expected result | 새 링크는 Profile Setup 또는 Home으로 이동한다. 만료 링크는 빈 화면이 아니라 친절한 안내와 새 링크 요청 UI를 표시하고 URL을 정리한다. |
| Notes / edge cases | 페이지 로드만으로 링크가 자동 발송되면 안 된다. `[ ] Pass [ ] Fail [ ] Blocked` |

### AUTH-03 비밀번호 설정·재설정

| 항목 | 내용 |
|---|---|
| Preconditions | 매직 링크로 생성되어 비밀번호가 없거나 재설정할 테스트 계정 |
| Test steps | 1. 「パスワードを設定 / 再設定」 선택<br>2. 팝업에 이메일 입력<br>3. recovery 링크 열기<br>4. 8자 이상 새 비밀번호 저장<br>5. 로그아웃 후 새 비밀번호로 로그인 |
| Expected result | recovery 화면에서만 새 비밀번호를 설정하고, 설정한 비밀번호로 로그인된다. |
| Notes / edge cases | 8자 미만, 불일치 입력을 차단한다. `[ ] Pass [ ] Fail [ ] Blocked` |

### PROFILE-01 최초 프로필 설정

| 항목 | 내용 |
|---|---|
| Preconditions | Auth 계정은 있으나 `public.users` 행이 없는 일회용 테스트 계정 |
| Test steps | 1. 로그인<br>2. 「プロフィールを設定」에서 필수값 입력<br>3. 목적, 파트, 장르, 지역 선택<br>4. 「プロフィールを保存してはじめる」 |
| Expected result | `public.users`와 `user_purposes`, `user_parts`, `user_genres`, `user_areas`가 본인 ID로 저장되고 Home이 표시된다. |
| Notes / edge cases | 필수값 누락, 빈 마스터 데이터 상태도 확인한다. `[ ] Pass [ ] Fail [ ] Blocked` |

### PROFILE-02 프로필 편집과 My Page 즉시 반영

| 항목 | 내용 |
|---|---|
| Preconditions | A 로그인, 프로필 존재 |
| Test steps | 1. 「マイページ」→「プロフィール編集」<br>2. 표시 이름·경력·파트·장르·지역·목적 중 일부 변경<br>3. 「変更を保存」 |
| Expected result | 「プロフィールを更新しました」가 표시되고 My Page로 돌아오자마자 새 값이 보인다. C로 로그인하면 멤버 목록/상세에도 반영된다. |
| Notes / edge cases | Home까지 나갔다 다시 들어와야만 갱신되는 회귀가 없어야 한다. `[ ] Pass [ ] Fail [ ] Blocked` |

### PROFILE-03 프로필 이미지 업로드

| 항목 | 내용 |
|---|---|
| Preconditions | A 로그인, Web 브라우저, 5 MiB 이하 JPEG/PNG/WebP |
| Test steps | 1. 「プロフィール編集」<br>2. 「画像を変更」<br>3. 이미지 선택<br>4. My Page 및 C가 보는 멤버 상세 확인 |
| Expected result | 업로드 성공 안내가 표시되고 새 이미지가 본인 My Page와 공개 프로필에 보인다. |
| Notes / edge cases | 5 MiB 초과·미지원 형식은 차단. 현재 iOS picker는 미구현이므로 Web에서만 필수 확인. `[ ] Pass [ ] Fail [ ] Blocked` |

## 2. 멤버 검색·상세

### MEMBER-01 기본 목록과 개인정보 비노출

| 항목 | 내용 |
|---|---|
| Preconditions | A와 C 모두 `account_status = active`, 서로 차단하지 않음 |
| Test steps | 1. A 로그인<br>2. 「メンバーを探す」 열기<br>3. C 카드와 상세 열기<br>4. 브라우저 Network 응답도 확인 |
| Expected result | C는 보이고 A 자신은 목록에서 제외된다. 이메일, 전화, `auth_uid`, 결제·관리자 필드는 응답/UI에 없다. |
| Notes / edge cases | suspended/withdrawn 사용자가 있으면 함께 제외되는지 확인. `[ ] Pass [ ] Fail [ ] Blocked` |

### MEMBER-02 검색 필터

| 항목 | 내용 |
|---|---|
| Preconditions | A 로그인, 서로 다른 파트·장르·지역·경력·목적을 가진 테스트 프로필 |
| Test steps | 1. 각 필터를 하나씩 적용<br>2. 여러 필터 조합<br>3. 표시 이름 키워드 검색<br>4. 필터 초기화 |
| Expected result | 선택한 조건과 하나 이상 매칭되는 사용자만 표시되고 초기화 시 기본 목록으로 돌아온다. |
| Notes / edge cases | 선택 목록 내부는 OR, 서로 다른 필터 종류 사이는 AND로 동작하는지 실제 결과로 확인. `[ ] Pass [ ] Fail [ ] Blocked` |

### MEMBER-03 상세 공개 설정

| 항목 | 내용 |
|---|---|
| Preconditions | C의 `show_age`, `show_gender` 값을 각각 켜고 끌 수 있음 |
| Test steps | 1. A에서 C 상세 확인<br>2. C 설정 변경 후 다시 확인 |
| Expected result | 나이·성별은 공개 설정이 켜진 경우에만 보인다. 공개 프로필 필드만 표시된다. |
| Notes / edge cases | 상세에서 없는 bio/장비/활동 정보는 빈 섹션으로 깨지지 않아야 한다. `[ ] Pass [ ] Fail [ ] Blocked` |

### MEMBER-04 차단 사용자 제외

| 항목 | 내용 |
|---|---|
| Preconditions | A와 C가 목록에 보이는 상태 |
| Test steps | 1. A가 C 상세에서 「ブロックする」<br>2. 멤버 목록 새로고침<br>3. C 계정에서도 A 검색 |
| Expected result | 양쪽 일반 멤버 검색 결과에서 상대가 제외되고 새 메시지 요청을 보낼 수 없다. |
| Notes / edge cases | 차단 해제 후 다시 검색 가능한지 SAFETY-03에서 확인. `[ ] Pass [ ] Fail [ ] Blocked` |

## 3. 메시지 요청

### REQUEST-01 요청 전송과 중복 방지

| 항목 | 내용 |
|---|---|
| Preconditions | A/C 사이에 pending/accepted 요청과 차단 관계가 없음 |
| Test steps | 1. A가 C 상세에서 「メッセージを送る」<br>2. 1~300자 내용 전송<br>3. 같은 상세를 다시 확인<br>4. C에서 A 상세도 확인 |
| Expected result | 1건만 생성된다. A는 「メッセージリクエスト送信済み」, C는 「届いているリクエストを確認」 상태다. 반대 방향 추가 요청도 불가능하다. |
| Notes / edge cases | 공백, 301자, 빠른 더블클릭을 시험한다. DB에도 중복 행이 없어야 한다. `[ ] Pass [ ] Fail [ ] Blocked` |

### REQUEST-02 받은 요청과 pending 배지

| 항목 | 내용 |
|---|---|
| Preconditions | A→C pending 요청 1건 |
| Test steps | 1. C 로그인<br>2. Home의 메일 아이콘 배지 확인<br>3. 「メッセージリクエスト」 열기 |
| Expected result | 배지는 pending 수와 같고 A의 안전한 공개 정보와 요청 내용이 표시된다. 빈 inbox는 오류가 아닌 빈 상태다. |
| Notes / edge cases | accepted/rejected 과거 행은 목록에 표시될 수 있지만 pending 배지에는 포함되지 않는다. `[ ] Pass [ ] Fail [ ] Blocked` |

### REQUEST-03 승인과 채팅방 생성

| 항목 | 내용 |
|---|---|
| Preconditions | A→C pending 요청 |
| Test steps | 1. C가 「承認する」<br>2. 성공 안내 확인<br>3. A/C 각각 「メッセージ」 확인 |
| Expected result | 요청은 `accepted`, 채팅방은 정확히 1개, A/C 참가자 행이 각각 1개 생성된다. 양쪽 상세는 채팅 가능 상태다. |
| Notes / edge cases | 같은 요청을 다시 승인해도 방/참가자가 중복 생성되지 않아야 한다. `[ ] Pass [ ] Fail [ ] Blocked` |

### REQUEST-04 거절

| 항목 | 내용 |
|---|---|
| Preconditions | 별도의 pending 요청 |
| Test steps | 1. 수신자가 「お断りする」<br>2. 양쪽 상세와 DB 확인 |
| Expected result | 상태가 `rejected`가 되고 방이 생성되지 않는다. 송신자나 제3자는 승인/거절할 수 없다. |
| Notes / edge cases | 거절된 관계의 재요청 정책은 현재 UI의 종료 상태로 유지된다. `[ ] Pass [ ] Fail [ ] Blocked` |

## 4. 채팅

### CHAT-01 채팅방 목록과 비참가자 차단

| 항목 | 내용 |
|---|---|
| Preconditions | A/C accepted 요청과 방 존재, D는 비참가자 |
| Test steps | 1. A/C 각각 「メッセージ」 확인<br>2. D 로그인 후 목록 확인<br>3. 가능하면 D 세션으로 A/C `room_id`에 `get_room_messages` 호출 |
| Expected result | A/C에는 같은 방이 보이고 D에는 보이지 않는다. D의 RPC 호출은 거절된다. |
| Notes / edge cases | `room_participants.left_at`가 있는 사용자는 활성 참가자로 취급하지 않는다. `[ ] Pass [ ] Fail [ ] Blocked` |

### CHAT-02 메시지 송수신

| 항목 | 내용 |
|---|---|
| Preconditions | A/C 활성 참가자, 차단 관계 없음 |
| Test steps | 1. A가 1~1000자 메시지 전송<br>2. A 화면 즉시 표시 확인<br>3. C가 방을 열어 수신 확인 후 답장<br>4. A가 다시 방을 열어 확인 |
| Expected result | 각 메시지가 한 번만 DB에 저장되고 송신자 화면에 즉시 표시된다. 거짓 실패/새로고침 경고가 없다. |
| Notes / edge cases | 공백, 1001자, 더블클릭은 차단. Realtime이 아니므로 이미 열린 상대 화면에는 자동 도착하지 않는다. `[ ] Pass [ ] Fail [ ] Blocked` |

### CHAT-03 Home unread 건수

| 항목 | 내용 |
|---|---|
| Preconditions | C의 방이 읽음 상태 |
| Test steps | 1. A가 C에게 메시지 2개 전송<br>2. C가 새로 로그인하거나 Home으로 돌아와 배지 확인<br>3. C가 방을 연 뒤 Home 복귀 |
| Expected result | 열기 전 Home unread는 2 증가하고, 방을 연 후 해당 메시지는 unread에서 제외된다. |
| Notes / edge cases | 배지는 화면 진입·복귀 시 재조회되며 Realtime이 아니다. `[ ] Pass [ ] Fail [ ] Blocked` |

### CHAT-04 방별 unread와 목록 복귀 갱신

| 항목 | 내용 |
|---|---|
| Preconditions | C에게 unread가 있는 채팅방 |
| Test steps | 1. C가 「メッセージ」 목록 열기<br>2. 방 카드의 숫자 확인<br>3. 방 열기<br>4. 뒤로 가기로 목록 복귀 |
| Expected result | 방별 unread가 정확하고, 복귀 직후 해당 카드 배지가 사라진 뒤 서버 값과 동기화된다. |
| Notes / edge cases | 갱신 실패 시 기존 목록은 유지되고 친절한 오류만 표시되어야 한다. `[ ] Pass [ ] Fail [ ] Blocked` |

### CHAT-05 내 메시지는 내 unread가 아님

| 항목 | 내용 |
|---|---|
| Preconditions | A/C 방 존재 |
| Test steps | 1. A가 메시지 전송<br>2. A의 Home과 방 목록 배지 확인<br>3. C의 배지 확인 |
| Expected result | A 자신의 unread는 증가하지 않고 C의 unread만 증가한다. |
| Notes / edge cases | 같은 초에 여러 메시지를 보내도 각각 정확히 계산되는지 확인. `[ ] Pass [ ] Fail [ ] Blocked` |

### CHAT-06 차단 후 채팅 제한

| 항목 | 내용 |
|---|---|
| Preconditions | A/C 채팅방 존재 |
| Test steps | 1. A가 C 차단<br>2. 양쪽 방 목록 확인<br>3. 기존 room ID에 `send_room_message` 호출 시도 |
| Expected result | 일반 UI의 방 목록에서 상대 방이 제외되고 양쪽 모두 새 메시지 전송이 거절된다. |
| Notes / edge cases | 현재 read RPC는 참가자 여부를 검사하지만 차단 여부는 별도로 검사하지 않는다. 기존 메시지 직접 RPC 조회 정책은 권한 문서의 제한 사항을 참고한다. `[ ] Pass [ ] Fail [ ] Blocked` |

## 5. 그룹

### GROUP-01 그룹 생성·편집과 즉시 갱신

| 항목 | 내용 |
|---|---|
| Preconditions | A 로그인 |
| Test steps | 1. 「マイページ」→「バンド・グループ」<br>2. 「グループを作成」<br>3. 이름·소개·장르·모집 파트·지역 저장<br>4. 목록에서 다시 편집 |
| Expected result | 생성·편집 직후 My Groups에 새 값이 보이며 My Page까지 나갔다 올 필요가 없다. A는 `管理`로 표시된다. |
| Notes / edge cases | 이름 빈값/61자, 소개 1001자를 차단한다. `[ ] Pass [ ] Fail [ ] Blocked` |

### GROUP-02 관리 그룹과 가입 그룹 구분

| 항목 | 내용 |
|---|---|
| Preconditions | A는 자신의 그룹 관리자, C는 승인되어 일반 멤버 |
| Test steps | 1. A/C 각각 「バンド・グループ」 확인<br>2. 카드 액션 비교 |
| Expected result | A는 관리 그룹에 편집·모집 관리 액션이 있고, C는 참가 중 그룹에 멤버 목록 중심 액션만 있다. |
| Notes / edge cases | C에게 그룹 편집이나 모집 관리 버튼이 노출되지 않아야 한다. `[ ] Pass [ ] Fail [ ] Blocked` |

### GROUP-03 그룹 멤버 목록 권한

| 항목 | 내용 |
|---|---|
| Preconditions | A 관리자, C 활성 멤버, D 비멤버 |
| Test steps | 1. A/C가 「メンバー」 목록 확인<br>2. D 세션으로 `get_group_members` 호출 |
| Expected result | A/C는 활성 멤버 목록과 역할을 볼 수 있다. D는 거절된다. |
| Notes / edge cases | left/removed 사용자는 목록에 보이지 않아야 한다. `[ ] Pass [ ] Fail [ ] Blocked` |

### GROUP-04 일반 멤버 탈퇴

| 항목 | 내용 |
|---|---|
| Preconditions | C가 A 그룹의 active `member` |
| Test steps | 1. C가 멤버 목록에서 「グループを退会する」<br>2. 확인<br>3. My Groups와 DB 확인 |
| Expected result | C의 `membership_status = left`, `left_at` 기록. C 목록에서 그룹이 사라지고 활성 멤버 목록에서도 제외된다. |
| Notes / edge cases | 관리자는 이 흐름으로 탈퇴할 수 없다. `[ ] Pass [ ] Fail [ ] Blocked` |

### GROUP-05 관리자의 멤버 제외

| 항목 | 내용 |
|---|---|
| Preconditions | A 관리자, C active `member` |
| Test steps | 1. A가 멤버 목록에서 C의 「メンバーから外す」<br>2. 확인<br>3. A/C 목록과 DB 확인 |
| Expected result | C의 `membership_status = removed`, `left_at`, `removed_by = A`가 기록되고 활성 목록에서 사라진다. |
| Notes / edge cases | 일반 멤버가 다른 멤버를 제외하거나 관리자를 제외할 수 없어야 한다. `[ ] Pass [ ] Fail [ ] Blocked` |

## 6. 모집 글·지원

### RECRUIT-01 모집 글 생성·편집

| 항목 | 내용 |
|---|---|
| Preconditions | A가 active 그룹 관리자 |
| Test steps | 1. My Groups에서 관리 그룹→「募集投稿」<br>2. 「募集を作成」<br>3. 제목·본문·파트·장르·지역과 `公開中` 저장<br>4. 다시 편집 |
| Expected result | 저장 직후 목록이 갱신되고 `open` 글은 공개 모집 목록에 보인다. |
| Notes / edge cases | 일반 멤버에게 생성·편집 액션이 없어야 한다. `下書き`/`終了`은 공개 목록에서 제외. `[ ] Pass [ ] Fail [ ] Blocked` |

### RECRUIT-02 공개 목록·상세

| 항목 | 내용 |
|---|---|
| Preconditions | active 그룹의 open 글과 draft/closed 글 존재 |
| Test steps | 1. C 로그인<br>2. 「募集を探す」<br>3. open 글 상세 열기 |
| Expected result | open 글만 보이며 그룹명, 제목, 본문, 모집 파트, 장르, 지역 등 안전한 정보만 표시된다. |
| Notes / edge cases | inactive 그룹 글은 제외되어야 한다. `[ ] Pass [ ] Fail [ ] Blocked` |

### RECRUIT-03 지원과 중복 방지

| 항목 | 내용 |
|---|---|
| Preconditions | C는 A 그룹의 active 멤버/관리자가 아니며 차단 관계 없음 |
| Test steps | 1. C가 모집 상세에서 「応募する」<br>2. 500자 이하 메시지 입력<br>3. 다시 같은 글 확인 |
| Expected result | `pending` 지원 1건이 생성되고 「応募済み」 상태로 추가 지원이 막힌다. 거짓 오류 snackbar가 없다. |
| Notes / edge cases | 501자, 더블클릭, 자기 그룹 지원을 차단한다. `[ ] Pass [ ] Fail [ ] Blocked` |

### RECRUIT-04 pending 지원 배지

| 항목 | 내용 |
|---|---|
| Preconditions | C→A 관리 그룹 pending 지원 1건 |
| Test steps | 1. A 로그인<br>2. 「マイページ」의 「バンド・グループ」 배지 확인<br>3. 그룹의 「募集投稿」 및 「応募一覧」 진입 |
| Expected result | 관리 중인 모든 active 그룹의 pending 지원 합계가 My Page와 모집 관리 경로에 표시되고, 처리 후 감소한다. |
| Notes / edge cases | 일반 멤버에게 관리자용 pending 배지가 표시되지 않아야 한다. `[ ] Pass [ ] Fail [ ] Blocked` |

### RECRUIT-05 지원 승인·거절

| 항목 | 내용 |
|---|---|
| Preconditions | 서로 다른 pending 지원 2건 |
| Test steps | 1. A가 「応募一覧」에서 하나는 「承認する」<br>2. 다른 하나는 「お断りする」 |
| Expected result | 승인 건은 `accepted`이고 지원자가 active `member`가 된다. 거절 건은 `rejected`이며 멤버가 되지 않는다. 수신 그룹 관리자 외 사용자는 처리할 수 없다. |
| Notes / edge cases | 이미 처리된 지원은 재처리되지 않아야 한다. `[ ] Pass [ ] Fail [ ] Blocked` |

### RECRUIT-06 탈퇴·제외 후 재지원

| 항목 | 내용 |
|---|---|
| Preconditions | C가 과거 지원 승인으로 A 그룹 멤버가 된 후 left 또는 removed 상태 |
| Test steps | 1. C로 같은 open 모집 글 상세 열기<br>2. 다시 지원<br>3. A가 다시 승인 |
| Expected result | 새 pending 지원이 생성될 수 있고, 승인 후 기존 `group_members` 이력 행이 active `member`로 재활성화된다. |
| Notes / edge cases | 과거 accepted/rejected 지원 이력은 유지되고 pending 중복만 금지된다. `[ ] Pass [ ] Fail [ ] Blocked` |

### RECRUIT-07 차단 관계의 지원 제한

| 항목 | 내용 |
|---|---|
| Preconditions | C와 그룹 소유자 A 사이 차단 관계 |
| Test steps | 1. C가 A 그룹 모집 상세 확인·지원 시도<br>2. 차단 전에 만든 pending 지원이 있다면 A가 승인 시도 |
| Expected result | 새 지원과 승인이 모두 거절된다. |
| Notes / edge cases | 그룹 내 다른 admin과의 관계가 아니라 현재 구현은 그룹 `created_by`와 지원자의 차단 관계를 기준으로 한다. `[ ] Pass [ ] Fail [ ] Blocked` |

## 7. 안전 기능

### SAFETY-01 사용자 차단

| 항목 | 내용 |
|---|---|
| Preconditions | A/C active, 차단 관계 없음 |
| Test steps | 1. A가 C 상세에서 「ブロックする」<br>2. 확인 다이얼로그 승인<br>3. 멤버 검색, 요청, 채팅, 모집 지원 확인 |
| Expected result | 차단이 1건 생성되고 관련 새 상호작용이 제한된다. 자기 자신 차단은 불가능하다. |
| Notes / edge cases | 같은 사용자를 반복 차단해도 중복 행이 생기지 않는다. `[ ] Pass [ ] Fail [ ] Blocked` |

### SAFETY-02 차단 목록

| 항목 | 내용 |
|---|---|
| Preconditions | A가 C를 차단 |
| Test steps | 1. A의 「マイページ」→「ブロックしたユーザー」<br>2. 목록 정보 확인<br>3. C 계정에서 동일 메뉴 확인 |
| Expected result | A에게 C의 안전한 공개 요약과 차단 시각이 보인다. C는 자신을 차단한 A를 이 목록으로 알 수 없다. |
| Notes / edge cases | 이메일·전화·`auth_uid`는 표시되지 않는다. `[ ] Pass [ ] Fail [ ] Blocked` |

### SAFETY-03 차단 해제

| 항목 | 내용 |
|---|---|
| Preconditions | A가 C를 차단 |
| Test steps | 1. 차단 목록에서 「ブロックを解除」<br>2. 확인<br>3. 멤버 검색과 가능한 상호작용 재확인 |
| Expected result | A→C block 행이 삭제되고, 다른 방향 block이 없다면 검색·새 요청/메시지 제한이 해제된다. |
| Notes / edge cases | C→A 차단도 별도로 존재하면 양방향 제한은 유지된다. `[ ] Pass [ ] Fail [ ] Blocked` |

### SAFETY-04 신고

| 항목 | 내용 |
|---|---|
| Preconditions | A 로그인, C active |
| Test steps | 1. C 상세에서 「通報する」<br>2. 사유 선택 및 1000자 이하 메모<br>3. 제출 |
| Expected result | 성공 안내가 표시되고 `reports`에 `reporter_id=A`, `target_user_id=C`, 선택 사유, `status=open`이 저장된다. |
| Notes / edge cases | 자기 신고, 잘못된 사유, 1001자 메모를 차단. 관리자 dashboard/자동 제재는 없다. `[ ] Pass [ ] Fail [ ] Blocked` |

## 8. 10~15분 회귀 Smoke Test

아래 순서는 이미 프로필이 있는 A/C 계정과 기존 테스트 그룹을 사용한다.

| 단계 | 조작 | 기대 결과 |
|---|---|---|
| 1 | A 이메일/비밀번호 로그인 | Home 표시, blank 없음 |
| 2 | 「マイページ」→「プロフィール編集」에서 표시 이름 일부 수정·저장 | My Page에 즉시 새 값 |
| 3 | 「メンバーを探す」에서 C 검색·상세 열기 | 필터와 공개 상세 정상 |
| 4 | A→C 메시지 요청 생성 또는 기존 관계 상태 확인 | 중복 생성 없음 |
| 5 | C 로그인, 요청 배지 확인 후 승인 | 요청 accepted, 방 1개 |
| 6 | C가 채팅에서 A에게 메시지 전송 | 즉시 한 번 표시 |
| 7 | A 로그인, Home/방 목록 unread 확인 후 방 열기 | unread 표시 후 읽음 처리 |
| 8 | A 관리 그룹의 「募集投稿」에서 open 글 확인 | 관리 목록과 공개 목록 정상 |
| 9 | C가 open 글에 지원 | pending 1건, 중복 없음 |
| 10 | A가 My Page pending 배지 확인 후 「応募一覧」에서 승인/거절 | 상태와 배지 갱신 |
| 11 | 승인된 C의 그룹 멤버 목록 확인 | C가 active member로 표시 |
| 12 | A가 테스트 사용자 차단→차단 목록 확인→해제 | 제한 및 복구 정상 |
| 13 | A 로그아웃 | AuthScreen 복귀, 새로고침 후에도 유지 |

Smoke 결과:

- `[ ] Pass`
- `[ ] Fail`
- `[ ] Blocked`
- 실행일:
- 실행자:
- 브라우저/OS:
- Supabase 프로젝트:
- 관련 이슈:

## 9. DB 확인용 참고 쿼리

아래 쿼리는 테스트 프로젝트에서 ID를 명시해 읽기 전용으로 실행한다.

```sql
-- 요청, 방, 참가자
select id, sender_user_id, receiver_user_id, status, created_at
from public.message_requests
order by created_at desc;

select id, request_id, created_at
from public.message_rooms
order by created_at desc;

select room_id, user_id, joined_at, left_at, last_read_at
from public.room_participants
order by created_at desc;

-- 메시지
select id, room_id, sender_user_id, message_type, body, created_at
from public.messages
order by created_at desc;

-- 그룹 멤버 이력
select group_id, user_id, role, membership_status, joined_at, left_at, removed_by
from public.group_members
order by updated_at desc;

-- 모집 지원
select recruitment_post_id, group_id, applicant_user_id, status,
       responded_at, responded_by, created_at
from public.recruitment_applications
order by created_at desc;

-- 차단과 신고
select blocker_id, blocked_id, created_at
from public.blocks
order by created_at desc;

select reporter_id, target_user_id, reason, status, created_at
from public.reports
order by created_at desc;
```


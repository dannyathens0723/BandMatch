# STAGE 미결 제품 결정

이 문서는 prompt에서 이미 고정한 결정을 반복하지 않는다. 아래 항목만 실제 구현 전 추가 결정이 필요하다.

## 1. 출시 인증 provider

- 질문: email 외 LINE/Apple을 MVP에 포함하는가?
- 중요성: wireframe CTA, OAuth callback, iOS Apple 정책, account linking 범위가 달라진다.
- 선택지: email만 / email+Apple / email+LINE+Apple
- 권장 기본값: Phase 1은 안정 email flow 유지, provider adapter를 설계하고 LINE/Apple은 계정 linking 정책 확정 후 추가
- 차단 phase: Phase 1 auth UI 최종화, iOS 출시
- wireframe 전 결정 필요: 아니오. placeholder/feature flag 가능

## 2. 최소 연령·미성년자 보호

- 질문: 최소 가입 연령, 보호자 동의, 성인-미성년 DM/crew 참가 제한은 무엇인가?
- 중요성: 일본 사용자, 10대, offline 연습/공연을 다룬다.
- 선택지: 13+ 공통 + 안내 / age band별 제한 / 미성년 보호자 동의와 contact 제한
- 권장 기본값: birth date 비공개, age band 표시, 신고/차단 상시 노출, 제품/법률 검토 전 미성년 exact location/자유 DM을 보수적으로 제한
- 차단 phase: Phase 2 public profile/지원, Phase 6 release
- wireframe 전 결정 필요: 기본 layout은 아니지만 실제 지원/메시지 launch 전 필수

## 3. 일반 1:1 메시지 요청의 STAGE 범위

- 질문: 현재 자유 member-to-member request를 유지할지, recruitment inquiry context로 제한할지?
- 중요성: prototype은 모집 문의 thread를 보여주며 서비스는 LINE 대체 채팅을 목표로 하지 않는다.
- 선택지: 자유 gated DM 유지 / recruitment inquiry만 / 승인 후 crew member 간 제한 대화
- 권장 기본값: recruitment/lesson 등 명시적 context가 있는 inquiry 중심으로 제한하고 기존 방은 compatibility로 유지
- 차단 phase: Phase 2 메시지 CTA/copy
- wireframe 전 결정 필요: detail/message action 구현 전 필요

## 4. crew leader 승계·관리자 탈퇴

- 질문: 유일 leader가 탈퇴/휴면/withdrawn일 때 누가 crew를 관리하는가?
- 중요성: 현재 RPC는 admin 탈퇴를 지원하지 않는다. 지속 crew와 archive ownership에 필수다.
- 선택지: leader transfer 필수 / 복수 admin / operator recovery / crew close
- 권장 기본값: active admin 최소 1명, 탈퇴 전 transfer 필수, operator recovery audit 제공
- 차단 phase: Phase 3 crew lifecycle
- wireframe 전 결정 필요: leader settings/member management 구현 전 필요

## 5. crew visibility와 archive 공개 범위

- 질문: current/past crew, practice, resource, member list를 누가 볼 수 있는가?
- 중요성: 활동 이력을 보존하지만 station, attendance, practice video는 민감하다.
- 선택지: 모든 archive member-only / public summary+private detail / 완전 public 선택 가능
- 권장 기본값: crew/event명과 public summary만 공개 가능; member, schedule, attendance, practice resource는 active member/허용된 former member 정책
- 차단 phase: Phase 3 archive/RLS
- wireframe 전 결정 필요: archive screen을 실제 data에 연결하기 전

## 6. former member의 과거 자료 접근

- 질문: left/removed member가 참가 당시 practice/resource/archive를 계속 볼 수 있는가?
- 중요성: “활동 기록 보존”과 안전/제외 효과가 충돌한다.
- 선택지: 즉시 전부 차단 / 본인 참가 event만 read / leader가 archive access 선택
- 권장 기본값: removed는 즉시 차단, voluntary left는 본인이 참여한 public-safe archive만 제한 read; exact station/member-private data는 항상 차단
- 차단 phase: Phase 3, Phase 6
- wireframe 전 결정 필요: archive permission 구현 전

## 7. schedule poll 응답 공개 수준

- 질문: 멤버별 ○△×를 전원에게 보여줄지 aggregate만 보여줄지?
- 중요성: 개인 일정은 민감하며 추천/attendance UX에 영향.
- 선택지: member 이름까지 공개 / aggregate+본인 응답 / leader만 상세
- 권장 기본값: 일반 member는 aggregate와 본인 응답, leader는 운영에 필요한 상세
- 차단 phase: Phase 3 poll
- wireframe 전 결정 필요: poll 상세 UI 전

## 8. crew resource 작성 권한

- 질문: 곡/참고/연습 영상 URL을 leader만 또는 모든 member가 추가할 수 있는가?
- 중요성: 악성 URL, 삭제 충돌, activity archive 품질.
- 선택지: leader only / member add+leader moderate / member 자유 편집
- 권장 기본값: active member add, 자기 항목 수정, leader hide/remove; audit actor 보존
- 차단 phase: Phase 3 resources
- wireframe 전 결정 필요: resource form mutation 전

## 9. event/lesson 수집·검수 운영

- 질문: 누가 정보를 등록하고 AI/외부 수집 row를 어떻게 검수/만료하는가?
- 중요성: 잘못된 일정·비용·URL은 오프라인 피해로 이어진다.
- 선택지: operator only / organizer self-service / AI draft+operator review / 혼합
- 권장 기본값: AI/크롤링은 draft만 생성, source URL과 last verified 필수, operator/verified organizer가 publish
- 차단 phase: Phase 4
- wireframe 전 결정 필요: static card는 가능, production publish 전 필수

## 10. professional verification 증거와 SLA

- 질문: 어떤 증거를 받고 누가 언제 검토하며 만료/취소하는가?
- 중요성: verified badge 신뢰, 개인정보 보관, lesson posting 권한.
- 선택지: self-claim만 / operator 수동 / 외부 자격 연계
- 권장 기본값: self-claim과 operator-verified를 분리하고 최소 evidence metadata + review audit; 증거 원문 보관 기간은 법률 검토
- 차단 phase: Phase 4 lesson publish
- wireframe 전 결정 필요: badge 시각은 가능, verified action 전 필수

## 11. nearest station source·노출 상세

- 질문: station master provider와 same-crew 공개 단위(역명만/노선 포함/도보 범위)는?
- 중요성: privacy, 데이터 품질, 추천 정확도, provider license.
- 선택지: 공공/라이선스 master / route provider master / 수동 free text
- 권장 기본값: stable station code master, free text 금지, same active crew에는 역명만; 좌표와 상세 이동 정보는 서버 계산 전용
- 차단 phase: Phase 2 profile, Phase 5 recommendation
- wireframe 전 결정 필요: profile input 구현 전

## 12. studio recommendation 알고리즘·비용

- 질문: 근사 좌표 방식과 route API 중 무엇을 언제 사용하며 비용 한도는?
- 중요성: 정확도, latency, 개인정보 제3자 전송, API 비용.
- 선택지: 좌표/거리 MVP / route API / hybrid cache
- 권장 기본값: Shinjuku MVP는 좌표+capacity+price heuristic, `method/version` abstraction을 두고 route API beta를 측정
- 차단 phase: Phase 5
- wireframe 전 결정 필요: 아니오. UI는 두 방식을 수용하도록 이미 설계 가능

## 13. map/provider와 외부 booking URL 정책

- 질문: map SDK/provider, booking URL allowlist, 잘못된 URL 신고 방식은?
- 중요성: Web/iOS SDK 비용·약관과 피싱 위험.
- 선택지: Google/Mapbox/정적 지도, 모든 HTTPS/allowlist/운영 검수
- 권장 기본값: provider abstraction + 운영 검수된 HTTPS URL + domain 표시/외부 이동 확인
- 차단 phase: Phase 5
- wireframe 전 결정 필요: static studio card는 아니지만 실제 map/booking 전 필요

## 14. 공개 deep link의 로그인 전 정보량

- 질문: 비로그인 recipient에게 recruitment/event/lesson/studio 정보를 어디까지 보여줄 것인가?
- 중요성: 공유 전환율과 minor/profile privacy의 균형.
- 선택지: 전체 public detail / 요약 후 login / 모든 내용 login 필수
- 권장 기본값: organizer/crew public summary와 조건은 표시, applicant/member/profile private 정보와 action은 login 후
- 차단 phase: Phase 2 deep link
- wireframe 전 결정 필요: route 구현 전 필요

## 15. 알림 channel과 기본값

- 질문: in-app 외 push/email을 언제 추가하고 어떤 event가 기본 on인가?
- 중요성: practice/poll/deadline usability, 청소년 알림, iOS permission.
- 선택지: in-app only / push opt-in / 중요 알림 email
- 권장 기본값: MVP in-app, Phase 6에 push opt-in; notification preference를 종류별로 설계
- 차단 phase: Phase 3 편의 기능, Phase 6 release
- wireframe 전 결정 필요: 아니오. in-app 상태로 구현 가능

## 16. content deletion·보존 기간

- 질문: withdrawn user, ended crew, expired event, 신고 content, verification evidence를 얼마나 보존하는가?
- 중요성: archive 가치, 개인정보, 분쟁/audit, 운영 비용.
- 선택지: 즉시 삭제 / 기간별 soft-delete / 법적 hold
- 권장 기본값: public visibility와 physical deletion 분리, status/archive + 명시적 retention schedule
- 차단 phase: Phase 6 및 account deletion
- wireframe 전 결정 필요: 아니오. 단, hard delete 구현 전 필수


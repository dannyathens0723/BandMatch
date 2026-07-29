# STAGE Migration 034 상세 사양

작성일: 2026-07-30 (JST)  
대상 브랜치: `stage-redesign`  
예정 마이그레이션: `034_stage_domain_genre_access_and_activation.sql`  
문서 상태: 구현 전 검토용 사양  
이번 작업 범위: 분석 및 데이터베이스 설계만 수행

> 이 문서는 Migration 034를 구현하거나 실행하지 않는다.  
> `supabase/migrations/001`~`033`, Flutter 소스, 원격 Supabase 상태를 변경하지 않는다.

---

## 1. Executive recommendation

Migration 034는 하나의 짧고 원자적인 트랜잭션으로 다음 두 작업만 수행하는 것이 가장 안전하다.

1. 활성 장르를 도메인별로 읽는 버전 고정 RPC
   `public.get_active_genres_v1(p_domain text)`를 추가한다.
2. Migration 032가 정확히 준비해 둔 11개 Dance 장르만
   `is_active = true`로 전환한다.

권장 결론은 다음과 같다.

- RPC가 허용하는 도메인은 `band`, `dance` 두 값으로 제한한다.
- `multi_domain`은 사용자 활동 도메인 값이지 장르 도메인 값이 아니므로 거부한다.
- RPC는 명시적인 안전 필드만 반환하고 `sort_order`, `code` 순으로 정렬한다.
- 현재 활성 장르는 이미 공개 마스터 데이터이므로 RPC 실행 권한은
  `anon`, `authenticated`에 부여하는 것을 권장한다.
- 함수 자체는 Migration 033의 읽기 전용 마스터 RPC와 동일하게
  `STABLE`, `SECURITY INVOKER`, 고정 `search_path`를 사용한다.
- 기존 Flutter가 아직 `genres` 테이블을 직접 조회하므로
  `genres_read_active` 정책과 직접 SELECT 권한은 Migration 034에서 변경하지 않는다.
- 11개 행의 사전 상태가 정확하지 않으면 자동 복구하거나 일부만 활성화하지 않고
  전체 마이그레이션을 실패시킨다.
- 예상하지 못한 `dance_*` 코드 또는 승인 목록 밖의 `domain = 'dance'` 행이 있으면 실패한다.
- 승인된 Dance 장르가 사용자, 그룹, 모집 게시물에 이미 연결되어 있으면 실패한다.
- Web 호환 빌드가 실제 배포되어 있고 오래된 캐시가 제거되었음을 확인하거나,
  현재 환경이 외부 사용자가 없는 개발 전용임을 명시적으로 확인하기 전에는
  Dance 활성화를 실행하지 않는다.
- Dance 기능을 되돌릴 때는 행을 삭제하지 않고 후속 forward migration으로
  같은 11개 행만 다시 비활성화한다. RPC와 UUID는 유지한다.

현재 저장소의 코드 상태는 Migration 034 구현 준비에 가깝지만,
실행 준비 상태는 **조건부 보류**다. 특히 RPC의 `anon` 권한과 Web 배포/캐시
활성화 게이트를 사람이 승인해야 한다.

---

## 2. Confirmed baseline

### 2.1 저장소와 마이그레이션 기준

확인한 로컬 기준은 다음과 같다.

- 브랜치: `stage-redesign`
- 확인 시점 HEAD: `7185f2e` (`fix: scope legacy genre queries to band domain`)
- 기존 SQL 마이그레이션: `001`~`033`
- 현재 최신 SQL:
  `supabase/migrations/033_stage_performance_roles.sql`
- Migration 034 파일은 아직 생성하지 않는다.

원격 Supabase가 로컬 마이그레이션 001~033과 완전히 동일한지는 이번 분석에서
원격 쿼리를 실행하지 않았으므로 저장소만으로 확정할 수 없다. 실제 적용 직전에는
아래의 preflight와 수동 검증 쿼리로 원격 상태를 확인해야 한다.

### 2.2 현재 `public.genres` 계약

초기 스키마와 Migration 032를 합친 현재 계약은 다음과 같다.

- 기본 식별자: `id uuid`
- 기존 고유 필드: `code`, `name`, `sort_order`
- 활성 상태: `is_active boolean`
- STAGE 확장 필드:
  - `domain text`
  - `category text`
- 허용 장르 도메인:
  - `band`
  - `dance`
- 기존 레코드는 Migration 032에서 `domain = 'band'`로 보존되었다.
- Migration 032의 11개 Dance 레코드는 `is_active = false`로 준비되었다.
- 기존 `set_updated_at` 트리거가 `genres`에 연결되어 있으므로
  활성화 UPDATE 시 11개 Dance 행의 `updated_at`은 변경된다.

### 2.3 현재 RLS 및 권한 기준

현재 `genres`는 RLS가 활성화되어 있다.

- `genres_read_active`
  - 대상: `anon`, `authenticated`
  - 작업: `SELECT`
  - 조건: 활성 행만 허용
- `master_data_admin_manage_genres`
  - 대상: `authenticated`
  - 관리 쓰기는 기존 관리자 판정에 한정

따라서 현재 활성 장르는 로그인 전후 모두 읽을 수 있고,
일반 사용자의 INSERT/UPDATE/DELETE 권한은 새로 열려 있지 않다.
Migration 034는 이 정책들을 변경하지 않아야 한다.

### 2.4 Migration 033에서 확립된 RPC 패턴

Migration 033의 성능 역할 조회 RPC는 다음 패턴을 사용한다.

- 버전이 포함된 함수명
- 도메인 파라미터 검증
- `STABLE`
- `SECURITY INVOKER`
- 고정 `search_path = public, pg_temp`
- 반환 필드 명시
- `PUBLIC`, `anon` 권한 회수 후 필요한 역할에만 실행 권한 부여
- `22023` 계열 입력 오류

Migration 034의 장르 조회 RPC도 특별한 사유가 없는 한 이 패턴을 따라야 한다.

### 2.5 현재 Flutter의 장르 조회 호환성

`app/lib/services/master_data_service.dart`의 레거시 장르 조회는 현재 다음을
동시에 필터링한다.

- `is_active = true`
- `domain = 'band'`

이 조회는 프로필 설정/편집, 그룹 생성/편집, 모집 게시물 생성/편집,
멤버 검색 필터 등 기존 BandMatch 경로에서 공유된다.

관련 테스트는 다음을 확인한다.

- 활성 Band 장르는 포함
- 활성 Dance 장르는 제외
- 비활성 Band 장르는 제외
- 정렬 유지
- parts/areas 조회 영향 없음
- STAGE preview가 프로덕션 Supabase 서비스를 직접 호출하지 않음

그러므로 현재 코드가 실제 사용자에게 전달된다는 보장이 있다면
Dance 장르 활성화 후에도 레거시 Band UI에 Dance 값이 섞이지 않는다.
다만 저장소 코드가 안전하다는 사실만으로 이미 배포된 오래된 Web 번들과
서비스 워커 캐시까지 안전하다고 단정할 수는 없다.

### 2.6 현재 데이터 소비 경계

Flutter의 장르 마스터 조회는 `genres` 직접 SELECT를 사용하지만,
저장된 사용자/그룹/모집 게시물의 표시 데이터는 다음 조인 또는 안전 RPC
projection을 통해 읽힌다.

- `user_genres`
- `group_genres`
- `recruitment_post_genres`
- 각 공개/본인 전용 조회 RPC가 만드는 `genre_names`

Migration 034는 위 연결 테이블에 어떤 행도 생성, 수정, 삭제하지 않는다.

---

## 3. Exact migration scope

### 3.1 반드시 포함할 작업

Migration 034의 허용 범위는 다음뿐이다.

1. 종속 객체와 현재 데이터 상태 preflight
2. 필요한 최소 잠금 획득
3. 레거시 행 및 연결 데이터의 변경 없음 증명을 위한 snapshot/digest 확보
4. `public.get_active_genres_v1(text)` 신규 정의
5. 함수 실행 권한 정리
6. 승인된 11개 Dance 장르의 `is_active`를 `false`에서 `true`로 변경
7. 함수 계약, 활성화 결과, 레거시 무변경, 정책 무변경 postcondition
8. PostgREST schema cache reload 알림
9. 모든 검증이 성공한 경우에만 commit

### 3.2 명시적으로 제외할 작업

Migration 034는 다음을 수행하지 않는다.

- 새로운 장르 행 추가
- 기존 장르 UUID, 코드, 이름, category, domain, sort_order 변경
- 기존 Band 장르 활성 상태 변경
- 장르 행 삭제
- `user_genres`, `group_genres`, `recruitment_post_genres` 변경
- 사용자 `activity_domain` 변경
- 성능 역할 또는 `user_performance_roles` 변경
- `parts`를 Dance 역할로 재사용
- `genres_read_active` RLS 정책 변경
- 기존 테이블 SELECT 권한 제거
- 일반 사용자 쓰기 권한 확대
- STAGE UI 활성화
- Flutter 서비스 또는 화면 변경
- Realtime, 알림, 결제, 채팅, 매칭 로직 변경

### 3.3 마이그레이션 파일의 단일 책임

예정 파일은 반드시 아래 하나다.

`supabase/migrations/034_stage_domain_genre_access_and_activation.sql`

이 파일에 향후 Flutter 호환성 제거, 오래된 API 삭제, 직접 테이블 접근 차단 같은
후속 정리 작업을 섞지 않는다. 그러한 작업은 실제 클라이언트 전환이 완료된 후
별도의 forward migration으로 다룬다.

---

## 4. Approved activation set

Migration 034가 활성화할 수 있는 행은 아래 11개뿐이다.

| 순서 | code | name | domain | category | sort_order | 적용 전 | 적용 후 |
|---:|---|---|---|---|---:|---|---|
| 1 | `dance_kpop` | `K-POP` | `dance` | `commercial` | 101 | inactive | active |
| 2 | `dance_hiphop` | `HIPHOP` | `dance` | `street` | 102 | inactive | active |
| 3 | `dance_jazz` | `JAZZ` | `dance` | `jazz_contemporary` | 103 | inactive | active |
| 4 | `dance_jazz_hiphop` | `JAZZ HIPHOP` | `dance` | `jazz_contemporary` | 104 | inactive | active |
| 5 | `dance_girls_hiphop` | `GIRLS HIPHOP` | `dance` | `commercial` | 105 | inactive | active |
| 6 | `dance_waack` | `WAACK` | `dance` | `street` | 106 | inactive | active |
| 7 | `dance_locking` | `LOCKING` | `dance` | `street` | 107 | inactive | active |
| 8 | `dance_popping` | `POPPING` | `dance` | `street` | 108 | inactive | active |
| 9 | `dance_breaking` | `BREAKING` | `dance` | `street` | 109 | inactive | active |
| 10 | `dance_house` | `HOUSE` | `dance` | `street` | 110 | inactive | active |
| 11 | `dance_other` | `その他（ダンス）` | `dance` | `other` | 111 | inactive | active |

### 4.1 strict precondition

적용 전 다음 조건을 모두 만족해야 한다.

- 위 코드가 정확히 11개 존재한다.
- 각 행의 `name`, `domain`, `category`, `sort_order`가 표와 정확히 일치한다.
- 11개 모두 `is_active = false`다.
- 코드 및 sort order의 중복이 없다.
- 승인 목록 밖의 `domain = 'dance'` 행이 없다.
- 승인 목록 밖의 `dance_*` 코드가 없다.
- 세 장르 연결 테이블에 승인된 Dance 장르를 가리키는 행이 0개다.

다음 상태는 모두 조용히 보정하지 않고 실패시킨다.

- 일부만 이미 활성
- 11개 모두 이미 활성
- 승인 행의 이름/category/sort order가 하나라도 다름
- 승인 밖 Dance 행이 비활성 상태로 존재
- 승인 밖 Dance 행이 활성 상태로 존재
- 승인된 Dance 장르가 어떤 엔터티에 이미 연결되어 있음

이 정책은 재실행 편의보다 마이그레이션 이력과 데이터 드리프트 감지를 우선한다.
이미 적용된 환경에서 파일을 다시 실행해야 할 이유가 생겼다면,
적용 기록을 먼저 확인하고 별도의 진단/복구 절차를 사용해야 한다.

### 4.2 허용되는 변경

UPDATE는 승인 코드 11개를 정확한 allowlist로 지정하고,
사전 metadata와 `is_active = false` 조건을 다시 포함해야 한다.

예상되는 변경은 다음뿐이다.

- 11개 행의 `is_active`: `false` → `true`
- 기존 트리거에 의한 같은 11개 행의 `updated_at` 갱신

다음 값은 변경되면 안 된다.

- `id`
- `code`
- `name`
- `domain`
- `category`
- `sort_order`
- `created_at`

영향 행 수가 정확히 11이 아니면 예외를 발생시키고 전체 트랜잭션을 rollback한다.

---

## 5. Versioned RPC contract

### 5.1 공개 계약

함수의 정확한 외부 계약은 다음과 같다.

`public.get_active_genres_v1(p_domain text)`

반환 컬럼과 순서는 다음으로 고정한다.

| 순서 | 컬럼 | 타입 | 설명 |
|---:|---|---|---|
| 1 | `id` | `uuid` | 안정적인 장르 식별자 |
| 2 | `code` | `text` | 앱/진단용 안정 코드 |
| 3 | `name` | `text` | 일본어 UI에서 사용할 표시명 |
| 4 | `domain` | `text` | `band` 또는 `dance` |
| 5 | `category` | `text` | 도메인 내 분류 |
| 6 | `sort_order` | `smallint` | UI 정렬 순서 |

반환하지 않는 필드는 다음과 같다.

- `is_active`
- `created_at`
- `updated_at`
- 사용자 또는 그룹 관련 어떤 필드도 포함하지 않음

RPC가 활성 행만 반환하므로 `is_active`를 반환할 필요가 없고,
내부 감사용 timestamp도 클라이언트 계약에 포함하지 않는다.

### 5.2 입력 계약

허용 입력은 정확히 다음 두 값이다.

- `band`
- `dance`

처리 규칙:

- 입력을 자동 소문자 변환하거나 공백 제거하여 관대하게 해석하지 않는다.
- `BAND`, `Dance`, 빈 문자열, 공백 문자열은 지원하지 않는다.
- `multi_domain`은 사용자 프로필의 활동 도메인 개념이므로 거부한다.
- `NULL`도 거부한다.
- 잘못된 값은 SQLSTATE `22023`의 명확한 입력 오류로 처리한다.

엄격한 입력은 호출자 버그를 조기에 드러내며,
오타가 빈 목록으로 오해되는 것을 방지한다.

### 5.3 조회 의미

RPC는 다음 조건을 모두 만족하는 행만 반환한다.

- `genres.is_active = true`
- `genres.domain = p_domain`

정렬은 다음으로 고정한다.

1. `sort_order ASC`
2. `code ASC`

동일한 데이터에서 항상 동일한 결과 순서를 제공해야 한다.

### 5.4 함수 속성

권장 속성:

- `LANGUAGE plpgsql`
- `STABLE`
- `SECURITY INVOKER`
- `SET search_path = public, pg_temp`
- 모든 테이블 참조는 `public.genres`처럼 schema-qualified

`SECURITY INVOKER`를 권장하는 이유:

- 현재 활성 장르는 RLS로 이미 `anon`, `authenticated`에 공개되어 있다.
- 읽기 RPC가 기존 테이블 접근 권한을 우회할 필요가 없다.
- Migration 033의 마스터 조회 RPC와 일관된다.
- 함수가 호출자보다 강한 권한을 갖지 않는다.

주의:

현재 권장안은 직접 테이블 SELECT 권한을 유지하는 호환 기간을 전제로 한다.
향후 정말로 `genres` 직접 SELECT를 제거하려면 `SECURITY INVOKER` 함수도
기본 테이블을 읽을 수 없게 된다. 그 시점에는 별도 보안 검토와 forward migration으로
안전한 `SECURITY DEFINER` projection 또는 다른 접근 구조를 설계해야 한다.
Migration 034에서 미리 권한 상승 함수를 만들 필요는 없다.

### 5.5 버전 관리

함수명에 `_v1`을 포함하는 이유:

- Flutter Web 캐시와 향후 iOS 버전이 서로 다른 API 계약을 사용할 수 있다.
- 컬럼 추가/삭제 또는 의미 변경 시 기존 클라이언트를 깨지 않고 `_v2`를 추가할 수 있다.
- 롤백 시 함수 계약을 유지하면서 데이터 활성화만 끌 수 있다.

`v1`의 반환 타입이나 의미를 적용 후 직접 바꾸지 않는다.
계약 변경이 필요하면 새 버전 함수를 추가한다.

---

## 6. Direct table access compatibility recommendation

### 6.1 권장안: 호환성 창 유지

Migration 034에서는 다음을 그대로 유지한다.

- `genres_read_active` 정책
- `anon`의 활성 장르 직접 SELECT
- `authenticated`의 활성 장르 직접 SELECT
- 관리자 관리 정책
- 기존 Flutter `genres` 직접 조회

이 선택은 보안을 약화하는 것이 아니라 현재 보안 경계를 유지하는 것이다.
활성 장르는 이미 공개 마스터 데이터이며, RPC도 동일한 공개 데이터의 좁은 projection이다.

### 6.2 왜 즉시 직접 조회를 막으면 안 되는가

현재 레거시 Flutter는 RPC가 아니라 `genres` 테이블을 직접 조회한다.
Migration 034와 동시에 직접 SELECT를 제거하면 다음이 깨질 수 있다.

- 온보딩
- 프로필 편집
- 멤버 검색 필터
- 그룹 생성/편집
- 모집 게시물 생성/편집
- 오래된 Web 번들
- 미래에 설치되어 업데이트되지 않은 iOS 빌드

따라서 RPC 추가와 레거시 접근 제거는 같은 마이그레이션으로 묶지 않는다.

### 6.3 후속 전환 조건

직접 조회 제한 여부는 다음 조건이 모두 충족된 후 별도로 결정한다.

- 모든 지원 Flutter 경로가 `get_active_genres_v1`을 사용함
- 배포된 Web 번들의 버전 확인 완료
- 서비스 워커 및 브라우저 stale cache 대응 완료
- 향후 iOS 최소 지원 버전 정책 수립
- 호출 로그 또는 릴리스 증거로 구형 직접 조회가 없음을 확인
- `SECURITY INVOKER` RPC가 기본 테이블 권한 제거 후에도 동작하도록
  별도 보안 설계 승인

즉, Migration 034의 “compatibility window”는 시간만으로 끝나는 것이 아니라
위 증거에 의해 종료되어야 한다.

---

## 7. Activation gate and stale-client safety

### 7.1 저장소 코드 통과만으로는 부족한 이유

현재 저장소의 레거시 조회는 `domain = 'band'`를 사용하므로 코드 자체는 안전하다.
하지만 Flutter Web에서는 사용자가 다음을 계속 실행할 수 있다.

- 이전 배포의 `main.dart.js`
- 오래된 서비스 워커 캐시
- CDN/프록시 캐시
- 오래 열린 브라우저 탭

이전 번들이 `is_active = true`만 필터링했다면,
Dance 장르 활성화 직후 기존 Band 화면에 Dance 값이 나타날 수 있다.

### 7.2 적용 전 필수 게이트

다음 둘 중 하나를 명시적으로 선택하고 증거를 남겨야 한다.

#### 경로 A: 개발 전용 환경

다음을 모두 확인한다.

- 외부 사용자 또는 공유 QA 사용자가 없음
- 공개 프로덕션 Web 배포가 없음
- 설치된 iOS 앱이 없음
- 실행 대상이 개발/내부 테스트 프로젝트임
- 호환 필터가 포함된 커밋 SHA를 기록함
- clean build로 레거시 Band 화면이 Band 장르만 표시함을 확인함

이 경우 정식 배포 게이트를 생략할 수 있지만,
“개발 전용”이라는 판단을 적용 기록에 남겨야 한다.

#### 경로 B: 공유 또는 공개 Web 환경

다음을 모두 수행한다.

1. `domain = 'band'` 호환 필터가 포함된 Flutter Web 빌드를 배포한다.
2. 배포 버전 또는 commit SHA를 기록한다.
3. 서비스 워커 갱신 동작을 확인한다.
4. 새 시크릿/익명 창에서 배포된 버전을 연다.
5. 기존 브라우저의 오래된 캐시 상태에서도 업데이트 안내 또는 갱신이 되는지 확인한다.
6. 원격 Supabase에서 Dance 장르는 아직 비활성인 상태로 기존 Band 경로를 회귀 테스트한다.
7. 캐시 제거 또는 강제 갱신 정책이 실제로 반영되었음을 확인한다.
8. 그 후에만 Migration 034를 적용한다.

### 7.3 최소 기록 항목

복잡한 release 시스템을 새로 만들 필요는 없지만 아래는 남겨야 한다.

- 활성화 대상 Supabase 프로젝트/환경 이름
- 적용 일시와 작업자
- 호환 Flutter commit SHA
- Web 배포 URL 또는 “개발 전용, 외부 배포 없음” 확인
- 서비스 워커/캐시 확인 결과
- Migration 034 적용 결과
- postcondition 쿼리 결과

### 7.4 게이트 실패 시 처리

다음 중 하나라도 불명확하면 Migration 034 적용을 보류한다.

- 현재 배포 버전을 알 수 없음
- 오래된 Web 캐시가 남을 가능성을 배제할 수 없음
- 레거시 장르 조회가 Band 도메인으로 제한되었는지 확인하지 못함
- 설치된 구형 iOS 클라이언트가 존재함
- 원격 데이터 preflight가 예상과 다름

이 보류는 SQL 설계 실패가 아니라 클라이언트 호환성 보호를 위한 운영 결정이다.

---

## 8. Legacy no-change proof

Migration 034는 단순히 “해당 테이블을 UPDATE하지 않았다”는 주장보다 강한
사전/사후 증명을 포함해야 한다.

### 8.1 Band 장르 snapshot

잠금 획득 후 활성화 전에 기존 Band 장르 전체를 안정적인 순서로 snapshot한다.

snapshot 대상:

- `id`
- `code`
- `name`
- `domain`
- `category`
- `sort_order`
- `is_active`
- `created_at`
- `updated_at`

활성화 후 같은 projection과 정렬로 다시 계산하여 완전히 동일한지 확인한다.
Band 행 수만 비교하는 것은 이름, 정렬, 활성 상태 변경을 놓칠 수 있으므로 부족하다.

### 8.2 연결 테이블 snapshot

다음 테이블은 전체 식별/관계 필드를 안정적인 순서로 snapshot한다.

- `public.user_genres`
- `public.group_genres`
- `public.recruitment_post_genres`

Migration 034 전후에 각 snapshot이 정확히 같아야 한다.
행 수만이 아니라 연결 대상 UUID 쌍과 가능한 메타데이터까지 포함한
정렬된 JSON 또는 digest 비교를 권장한다.

### 8.3 승인 Dance 장르의 기존 할당 금지

전체 연결 snapshot과 별도로,
승인된 11개 Dance 장르 ID를 참조하는 행이 세 연결 테이블 모두 0개인지 확인한다.

이 조건은 활성화 시점 이전에 숨겨진 Dance 할당이 갑자기 사용자 UI에 노출되는 것을 막는다.
0이 아니면 자동 삭제하지 않고 실패해야 한다.

### 8.4 기존 함수, 뷰, 정책 증명

Migration 034가 의도적으로 추가하는 새 함수와 새 함수 권한을 제외하고,
다음 객체의 정의가 전후 동일해야 한다.

- 기존 `public` 함수
- 기존 `public` 뷰
- `genres` RLS 정책
- 기존 장르 관련 grants
- 기존 트리거와 constraint

구현에서는 최소한 중요 객체의 catalog signature/definition digest를 확보하고,
postcondition에서 비교한다.

### 8.5 허용되는 timestamp 차이

기존 `set_updated_at` 트리거 때문에 승인된 Dance 11개 행의 `updated_at`만
변경되는 것이 정상이다.

- 11개 Dance `created_at`: 동일해야 함
- 11개 Dance `updated_at`: 활성화 시점으로 변경 예상
- 모든 Band `created_at`, `updated_at`: 동일해야 함
- 연결 테이블 timestamp: 동일해야 함

---

## 9. RLS, grants, and function security

### 9.1 권장 grant 모델

권장 권한은 다음과 같다.

| 주체 | RPC EXECUTE | 이유 |
|---|---:|---|
| `PUBLIC` | 거부 | Postgres 기본 함수 실행 권한을 명시적으로 제거 |
| `anon` | 허용 | 현재 활성 장르가 로그인 전에도 공개되는 마스터 데이터 |
| `authenticated` | 허용 | 로그인 후 모든 장르 선택 화면에서 사용 |
| `service_role` | 별도 변경 없음 | Flutter에서 사용하지 않으며 플랫폼 기본 권한에 의존 |

반드시 함수 생성 직후 `PUBLIC` 기본 실행 권한을 회수한 뒤,
승인된 역할에만 다시 부여한다.

### 9.2 `anon` 허용의 보안 영향

`anon` 실행 권한은 다음 이유로 새로운 민감 정보 공개가 아니다.

- 현재 `anon`은 `genres_read_active`로 활성 장르를 이미 직접 읽을 수 있다.
- RPC는 더 적은 필드만 반환한다.
- RPC는 활성 행만 반환한다.
- 사용자, 그룹, 결제, 인증 필드를 참조하지 않는다.
- 쓰기 경로가 없다.

단, 제품이 “장르 마스터도 로그인 후에만 공개”로 정책을 바꾸려면
이 결정은 다시 검토해야 한다. 현재 제품/스키마 기준으로는 `anon` 허용이
호환성과 온보딩 측면에서 더 일관적이다.

### 9.3 기존 RLS 무변경

Migration 034는 다음을 하지 않는다.

- `genres` RLS disable
- `genres_read_active` 삭제/완화
- 관리자 쓰기 정책 변경
- 사용자 생성 데이터 정책 변경
- private table grant 추가

일반 인증 사용자가 `genres`에 쓰려고 하면 기존과 동일하게 관리자 RLS에서 거부되어야 한다.

### 9.4 입력 오류와 정보 노출

오류 메시지는 지원 도메인 계약을 설명할 수 있지만,
내부 테이블 구조나 SQL을 노출하지 않는다.

권장 오류 의미:

- null/unsupported domain: “unsupported genre domain”
- SQLSTATE: `22023`

데이터가 0개인 정상 도메인은 빈 결과를 반환할 수 있지만,
Migration 034 postcondition상 `dance`는 11개, `band`는 기존 활성 개수가
유지되어야 하므로 적용 직후 빈 결과는 실패다.

---

## 10. Ordered future SQL outline

아래는 향후 Migration 034 구현 시 따라야 할 순서다.
이 문서는 실제 실행 가능한 마이그레이션 SQL을 제공하지 않는다.

### 단계 1: 트랜잭션과 운영 제한 설정

목적:

- 모든 DDL/DML/검증을 원자적으로 처리
- 장시간 잠금 대기를 피함

요구사항:

- 명시적 transaction
- 합리적인 local lock timeout
- 합리적인 local statement timeout

실패 시:

- 아무 객체나 데이터도 남기지 않고 rollback
- 원인을 확인한 뒤 저트래픽 시간에 재시도

### 단계 2: catalog 및 dependency preflight

확인 대상:

- `public.genres`와 필수 컬럼 존재
- domain/category 제약이 Migration 032 계약과 일치
- `set_updated_at` 트리거 존재
- 세 연결 테이블 존재
- `genres_read_active`와 관리자 정책 존재
- `public.get_active_genres_v1(text)`가 아직 존재하지 않음
- Migration 033의 기반 객체가 존재

실패 시:

- 현재 환경의 마이그레이션 순서가 다르므로 즉시 rollback
- `CREATE OR REPLACE`로 알 수 없는 기존 함수를 덮어쓰지 않음

### 단계 3: 잠금 획득

권장 잠금:

- `public.genres`: `SHARE ROW EXCLUSIVE`
- `public.user_genres`: `SHARE`
- `public.group_genres`: `SHARE`
- `public.recruitment_post_genres`: `SHARE`

목적:

- 장르 metadata/활성 상태에 대한 동시 쓰기 방지
- snapshot 중 장르 연결 INSERT/UPDATE/DELETE 방지
- 일반 SELECT는 계속 허용

잠금은 고정된 순서로 한 번에 획득해 deadlock 가능성을 낮춘다.

실패 시:

- timeout 후 rollback
- 잠금 강도를 임의로 `ACCESS EXCLUSIVE`로 높이지 않음
- 활성 사용자 저장 작업이 적은 시간에 재시도

### 단계 4: pre-migration snapshot 생성

트랜잭션 내부 임시 데이터 또는 변수로 다음을 보존한다.

- Band 장르 전체 projection
- 승인 Dance 장르 전체 metadata 및 timestamp
- 세 연결 테이블 전체 projection/digest
- 중요 기존 함수/뷰/정책/트리거 정의
- 기존 grant 상태

목적:

- postcondition에서 실제 무변경을 증명

실패 시:

- snapshot을 만들 수 없는 구조 드리프트로 간주하고 rollback

### 단계 5: activation precondition 검증

정확히 검증한다.

- 승인 11개가 정확한 metadata로 존재
- 11개 모두 inactive
- 예상 밖 Dance 행 0개
- 승인 Dance 장르 할당 0개
- 기존 Band snapshot이 비어 있거나 비정상적이지 않음

실패 시:

- 자동 수정 없이 rollback
- 별도의 진단 결과를 사람이 검토

### 단계 6: 버전 고정 RPC 생성

5절의 정확한 계약으로 함수를 신규 생성한다.

목적:

- STAGE와 향후 클라이언트가 도메인별 활성 장르를 안정적으로 조회

구현 제한:

- safe fields만 반환
- 엄격한 domain validation
- active filter
- deterministic ordering
- identity 또는 사용자 데이터 의존 없음

실패 시:

- 전체 rollback

### 단계 7: RPC 권한 최소화

순서:

1. `PUBLIC` 기본 EXECUTE 회수
2. `anon` EXECUTE 부여
3. `authenticated` EXECUTE 부여

다른 테이블 또는 함수 권한은 변경하지 않는다.

실패 시:

- 전체 rollback

### 단계 8: 정확한 11개 Dance 장르 활성화

UPDATE는 코드 allowlist와 정확한 metadata 및 inactive 조건을 함께 사용한다.

검증:

- 영향 행 수 정확히 11
- 변경 필드는 `is_active`와 트리거가 관리하는 `updated_at`뿐

실패 시:

- 전체 rollback

### 단계 9: postcondition 검증

다음을 모두 검증한다.

- RPC signature/속성/반환 타입 정확
- grants 정확
- `band` 호출 결과가 기존 활성 Band 데이터와 정확히 일치
- `dance` 호출 결과가 정확히 11개
- null/unsupported 입력이 계약대로 거부됨
- 11개 Dance metadata/UUID/created_at 유지
- 11개 Dance만 active
- 예상 밖 Dance 행 0개
- Band snapshot 완전 동일
- 세 연결 테이블 snapshot 완전 동일
- 승인 Dance 할당 0개
- 기존 함수/뷰/정책/트리거 정의 동일
- `genres` RLS가 계속 enabled

하나라도 실패하면 예외를 발생시켜 전체 rollback한다.

### 단계 10: PostgREST schema reload 알림

함수 생성 후 `notify pgrst, 'reload schema'`를 transaction 안에서 보낸다.
알림은 commit 시 전달되어 새 RPC를 PostgREST가 인식하게 한다.

이 알림 성공만으로 REST endpoint 인식이 완전히 증명되지는 않으므로,
적용 후 실제 anon/authenticated RPC 호출도 테스트한다.

### 단계 11: commit

모든 postcondition이 성공할 때만 commit한다.
부분 활성화 또는 함수만 생성된 상태는 허용하지 않는다.

---

## 11. Locking and operational impact

### 11.1 예상 잠금 영향

`genres`의 `SHARE ROW EXCLUSIVE` 잠금은 다음을 허용한다.

- 일반 장르 SELECT
- RPC를 통한 읽기

동시에 다음을 잠시 대기시킬 수 있다.

- 장르 관리자 INSERT/UPDATE/DELETE
- 충돌하는 DDL

세 연결 테이블의 `SHARE` 잠금은 일반 읽기를 허용하지만,
잠금이 유지되는 짧은 동안 프로필/그룹/모집 게시물의 장르 연결 저장을 대기시킬 수 있다.

### 11.2 왜 연결 테이블도 잠그는가

Migration 034가 연결 테이블을 수정하지 않더라도,
pre/post snapshot 사이에 사용자가 장르 선택을 저장하면 무변경 검증이
거짓 실패하거나 동시 변경을 놓칠 수 있다.

짧은 `SHARE` 잠금은 다음 두 목적을 만족한다.

- 정확한 무변경 증명
- 일반 읽기 지속

### 11.3 예상 실행 시간

장르 11개 활성화와 작은 catalog 검증이므로 정상 환경에서는 짧게 끝나야 한다.
실행이 수 초 이상 잠금 대기 상태라면 강제로 계속 기다리기보다 timeout으로
rollback하고 원인을 조사하는 편이 안전하다.

### 11.4 권장 운영 시간

서비스 중단은 필요하지 않지만 다음 시점을 권장한다.

- 프로필/그룹/모집 게시물 편집이 적은 시간
- Web 호환 배포 및 캐시 확인 직후
- 작업자가 즉시 post-application 검증을 수행할 수 있는 시간
- 문제가 있으면 STAGE 노출을 즉시 끌 수 있는 시간

### 11.5 동시 쓰기 처리

잠금 대기 중인 정상 사용자 저장은 마이그레이션 commit 후 이어질 수 있다.
lock timeout이 발생하면 마이그레이션 전체가 실패하므로 부분 데이터는 남지 않는다.

Migration 034 구현에서 다음은 금지한다.

- `NOWAIT` 실패를 잡아 무시하고 계속 실행
- snapshot 검증을 생략
- 동시 쓰기 문제를 해결하려고 RLS를 일시적으로 끄기
- 넓은 테이블에 불필요한 `ACCESS EXCLUSIVE` 잠금 사용

---

## 12. Rollback and feature-disable strategy

### 12.1 우선순위

문제 발생 시 우선 조치는 데이터 삭제가 아니라 기능 노출 중단이다.

1. STAGE 장르 선택 UI/진입점을 feature disable
2. 레거시 Band Flutter의 `domain = 'band'` 필터 유지
3. 문제 범위와 이미 생성된 Dance 연결 데이터 확인
4. 필요하면 별도의 forward rollback migration 작성

### 12.2 권장 forward rollback

되돌림 마이그레이션은 다음 원칙을 따른다.

- 정확한 11개 승인 코드만 대상으로 함
- metadata가 승인 계약과 일치하는지 먼저 검증
- `is_active = true`를 `false`로 변경
- UUID와 행 자체는 유지
- `get_active_genres_v1`은 유지
- 연결 데이터는 삭제하지 않음
- Band 데이터는 변경하지 않음

RPC를 유지하면 기존 배포 클라이언트 계약은 살아 있고,
`dance` 호출만 정상적으로 빈 목록을 반환하게 할 수 있다.

### 12.3 이미 Dance 선택 데이터가 존재할 때

Migration 034 이후 STAGE 테스트로 `user_genres` 등 연결이 생겼다면,
장르를 비활성화해도 연결 행을 물리 삭제하지 않는다.

이유:

- 사용자 선택 이력 보존
- 같은 UUID로 재활성 가능
- 데이터 손실 방지
- 잘못된 재생성/중복 방지

관련 UI는 비활성 장르를 선택 옵션에서 제외하고,
필요하면 별도 데이터 정리 정책을 설계한다.

### 12.4 금지되는 롤백

- 이미 적용된 Migration 034 파일 수정
- 11개 Dance 행 DELETE
- 같은 코드를 새 UUID로 다시 INSERT
- `user_genres`, `group_genres`, `recruitment_post_genres` 일괄 삭제
- 레거시 Flutter의 Band 필터 제거
- RPC를 즉시 DROP하여 배포 클라이언트를 깨기
- 원격 DB를 수동으로 일부만 되돌리고 migration 기록을 남기지 않기

### 12.5 트랜잭션 내부 실패

Migration 034 실행 중 preflight/postcondition이 실패하면
원래 트랜잭션 rollback만으로 충분하다.
이 경우 함수, grant, 활성화 UPDATE가 모두 남지 않아야 한다.

---

## 13. Flutter release sequence after Migration 034

### 13.1 적용 전

1. 현재 레거시 Band 장르 필터 테스트 유지
2. `dart analyze`
3. `flutter test`
4. `flutter build web`
5. 대상 환경이 공유/공개라면 호환 Web 빌드 먼저 배포
6. 서비스 워커 및 stale cache 확인
7. 활성화 게이트 기록

### 13.2 Migration 034 적용 직후

다음 순서로 검증한다.

1. SQL postcondition 결과 확인
2. anon으로 `get_active_genres_v1('band')` 호출
3. anon으로 `get_active_genres_v1('dance')` 호출
4. authenticated로 두 도메인 호출
5. 레거시 Flutter의 기존 Band 화면 회귀 테스트
6. Band 화면에 Dance 장르가 나타나지 않는지 확인
7. 아직 STAGE 저장 UI는 열지 않음

### 13.3 첫 Flutter 구현 권장 범위

Migration 034 다음 첫 Flutter 작업은 **서비스/모델 기반만** 구현하는 것을 권장한다.

범위:

- `get_active_genres_v1`을 호출하는 domain-aware 장르 서비스
- `get_active_performance_roles_v1`을 호출하는 성능 역할 서비스와 정합성 확인
- `band`/`dance` 도메인 타입 또는 안전한 enum 매핑
- 장르 응답 모델
- unsupported domain 및 PostgREST 오류 처리
- Band와 Dance 결과 파싱/정렬 테스트
- 기존 레거시 direct-query 서비스는 호환 기간 동안 유지

이 첫 작업에서는 다음을 하지 않는다.

- 전체 프로필 UI 전환
- Dance 프로필 저장
- `multi_domain` 병합 UI
- 전체 기존 화면을 한 번에 RPC로 교체
- 직접 테이블 접근 권한 제거

작은 서비스 기반을 먼저 검증하면 데이터베이스 문제와 화면 상태 문제를 분리할 수 있다.

### 13.4 그다음 권장 순서

1. STAGE Dance 프로필의 장르/성능 역할 읽기 전용 화면
2. 개발자/내부 QA 검증
3. 자기 프로필 저장 RPC와 UI의 작은 수직 슬라이스
4. Band 경로를 versioned RPC로 점진 전환
5. 모든 지원 클라이언트 전환 증거 확보
6. 직접 테이블 접근 제한 여부 별도 설계

---

## 14. Positive and negative verification matrix

### 14.1 긍정 시나리오

| ID | 시나리오 | 기대 결과 |
|---|---|---|
| P1 | `band` RPC 호출 | 기존 활성 Band 장르만 정렬되어 반환 |
| P2 | `dance` RPC 호출 | 승인된 11개가 정확한 순서로 반환 |
| P3 | anon 호출 | 권장 grant 승인 시 정상 반환 |
| P4 | authenticated 호출 | 정상 반환 |
| P5 | 레거시 Flutter 프로필 편집 | Dance 장르 없이 기존 Band 장르만 표시 |
| P6 | 레거시 멤버 검색 필터 | Band 장르만 표시 |
| P7 | 그룹/모집 게시물 편집 | 기존 Band 장르만 표시 |
| P8 | Band 직접 SELECT | 기존과 동일하게 활성 Band 행 읽기 가능 |
| P9 | 일반 사용자의 장르 쓰기 | 기존 RLS에 의해 계속 거부 |
| P10 | 함수 반환 projection | 정의한 6개 필드만 반환 |

### 14.2 부정 시나리오

| ID | 시나리오 | 기대 결과 |
|---|---|---|
| N1 | `NULL` domain | SQLSTATE `22023` 오류 |
| N2 | 빈 문자열 | 입력 오류 |
| N3 | `multi_domain` | 입력 오류 |
| N4 | 대문자 `DANCE` | 입력 오류 |
| N5 | 임의 문자열 | 입력 오류 |
| N6 | 승인 Dance 행 하나가 이미 active | 마이그레이션 전체 실패 |
| N7 | 승인 밖 `dance_*` 행 존재 | 마이그레이션 전체 실패 |
| N8 | 승인 밖 `domain = 'dance'` 행 존재 | 마이그레이션 전체 실패 |
| N9 | 승인 Dance metadata drift | 마이그레이션 전체 실패 |
| N10 | 승인 Dance 연결 데이터 존재 | 마이그레이션 전체 실패 |
| N11 | UPDATE 영향 행 수가 11이 아님 | 전체 rollback |
| N12 | postcondition에서 Band digest 변경 | 전체 rollback |
| N13 | 연결 테이블 digest 변경 | 전체 rollback |
| N14 | 함수 기본 PUBLIC EXECUTE가 남음 | postcondition 실패 |
| N15 | PostgREST가 함수를 인식하지 않음 | DB commit은 진단하되 STAGE 클라이언트 배포 보류 |

### 14.3 회귀 검증

Migration 034 이후에도 다음은 그대로 동작해야 한다.

- Supabase Auth
- 프로필 설정/편집
- 프로필 이미지
- 멤버 검색
- 메시지 요청
- 채팅
- 그룹 프로필
- 모집 게시물과 지원 흐름
- 차단/신고
- badge/unread 로직

Migration 034는 위 기능의 테이블이나 RPC를 변경하지 않지만,
장르 master 소비 화면은 반드시 실제 UI에서 회귀 테스트한다.

---

## 15. Manual preflight and post-application verification queries

아래 쿼리는 사양 검토 및 실제 적용 전후의 **읽기 전용 검증 예시**다.
이 문서 작성 과정에서는 실행하지 않았다.

### 15.1 승인 Dance 행 확인

```sql
select
  id,
  code,
  name,
  domain,
  category,
  sort_order,
  is_active,
  created_at,
  updated_at
from public.genres
where code in (
  'dance_kpop',
  'dance_hiphop',
  'dance_jazz',
  'dance_jazz_hiphop',
  'dance_girls_hiphop',
  'dance_waack',
  'dance_locking',
  'dance_popping',
  'dance_breaking',
  'dance_house',
  'dance_other'
)
order by sort_order, code;
```

적용 전 기대:

- 11행
- 표의 metadata와 정확히 일치
- 모두 `is_active = false`

적용 후 기대:

- 같은 UUID와 metadata의 11행
- 모두 `is_active = true`
- `created_at` 동일
- `updated_at`만 적용 시점으로 변경

### 15.2 예상 밖 Dance 행 확인

```sql
select
  id,
  code,
  name,
  domain,
  category,
  sort_order,
  is_active
from public.genres
where (
    domain = 'dance'
    or code like 'dance\_%' escape '\'
  )
  and code not in (
    'dance_kpop',
    'dance_hiphop',
    'dance_jazz',
    'dance_jazz_hiphop',
    'dance_girls_hiphop',
    'dance_waack',
    'dance_locking',
    'dance_popping',
    'dance_breaking',
    'dance_house',
    'dance_other'
  )
order by code;
```

기대: 0행

### 15.3 활성 개수 확인

```sql
select domain, is_active, count(*) as row_count
from public.genres
group by domain, is_active
order by domain, is_active;
```

적용 후 Dance 기대: `domain = 'dance' and is_active = true`가 정확히 11행

### 15.4 Dance 연결 데이터 확인

```sql
select 'user_genres' as source, count(*) as row_count
from public.user_genres ug
join public.genres g on g.id = ug.genre_id
where g.domain = 'dance'
union all
select 'group_genres', count(*)
from public.group_genres gg
join public.genres g on g.id = gg.genre_id
where g.domain = 'dance'
union all
select 'recruitment_post_genres', count(*)
from public.recruitment_post_genres rpg
join public.genres g on g.id = rpg.genre_id
where g.domain = 'dance';
```

Migration 034 적용 직전 기대: 세 결과 모두 0  
Migration 034 적용 직후, Flutter 쓰기 기능을 열기 전 기대: 세 결과 모두 0

### 15.5 Band snapshot/digest 기록

적용 전 결과를 별도로 저장하고 적용 후 같은 쿼리 결과와 비교한다.

```sql
select md5(
  coalesce(
    jsonb_agg(to_jsonb(snapshot_row) order by snapshot_row.sort_order, snapshot_row.code)::text,
    '[]'
  )
) as band_genres_digest
from (
  select
    id,
    code,
    name,
    domain,
    category,
    sort_order,
    is_active,
    created_at,
    updated_at
  from public.genres
  where domain = 'band'
) as snapshot_row;
```

기대: 적용 전후 digest가 동일

### 15.6 연결 테이블 digest 기록

각 결과를 적용 전 저장하고 적용 후 비교한다.

```sql
select md5(
  coalesce(jsonb_agg(to_jsonb(x) order by x.user_id, x.genre_id)::text, '[]')
) as user_genres_digest
from (
  select user_id, genre_id
  from public.user_genres
) x;

select md5(
  coalesce(jsonb_agg(to_jsonb(x) order by x.group_id, x.genre_id)::text, '[]')
) as group_genres_digest
from (
  select group_id, genre_id
  from public.group_genres
) x;

select md5(
  coalesce(
    jsonb_agg(to_jsonb(x) order by x.post_id, x.genre_id)::text,
    '[]'
  )
) as recruitment_post_genres_digest
from (
  select post_id, genre_id
  from public.recruitment_post_genres
) x;
```

기대: 각 digest가 적용 전후 동일

> 실제 컬럼명이 원격 스키마와 다른 경우 쿼리를 임의로 실행하지 말고,
> Migration 001~033과 원격 catalog 차이를 먼저 조사한다.

### 15.7 함수 signature와 보안 속성 확인

```sql
select
  p.oid::regprocedure as signature,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer,
  p.provolatile as volatility,
  p.proconfig as function_settings
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'get_active_genres_v1';
```

기대:

- signature: `get_active_genres_v1(text)`
- `security_definer = false`
- volatility: stable을 뜻하는 `s`
- `search_path`에 `public, pg_temp`

### 15.8 함수 grants 확인

```sql
select
  grantee,
  privilege_type
from information_schema.routine_privileges
where specific_schema = 'public'
  and routine_name = 'get_active_genres_v1'
order by grantee, privilege_type;
```

권장안 적용 시 기대:

- `anon`: EXECUTE
- `authenticated`: EXECUTE
- `PUBLIC`: 없음

### 15.9 RLS 정책 무변경 확인

```sql
select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
  and tablename = 'genres'
order by policyname;
```

기대:

- `genres_read_active` 유지
- 관리자 관리 정책 유지
- Migration 034가 새 쓰기 정책을 추가하지 않음

### 15.10 RPC 긍정 호출

```sql
select * from public.get_active_genres_v1('band');
```

```sql
select * from public.get_active_genres_v1('dance');
```

기대:

- Band: 기존 활성 Band 결과
- Dance: 승인 11개
- 정렬: `sort_order`, `code`

### 15.11 RPC 결과와 직접 조회의 동등성

```sql
(
  select id, code, name, domain, category, sort_order
  from public.get_active_genres_v1('band')
)
except
(
  select id, code, name, domain, category, sort_order
  from public.genres
  where is_active and domain = 'band'
);
```

그리고 반대 방향도 확인한다.

```sql
(
  select id, code, name, domain, category, sort_order
  from public.genres
  where is_active and domain = 'band'
)
except
(
  select id, code, name, domain, category, sort_order
  from public.get_active_genres_v1('band')
);
```

기대: 양쪽 모두 0행

Dance에 대해서도 동일한 양방향 `EXCEPT` 검증을 수행한다.

### 15.12 RPC 부정 호출

아래는 각각 별도로 실행하고 모두 입력 오류가 발생하는지 확인한다.

```sql
select * from public.get_active_genres_v1(null);
```

```sql
select * from public.get_active_genres_v1('');
```

```sql
select * from public.get_active_genres_v1('multi_domain');
```

```sql
select * from public.get_active_genres_v1('DANCE');
```

기대: 지원하지 않는 입력으로 성공하지 않음

### 15.13 일반 사용자 쓰기 거부

Supabase SQL Editor의 관리자 세션은 RLS를 우회할 수 있으므로,
SQL Editor에서 성공/실패만 보고 일반 사용자 보안을 판단하면 안 된다.

검증 방법:

- 실제 anon client로 쓰기 시도: 거부
- 실제 non-admin authenticated client로 쓰기 시도: 거부
- 관리자 계정의 기존 관리 기능: 기존 정책 범위에서만 허용

테스트 후 어떤 장르 데이터도 변경되지 않았는지 다시 확인한다.

### 15.14 PostgREST schema cache 확인

SQL 직접 호출 성공만으로 REST cache 인식을 증명할 수 없다.
적용 후 실제 Supabase client에서 아래 두 호출을 수행한다.

- anon session: RPC `get_active_genres_v1`, `p_domain = band`
- authenticated session: RPC `get_active_genres_v1`, `p_domain = dance`

함수를 찾을 수 없다는 PostgREST 오류가 나오면,
데이터를 다시 변경하지 말고 schema reload 상태를 진단한다.

---

## 16. User decisions required

아래 결정은 Migration 034 구현 또는 적용 전에 확인해야 한다.

| # | 질문 | 권장안 | 대안 | DB 영향 | Flutter 영향 | 차단 여부 |
|---:|---|---|---|---|---|---|
| 1 | RPC를 로그인 전에도 허용할 것인가? | `anon` + `authenticated` EXECUTE | authenticated만 허용 | 활성 공개 장르의 접근 범위 유지 또는 축소 | 온보딩/로그인 전 선택 가능 여부 | **구현 차단** |
| 2 | 지원 장르 도메인은 무엇인가? | `band`, `dance`만 허용 | 향후 값을 미리 허용 | 입력 계약과 postcondition 변경 | enum/오류 처리 변경 | **구현 차단** |
| 3 | 일부/전체가 이미 active면 어떻게 할 것인가? | 모든 비정상 사전 상태에서 실패 | idempotent no-op 또는 나머지만 활성화 | 드리프트 탐지 강도 변화 | 없음 | **구현 차단** |
| 4 | 예상 밖 Dance 행이 있으면 어떻게 할 것인가? | active 여부와 무관하게 실패 | 승인 11개만 활성화하고 무시 | 숨은 데이터 허용 여부 | 미래 목록 결과 위험 | **구현 차단** |
| 5 | Dance 연결 데이터가 이미 있으면 어떻게 할 것인가? | 0이 아니면 실패 | 기존 연결을 보존한 채 활성화 | 숨은 할당 노출 가능 | 기존 사용자 UI에 갑작스러운 표시 가능 | **적용 차단** |
| 6 | 현재 환경은 개발 전용인가, 공유/공개 Web인가? | 공유/공개면 호환 빌드·캐시 검증 후 적용 | 개발 전용 확인 후 간소화 | DB 내용은 같음 | stale client 안전성에 직접 영향 | **적용 차단** |
| 7 | 직접 `genres` SELECT를 Migration 034에서 제거할 것인가? | 제거하지 않고 호환성 창 유지 | 즉시 제거 | 기존 RLS/grant 및 RPC 보안 구조 변경 필요 | 현재 레거시 화면 파손 위험 | **구현 차단** |
| 8 | 첫 Flutter 후속 작업 범위는? | RPC 서비스/모델/테스트만 | 즉시 전체 STAGE UI | DB 영향 없음 | 릴리스 위험과 작업 크기 변화 | 구현 후 결정 가능 |

### 16.1 권장 승인 문구

Migration 034 구현을 승인할 때는 최소한 다음 취지를 명시하는 것이 좋다.

> `band`와 `dance`만 지원하고, RPC는 anon/authenticated에 허용한다.  
> 승인된 11개가 모두 정확한 inactive 상태이며 예상 밖 Dance 행과 연결 데이터가
> 하나도 없을 때만 활성화한다. 기존 직접 SELECT는 호환 기간 동안 유지한다.  
> 실제 적용은 Web 배포/캐시 게이트 또는 개발 전용 환경 확인 후 수행한다.

---

## 17. Readiness assessment

### 17.1 설계 준비 상태

이 사양 기준으로 Migration 034의 기술 범위와 검증 기준은 충분히 정의되었다.

- exact activation set 확정
- RPC contract 확정안 제시
- 권한 모델 권장안 제시
- 엄격한 precondition/postcondition 정의
- legacy no-change 증명 정의
- 잠금 전략 정의
- rollback 전략 정의
- Flutter 릴리스 순서 정의

### 17.2 구현 준비 상태

다음 사용자 결정을 승인하면 로컬 SQL 파일 구현을 시작할 수 있다.

- RPC `anon` 권한
- 도메인 allowlist
- strict activation 정책
- unexpected Dance 행 처리
- 직접 조회 호환성 창

### 17.3 원격 적용 준비 상태

현재 문서 작성 시점에는 **아직 적용 준비 완료로 판정하지 않는다**.

이유:

- 원격 Supabase preflight를 이번 작업에서 실행하지 않음
- 배포된 Web 버전과 서비스 워커 캐시 상태를 저장소만으로 확정할 수 없음
- 개발 전용 환경인지 공유/공개 환경인지 최종 확인이 필요
- 승인된 11개와 연결 테이블의 원격 실제 상태 확인이 필요

따라서 상태는 다음과 같다.

- 사양 작성: 완료
- 로컬 Migration 034 구현: 사용자 결정 후 가능
- 원격 SQL 실행: activation gate와 원격 preflight 완료 전 금지
- STAGE Flutter 장르 UI 활성화: Migration 034 post-verification 전 금지

---

## 18. Exact recommended next Codex task

아래 요청을 다음 Codex 작업으로 그대로 사용하는 것을 권장한다.

```text
Implement the approved STAGE Migration 034 in the `stage-redesign` branch.

Create exactly:
- supabase/migrations/034_stage_domain_genre_access_and_activation.sql

Use:
- docs/stage-analysis/10_MIGRATION_034_SPEC.md
- supabase/migrations/032_stage_taxonomy_and_user_profile.sql
- supabase/migrations/033_stage_performance_roles.sql

Approved decisions:
- get_active_genres_v1 supports exactly `band` and `dance`
- grant EXECUTE to anon and authenticated; revoke from PUBLIC
- use STABLE, SECURITY INVOKER, and search_path public, pg_temp
- preserve existing genres direct SELECT/RLS compatibility
- require all 11 approved Dance genres to exist with exact metadata and all inactive
- fail on partial/already-active state
- fail on any unexpected dance-domain or dance_* row
- fail if any approved Dance genre already has user/group/recruitment assignments
- activate exactly the approved 11 rows
- preserve all Band rows and all genre assignment rows exactly
- include strict preflight, postconditions, minimal locks, and
  notify pgrst, 'reload schema'

Do not:
- execute SQL against Supabase
- modify migrations 001-033
- modify Flutter
- add unrelated RPCs, grants, policies, or dependencies
- commit or push

After implementation:
- inspect the SQL statically
- verify only the one new migration file changed
- explain the activation gate that must be completed before running it remotely
```

Migration 034 구현이 끝난 뒤에도 바로 원격 실행하지 말고,
먼저 이 문서의 7절 activation gate와 15절 preflight 검증을 완료해야 한다.

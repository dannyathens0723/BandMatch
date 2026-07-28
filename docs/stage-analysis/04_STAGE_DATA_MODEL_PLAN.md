# STAGE 데이터 모델 계획

이 문서는 SQL 구현안이 아니다. 현재 `001`–`031`을 수정하지 않고, STAGE에 필요한 후속 object와 RLS 경계를 정의한다.

## 1. 현재 스키마 총괄

### 1.1 현재 table register

| 현재 table | 현재 역할 | STAGE 분류 | 방향 |
|---|---|---|---|
| `users` | Auth와 연결된 profile/account | 유지·확장 | dance profile, professional public state 추가; private 필드는 기존 보호 유지 |
| `groups` | band/group profile | UI명만 변경 + 확장 | 기술명 유지, UI/model은 Crew; lifecycle/domain 필드 확장 |
| `areas` | prefecture/city/ward master | 유지·확장 | broad activity area; station과 분리 |
| `parts` | instrument/part master | legacy 유지 | 미래 band용. dance 역할을 덮어쓰지 않음 |
| `genres` | genre master | 유지·확장 | domain/category 추가, dance seed |
| `user_purposes` | 사용자 목적 | 유지·확장 | STAGE 목적 code 검토 |
| `user_parts` | 보유 part | 신규 object로 migration | dance에는 `user_performance_roles` 사용; 기존 band data 보존 |
| `user_genres` | 사용자 genre | 유지·확장 | 새 genre taxonomy와 연결 |
| `user_target_parts` | 찾는 part | 신규 object로 migration | 신규 role preference로 이동 후 deprecate |
| `user_recruiting_parts` | 모집 part | 신규 object로 migration | STAGE role 구조로 이동 후 deprecate |
| `user_areas` | profile area | 유지·확장 | broad public area만; exact station 금지 |
| `group_genres` | group genre | UI명만 변경 + 확장 | crew genre로 계속 사용 |
| `group_target_parts` | group target part | 신규 object로 migration | role 구조로 이동 후 deprecate |
| `group_recruiting_parts` | group recruiting part | 신규 object로 migration | recruitment role 구조로 이동 후 deprecate |
| `group_members` | role/membership history | 유지·확장 | crew member의 active/left/removed, leader 권한 기준 |
| `group_areas` | group activity area | UI명만 변경 + 유지 | crew broad area |
| `media_portfolios` | user/group external media | 유지·확장 | public performance portfolio; crew operational resource와 분리 |
| `blocks` | user block | 유지 | STAGE 모든 상호작용의 양방향 제한 기준 |
| `message_requests` | gated conversation request | 유지 여부 제품 결정 | recruitment inquiry로 제한하는 방안 |
| `message_rooms` | accepted request room | 유지 | low-frequency 1:1 inquiry |
| `room_participants` | room access/unread | 유지·확장 | `last_read_at`, active participant 계약 보존 |
| `messages` | room message | 유지 | text 중심; full video 금지 |
| `message_reads` | per-message read record | 불명확/향후 cleanup | 현재 room-level unread가 주 사용 경로 |
| `reviews` | blind reciprocal review | 불명확 | STAGE MVP 화면 없음; 보존, 활성화 여부 결정 |
| `reports` | user/message report | 유지·확장 | event/lesson/studio/content 신고는 별도 target 설계 필요 |
| `notifications` | user notification | 유지·확장 | STAGE action 종류 추가; archive log와 분리 |
| `legal_documents` | terms/privacy | 유지 | minor/offline 정책 버전 추가 가능 |
| `user_consents` | versioned consent | 유지·확장 | 보호자/추가 동의 결정에 대응 |
| `invitations` | friend/group invitation | 불명확 | share deep link와 혼동 금지; 지원은 반드시 개인 |
| `admin_users` | operator auth/role | 유지·확장 | professional/content verification 운영 |
| `admin_actions` | operator audit | 유지·확장 | verification/content moderation action 추가 |
| `ads` | 광고 | MVP 외 유지 | STAGE core와 분리 |
| `waitlist` | 사전 등록 | MVP 외 유지 | 필요 시 STAGE branding만 |
| `subscriptions` | 결제 구독 | MVP 외 유지 | client 노출 금지 |
| `payment_history` | 결제 이력 | MVP 외 유지 | client 노출 금지 |
| `recruitment_posts` | group 모집 글 | 유지·확장 | target event, 조건, publish/close metadata |
| `recruitment_post_parts` | 모집 part | 신규 object로 migration | recruitment role로 backfill 후 deprecate |
| `recruitment_post_genres` | 모집 genre | 유지·확장 | 새 taxonomy |
| `recruitment_post_areas` | 모집 area | 유지 | broad location |
| `recruitment_applications` | 개인 지원/결정 | 유지·확장 | 현재 atomic approval/member reactivation 보존 |

“deprecate”는 데이터 삭제를 뜻하지 않는다. Flutter와 RPC가 새 object로 완전히 전환되고 backfill 검증이 끝난 뒤 별도 cleanup migration에서만 고려한다.

### 1.2 현재 주요 상태/check

| object | 현재 상태 |
|---|---|
| `users.account_status` | `active`, `suspended`, `withdrawn` |
| `groups.account_status` | `active`, `suspended`, `withdrawn` |
| `group_members.role` | `admin`, `member` |
| `group_members.membership_status` | `active`, `left`, `removed` |
| `message_requests.status` | `pending`, `accepted`, `rejected` |
| `recruitment_posts.status` | `draft`, `open`, `closed` |
| `recruitment_applications.status` | `pending`, `accepted`, `rejected` |
| `reports.status` | `open`, `reviewing`, `closed` |
| `messages.message_type` | `text`, `stamp`; 현재 Flutter/RPC는 text |

현재 table은 UUID PK, FK, `created_at`/`updated_at` pattern을 주로 사용한다. STAGE 신규 object도 이 convention을 유지한다.

### 1.3 현재 컬럼·FK register

PostgreSQL enum type은 사용하지 않으며 상태 값은 모두 `text + CHECK`다. 아래 표는 공통 UUID `id`와 timestamp를 포함한 현재 최종 컬럼을 migration `001`–`031` 기준으로 압축 표기한다. `→`는 FK 대상이며, join table의 괄호는 unique key다.

| table | 현재 컬럼과 주요 FK/check |
|---|---|
| `users` | `id`, `auth_uid→auth.users`, `email`, `phone`, `phone_verified`, `sns_providers`, `account_status`, `withdrawn_at`, `display_name`, `avatar_url`, `birth_date`, `gender`, `show_age`, `show_gender`, `last_login_at`, `premium_boost`, `referral_source`, `invited_by→users`, `experience_level`, `activity_frequency`, `activity_days`, `plays_instrument`, `employment`, `favorite_artists`, `gear`, `bio`, `style_orientation`, recruiting 조건 필드, timestamps |
| `groups` | `id`, `created_by→users`, `name`, `avatar_url`, `bio`, `account_status`, `last_active_at`, `premium_boost`, style/activity/recruiting 조건 필드, timestamps |
| `areas` | `id`, `parent_id→areas`, `code`, `name`, `level(prefecture/city/station)`, `sort_order`, `is_active`, timestamps |
| `parts`, `genres` | `id`, unique `code/name/sort_order`, `is_active`, timestamps |
| `user_purposes` | `id`, `user_id→users`, `purpose(recruit/join/practice)`, timestamps, unique `(user_id,purpose)` |
| `user_parts` | `id`, `user_id→users`, `part_id→parts`, `other_part_text`, timestamps, unique `(user_id,part_id)` |
| `user_genres` | `id`, `user_id→users`, `genre_id→genres`, timestamps, unique `(user_id,genre_id)` |
| `user_target_parts`, `user_recruiting_parts` | `id`, `user_id→users`, `part_id→parts`, timestamps, unique `(user_id,part_id)` |
| `user_areas` | `id`, `user_id→users`, `area_id→areas`, `show_on_profile`, `is_primary`, timestamps, unique `(user_id,area_id)` |
| `group_genres` | `id`, `group_id→groups`, `genre_id→genres`, timestamps, unique `(group_id,genre_id)` |
| `group_target_parts`, `group_recruiting_parts` | `id`, `group_id→groups`, `part_id→parts`, timestamps, unique `(group_id,part_id)` |
| `group_members` | `id`, `user_id→users`, `group_id→groups`, `part_id→parts`, `other_part_text`, `role(admin/member)`, `membership_status(active/left/removed)`, `joined_at`, `left_at`, `removed_by→users`, timestamps, unique `(user_id,group_id)` |
| `group_areas` | `id`, `group_id→groups`, `area_id→areas`, `show_on_profile`, `is_primary`, timestamps, unique `(group_id,area_id)` |
| `media_portfolios` | `id`, nullable one-of `user_id→users`/`group_id→groups`, `platform`, `embed_url`, title/description/thumbnail/sort/public, timestamps |
| `blocks` | `id`, `blocker_id→users`, `blocked_id→users`, timestamps, non-self, unique pair |
| `message_requests` | user/group sender one-of, user/group receiver one-of, `status`, `note`, `responded_at`, `responded_by→users`, timestamps, self-target 금지 |
| `message_rooms` | `id`, unique `request_id→message_requests`, `initial_note`, `last_message_at`, timestamps |
| `room_participants` | `id`, `room_id→message_rooms`, `user_id→users`, `participant_role`, `joined_at`, `left_at`, `last_read_at`, timestamps, unique `(room_id,user_id)` |
| `messages` | `id`, `room_id→message_rooms`, `sender_user_id→users`, `acting_group_id→groups`, `message_type(text/stamp)`, `body`, `stamp_code`, timestamps, payload CHECK |
| `message_reads` | `id`, `message_id→messages`, `user_id→users`, `read_at`, timestamps, unique `(message_id,user_id)` |
| `reviews` | `id`, `room_id→message_rooms`, reviewer/reviewee user-or-group FKs, `rating`, `comment`, blind/publish timestamps, `is_published`, timestamps |
| `reports` | `id`, `reporter_id→users`, target user/message FKs, `reason`, `details`, `status`, `admin_note`, resolution fields, `resolved_by→admin_users`, timestamps |
| `notifications` | `id`, `user_id→users`, `notification_type`, title/body/reference, `is_read`, `read_at`, timestamps |
| `legal_documents` | `id`, `document_type`, `version`, title/body, `effective_at`, `is_published`, timestamps, unique type/version |
| `user_consents` | `id`, `user_id→users`, `legal_document_id→legal_documents`, `consented_at`, timestamps, unique pair |
| `invitations` | `id`, `inviter_id→users`, type/code, target group/part, invitee email, status, registered user/time, reward status, expiry, timestamps |
| `admin_users` | `id`, `auth_uid→auth.users`, `email`, `role(admin/moderator)`, `is_active`, timestamps |
| `admin_actions` | `id`, `admin_id→admin_users`, action/target/reason, timestamps |
| `ads` | `id`, title/description/image/link/advertiser, `area_target_id→areas`, active/priority/schedule, timestamps |
| `waitlist` | `id`, unique `email`, `area_text`, `referral_source`, timestamps |
| `subscriptions` | `id`, `user_id→users`, provider/customer/subscription/plan, `status`, period/cancel fields, timestamps |
| `payment_history` | `id`, `user_id→users`, `subscription_id→subscriptions`, provider/payment/amount/currency/status, `paid_at`, timestamps |
| `recruitment_posts` | `id`, `group_id→groups`, `title`, `body`, `status(draft/open/closed)`, timestamps |
| `recruitment_post_parts` | `id`, `post_id→recruitment_posts`, `part_id→parts`, timestamps, unique pair |
| `recruitment_post_genres` | `id`, `post_id→recruitment_posts`, `genre_id→genres`, timestamps, unique pair |
| `recruitment_post_areas` | `id`, `post_id→recruitment_posts`, `area_id→areas`, timestamps, unique pair |
| `recruitment_applications` | `id`, `recruitment_post_id→recruitment_posts`, `group_id→groups`, `applicant_user_id→users`, `status`, `note`, response actor/time, timestamps; 최종 uniqueness는 pending row partial index |

FK delete action은 identity/history에는 주로 `restrict`, 소유 join에는 `cascade`, 선택적 참조에는 `set null`이다. 정확한 type/default/delete action의 source of truth는 기존 migration이며 이 문서는 기존 정의를 대체하지 않는다.

## 2. 현재 view register

| view | 반환 범위 | 분류 |
|---|---|---|
| `user_public_profiles` | 초기 public profile projection | 교체 후 deprecate 후보; 현재 safe contract와 중복 |
| `user_public_areas` | 초기 public area projection | 유지 여부 검토; broad area 원칙에는 맞음 |
| `member_search_profiles` | active/nonblocked safe member list | 유지·확장 또는 STAGE public profile v2로 migration |
| `member_public_profile_details` | safe member detail | 유지·확장 |
| `received_message_requests_view` | 본인 수신 request + safe sender | inquiry 범위 결정 후 유지 |
| `my_chat_rooms` | 본인 active accepted direct rooms + unread | 유지; 차단/참가자 계약 보존 |

새 view를 만들 때 `users`의 `email`, `phone`, `auth_uid`, `phone_verified`, billing/admin/system 필드를 절대 포함하지 않는다.

## 3. 현재 RPC/function register

### 3.1 유지해야 할 기반 helper

`set_updated_at`, `protect_user_system_fields`, `current_user_id`, `is_admin`, `is_group_admin`, `can_initialize_group_member`, `can_act_for_party`, `is_party_active`, `has_block_relationship`, `is_public_profile_visible`, `is_room_participant`, `is_room_group_party`, `is_active_accepted_room_participant`, `room_has_block_relationship`.

분류: **유지·확장**. STAGE 신규 RLS에서 재사용하되 exact station이나 crew activity 권한은 목적별 helper를 추가한다. 범용 helper 하나에 모든 권한을 넣지 않는다.

### 3.2 사용자/검색/profile

| 함수 | 분류 |
|---|---|
| `search_member_profiles` | STAGE person discovery가 확정될 때까지 유지; public profile v2로 migration 가능 |
| `get_my_page_profile` | 유지·확장 |
| `update_my_avatar_url` | 유지 |
| `assert_active_master_ids` | 내부 validation helper로 유지; client execute는 계속 금지 |
| `withdraw_current_user` | 보존; 실제 STAGE account UX/법적 결정 전 활성화하지 않음 |
| `get_user_safety_state`, `block_user`, `unblock_user`, `report_user`, `get_my_blocked_users` | 유지·확장 |

### 3.3 메시지

| 함수 | 분류 |
|---|---|
| `get_member_relationship_state`, `send_message_request` | inquiry 정책에 맞게 확장 또는 recruitment-specific API로 migration |
| `accept_message_request` | 유지하되 block 재검사 gap 별도 hardening |
| `prevent_duplicate_open_direct_message_requests` | 유지 |
| `get_room_messages`, `send_room_message` | 유지; block 후 read 정책 별도 hardening |
| `mark_chat_room_read`, `get_my_badge_counts` | 유지·확장 |

### 3.4 그룹/모집

| 함수 | 분류 |
|---|---|
| `get_my_group_profiles`, `create_my_group_profile`, `update_my_group_profile` | UI는 crew; event/lifecycle 확장 |
| `get_group_members`, `leave_group`, `remove_group_member` | 유지·확장 |
| `get_my_group_recruitment_posts`, `create_my_group_recruitment_post`, `update_my_group_recruitment_post` | target event와 role 조건 추가 |
| `get_public_recruitment_posts` | STAGE discovery projection으로 migration |
| `get_my_recruitment_application_state`, `apply_to_recruitment_post` | 유지·확장 |
| `get_my_group_recruitment_applications`, `accept_recruitment_application`, `reject_recruitment_application` | 유지·확장 |

### 3.5 현재 있지만 STAGE MVP 경로가 불명확한 함수

`is_valid_review_parties`, `publish_due_reviews`, `publish_reciprocal_reviews`, `redeem_invitation`.

분류: **보존/제품 결정 필요**. 참조를 제거하거나 object를 drop하지 않는다.

## 4. 현재 index·trigger·policy·grant 분류

### 4.1 index

| index 묶음 | exact names | 분류 |
|---|---|---|
| active/list | `users_active_last_login_idx`, `groups_active_last_active_idx`, `ads_active_target_idx` | 유지 |
| user taxonomy | `user_purposes_purpose_idx`, `user_parts_part_idx`, `user_genres_genre_idx`, `user_areas_area_idx`, `user_areas_one_primary_per_user` | 기존 object 수명 동안 유지; role migration 후 part index만 cleanup 후보 |
| group | `group_members_group_idx`, `group_members_active_group_idx`, `group_areas_area_idx`, `group_areas_one_primary_per_group` | 유지·확장 |
| messaging | `message_requests_receiver_idx`, `message_requests_one_pending_direct_user_pair`, `room_participants_user_idx`, `messages_room_created_idx` | 유지 |
| recruitment | `recruitment_posts_group_status_idx`, `recruitment_post_parts_part_idx`, `recruitment_post_genres_genre_idx`, `recruitment_post_areas_area_idx`, `recruitment_applications_group_status_idx`, `recruitment_applications_applicant_idx`, `recruitment_applications_one_pending_per_post_user` | 유지; role index는 새 object 추가 |
| notification/review | `notifications_user_unread_idx`, `reviews_one_per_party_per_room` | 유지 |

신규 FK/filter/order-by에는 실행 계획을 확인한 뒤 index를 추가한다. recommendation source를 위해 exact station index가 필요해도 public query에 노출하지 않는다.

### 4.2 trigger

- 모든 초기 mutable table, `group_areas`, recruitment tables/applications의 table-scoped `set_updated_at`: 유지
- `users.protect_user_system_fields`: 유지·필드 목록 확장
- `reviews.publish_reciprocal_reviews`: review 기능 보존 기간 동안 유지
- `message_requests.prevent_duplicate_open_direct_message_requests`: 유지

새 STAGE 상태 전이는 client trigger보다 명시적 transactional RPC를 우선한다.

### 4.3 RLS policy families

아래 exact policy family는 현재 protection을 유지한다.

- master: `areas_read_active`, `parts_read_active`, `genres_read_active`, `master_data_admin_manage_*`
- user/self: `users_select_self`, `users_insert_self`, `users_update_self_unverified`, `users_update_self_verified`, `users_admin_manage`
- user joins: `user_purposes_*`, `user_parts_*`, `user_genres_*`, `user_target_parts_*`, `user_recruiting_parts_*`, `user_areas_*`
- group: `groups_read_active_or_manage`, `groups_insert_creator`, `groups_update_admin`, `groups_admin_manage`, `group_genres_*`, `group_target_parts_*`, `group_recruiting_parts_*`, 최종 `group_members_read`, `group_members_insert_admin`, `group_members_update_admin`, `group_areas_read`, `group_areas_write`
- media: `media_read_public_or_owner`, `media_insert_owner`, `media_update_owner`, `media_delete_owner`
- request/chat: `requests_select_party`, `requests_insert_sender`, `requests_reject_recipient`, `requests_admin_manage`, `rooms_select_participant`, `rooms_admin_manage`, `room_participants_select_participant`, `room_participants_admin_manage`, `messages_select_participant`, `messages_insert_participant`, `messages_admin_manage`, `message_reads_*`
- recruitment: `recruitment_posts_admin_manage`, `recruitment_post_parts_admin_manage`, `recruitment_post_genres_admin_manage`, `recruitment_post_areas_admin_manage`, `recruitment_applications_read_parties`
- safety: `blocks_select_self`, `blocks_insert_self`, `blocks_delete_self`, `reports_select_reporter_or_admin`, `reports_insert_reporter`, `reports_admin_manage`
- self data: `notifications_select_self`, `notifications_update_self`, `notifications_admin_manage`, `reviews_*`, `consents_*`, `subscriptions_*`, `payment_history_*`
- operation: `legal_documents_*`, `invitations_*`, `admin_users_*`, `admin_actions_*`, `ads_*`, `waitlist_*`
- Storage: `avatars_public_read`, `avatars_insert_own_folder`, `avatars_update_own_folder`, `avatars_delete_own_folder`

분류:

- 기존 table의 policy는 **유지**한다.
- 새 STAGE table은 기본 RLS enabled + direct `public/anon` revoke부터 시작한다.
- 민감 location, approval, verification은 safe RPC를 통해서만 접근한다.
- public catalog도 write는 operator/owner RPC로 제한한다.

### 4.4 grants/revokes

현재 safe view/RPC 대부분은 `public, anon` 권한을 revoke하고 `authenticated`에 필요한 select/execute만 grant한다. master active rows와 public avatar object만 비로그인 read가 허용된다.

STAGE 공개 deep link를 로그인 전에도 보여줄지 결정되기 전에는 event/lesson/recruitment RPC를 `anon`에 일괄 grant하지 않는다. 공개 preview가 필요하면 별도 최소 projection을 만든다.

## 5. 제안 target entities

### 5.1 identity·taxonomy

| entity/extension | 목적·주요 컬럼 | 소유/FK | read/write·민감성 |
|---|---|---|---|
| `users` extension | `performance_domain`, public professional state, dance experience/availability | 본인 row | self write RPC; public projection만. 인증/결제 필드는 private |
| `performance_roles` | dance role/position와 미래 band role (`domain`, `code`, `name`, `sort_order`, `is_active`) | operator master | active public read, operator write |
| `user_performance_roles` | 사용자 역할/숙련/희망 | user, role FK | 본인 write; 공개 허용 필드만 projection |
| `group_performance_roles` | crew role 구성 | group, role FK | active group read; admin write |
| `recruitment_post_roles` | 모집 role/인원/필수 수준 | post, role FK | open post safe read; group admin write |
| `genres` extension | `domain`, `category` | operator master | active public read, operator write |

기존 `parts` data는 role로 자동 해석하지 않는다. 명시적 mapping table 또는 one-time mapping audit를 거친다.

### 5.2 location privacy

| entity | 주요 컬럼 | 권한 |
|---|---|---|
| `stations` | railway operator/line/station code, display name, prefecture/city, approximate coordinate | read-only master; operator import |
| `station_lines` 또는 station-line join | 역/노선 다대다 | read-only master |
| `user_private_locations` | `user_id`, `nearest_station_id`, optional walking band, consent/update time | 본인/운영자만 direct access. public 금지 |
| same-crew station RPC | crew ID를 받아 active member의 제한된 station 정보 반환 | 호출자도 active same crew여야 함; public list/검색에서 호출 금지 |

recommendation 계산 결과에는 개인별 exact station을 포함하지 않는다. 같은 crew UI에서 exact station을 보여주는 요구는 별도 member-only RPC로 구현하며 활동 탈퇴 즉시 접근이 사라져야 한다.

### 5.3 professional verification

| entity | 주요 컬럼 | 권한 |
|---|---|---|
| `users.professional_state` | `general`, `professional_unverified`, `professional_verified` | 본인은 unverified 신청 가능; verified는 operator only |
| `professional_verifications` | applicant, evidence metadata, status, reviewed_by/at, reason, audit | 본인 자기 상태 + operator; evidence private |

public projection은 검증 상태 badge만 반환하고 evidence, admin note는 반환하지 않는다.

### 5.4 events·crew lifecycle·recruitment

| entity/extension | 목적·키 | 권한/RLS |
|---|---|---|
| `event_organizers` | organizer identity, official URLs, verification state | published safe read; operator write |
| `stage_events` | title, category, venue, start/end, application deadline, fee summary, source URL/type, last_verified_at, publish/status | published safe read; operator/editor write |
| `crew_event_targets` | group/event, status, selected/started/ended, archive summary; active target 1개 | active crew member read; admin write |
| `recruitment_posts.target_event_id` | post가 목표 event를 참조 | open safe read; group admin write |
| `recruitment_applications` extension | optional condition snapshot/decision code | applicant와 group admin만 |

AI 수집 row는 곧바로 published가 되면 안 된다. `source_type`, `source_url`, `last_verified_at`, `review_status`, `reviewed_by/at`를 요구한다.

### 5.5 crew activity

| entity | 주요 컬럼/FK | ownership/read/write |
|---|---|---|
| `crew_practices` | group, title, starts/ends, studio/room optional, status, created_by | active member read; admin create/update/cancel |
| `practice_attendance` | practice/user, response, responded_at, note | active member self write; active crew read |
| `schedule_polls` | group, title, deadline, status, finalized_option/practice | active member read; admin create/finalize |
| `schedule_poll_options` | poll, starts/ends, optional studio | member read; admin write |
| `schedule_poll_responses` | option/user, response | self write; crew aggregate/member read 정책 결정 |
| `crew_announcements` | group, title/body, pinned, published_by/at, archived_at | member read; admin write |
| `crew_resources` | group, optional practice/event, type, title, external_url, provider, added_by | member read; leader/member write 정책 |
| `crew_activity_events` | group, event type/reference/time, immutable summary | member/archive read; trusted RPC write |

full video binary는 저장하지 않는다. URL protocol/domain validation과 안전 경고가 필요하다.

### 5.6 lessons·studios

| entity | 주요 컬럼/FK | ownership/read/write |
|---|---|---|
| `lessons_workshops` | instructor user optional, organizer, title, genre, schedule, area, fee, external application/source URL, verification fields | published safe read; verified instructor/operator write |
| `studios` | name, area, address display, lat/lng, website/booking URL, status | published safe read; operator write |
| `studio_rooms` | studio, name, capacity, size, hourly-price summary | safe read; operator write |
| `studio_facilities` | code/name master | safe read; operator write |
| `studio_room_facilities` | room/facility | safe read; operator write |
| `studio_accesses` | station, walking minutes, access note | safe read; operator write |
| `studio_recommendation_runs` | group, requester, criteria snapshot, method/version, expiry | active member read; leader execute/save 여부 결정 |
| `studio_recommendation_items` | run/studio, rank/score/reason aggregate | same crew read; system write |

recommendation run에는 개인 station 원문을 복제하지 않는다. 계산 시 `user_private_locations`를 읽고 aggregate score/reason만 저장한다.

## 6. 추천 알고리즘 두 옵션

| 항목 | 좌표/근사 방식 | 실제 route API |
|---|---|---|
| 입력 | station 좌표, 거리, 환승 근사 | 출발역별 route/time/fare |
| 비용 | 낮음; 자체 계산 가능 | 호출량×member×studio 비용, quota 관리 |
| 정확도 | 환승/노선 불편을 반영하기 어려움 | 실제 이동시간과 환승 반영 |
| latency | 낮고 예측 가능 | 외부 API/network/cache 영향 |
| 개인정보 | raw station을 서버 내부 계산 | 제3자 API에 station pair 전송 가능 |
| 운영 | coordinate master 품질 필요 | provider 계약/약관/키 관리 필요 |
| MVP 적합성 | Shinjuku 소규모 catalog에 적합 | 검증 후 beta/유료 기능 후보 |

최종 알고리즘은 이 분석에서 결정하지 않는다. UI와 DB는 `method`, `algorithm_version`, `criteria_snapshot`으로 둘 다 수용한다.

## 7. 안전·보존·삭제

### 민감 필드

- 현재: `auth_uid`, email, phone, phone verification, SNS provider, system/account status, billing, admin notes/actions
- 신규: exact nearest station, verification evidence, minor/guardian 관련 정보, recommendation raw inputs

이 필드는 public view, 검색 RPC, recruitment projection에 포함하지 않는다.

### 보존 원칙

- crew/event/practice/resource는 status/archive를 사용하고 즉시 hard delete하지 않음
- user withdrawal은 public visibility 제거와 법적 보존 대상을 분리
- source event/lesson은 last-verified와 expired 상태 유지
- operator 변경은 audit actor/time/reason 기록
- external URL 삭제/변경 이력은 최소한 updated/source verification audit로 추적

## 8. 필수 safe RPC/view

후속 구현에서 목적별로 제안한다.

- `get_my_stage_profile` / `update_my_stage_profile`
- `get_public_stage_profile(user_id)`
- `get_crew_members_public(crew_id)`
- `get_crew_member_private_station(crew_id, user_id)` 또는 더 제한된 member-only projection
- `get_stage_home_summary`
- `get_crew_home_summary(crew_id)`
- `search_crew_recruitments(filters)`
- target event 선택/종료 transactional RPC
- practice/poll/attendance mutation RPC
- announcement/resource mutation RPC
- event/lesson/studio safe catalog RPC
- `recommend_crew_studios(crew_id, criteria)` SECURITY DEFINER
- STAGE badge summary RPC

거대 RPC 하나가 모든 tab 데이터를 반환하게 만들지 않는다. 권한, cache, failure domain이 다른 데이터를 분리한다.

## 9. RLS 설계 원칙

1. 새 table은 생성 즉시 RLS enable.
2. `public`, `anon`은 기본 revoke.
3. public catalog는 published/active 최소 projection만 read.
4. group operational data는 active `group_members`만 read.
5. create/update/delete는 group admin/leader 또는 자기 row만.
6. 승인·finalize·target 전환은 transactional SECURITY DEFINER RPC.
7. exact station/verification evidence는 direct table select를 client에 grant하지 않음.
8. block 관계를 public profile, inquiry, chat send/read 정책에 일관되게 적용.
9. `search_path = public, pg_temp`, 명시적 schema qualification, 최소 반환 field를 유지.
10. 모든 policy/RPC에 non-member, former member, blocked, suspended, direct-RPC negative test를 추가.

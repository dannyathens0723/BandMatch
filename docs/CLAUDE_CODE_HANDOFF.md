# STAGE Claude Code Handoff

## Objective

STAGE is replacing the BandMatch-first presentation with a dance Crew product.
The near-term objective is to cover the roughly 50-screen STAGE wireframe
quickly enough to ship a public test build to Hongo and other testers, while
preserving caller-scoped Supabase security and the legacy BandMatch mode.

## Repository state

- Repository: `C:\Users\PC-Le-143\Documents\work_local\99_HGMY\Dev\BandMatch`
- Branch: `stage-redesign`
- Baseline HEAD for this sprint: `cd2bf509f5eefdfd1f0abc7a0f8e2d37b95cc062`
- Migrations confirmed remotely applied by the user: `001`–`042`
- New migration: `043_stage_crew_activity_operating_loop.sql`
- Migration 043 has **not** been executed remotely by Codex.
- Codex has not committed or pushed this sprint.

## Source-of-truth priority

1. `docs/STAGE.html` and `docs/design/reference/`
2. `docs/product/STAGE_SERVICE_OVERVIEW.md`
3. `docs/product/STAGE_BRAND_CONCEPT.md`
4. `docs/stage-analysis/02_WIREFRAME_SCREEN_AND_ROUTE_AUDIT.md`
5. `docs/stage-analysis/03_BANDMATCH_TO_STAGE_GAP_ANALYSIS.md`
6. `docs/stage-analysis/04_STAGE_DATA_MODEL_PLAN.md`
7. `docs/stage-analysis/05_STAGE_MIGRATION_SEQUENCE.md`
8. `docs/stage-analysis/06_STAGE_IMPLEMENTATION_ROADMAP.md`

Older BandMatch documents and code are legacy technical references, not the
final STAGE presentation source of truth.

## Implemented runtime journeys

- STAGE-branded authentication and authenticated five-tab shell
- Home dashboard and derived Activity Center
- Crew discovery, application, My Crew, Crew creation/editing, recruitment
  management, applicant decisions, and active membership creation
- Crew Home with safe multi-Crew context switching
- Practice create/edit/complete/cancel and member self-attendance
- Schedule poll create/respond/cancel/finalize with optional atomic practice
  creation
- Crew announcements and HTTPS-only external resources
- Current target event plus read-only activity/history view
- Stage event and Studio discovery/detail with external-link confirmation
- My Page, STAGE profile edit, and taxonomy save/restore
- Legacy BandMatch startup remains selected when `STAGE_PROFILE_FLOW=false`

Primary Crew route hierarchy:

`クルー → マイクルー → Crew Home → 練習予定 / 日程調整 / お知らせ / 練習資料 / 活動履歴`

## Migration 043 security conventions

- Caller identity is derived from the authenticated session through
  `require_stage_active_user_v1()`; no acting-user ID is accepted.
- Crew reads/self-actions require active membership in an active Crew.
- Management mutations require active `admin` membership.
- New tables have RLS enabled and direct `public`, `anon`, and `authenticated`
  privileges revoked.
- Client access is through narrow `SECURITY DEFINER` RPCs with
  `search_path = public, pg_temp` and schema-qualified objects.
- PUBLIC and anon cannot execute client RPCs; authenticated receives only the
  listed RPC grants. The internal membership helper is not client-executable.
- No email, phone, auth UID, exact private station, billing, moderation, or
  admin-only profile data is projected.
- Practice and poll history is status-based rather than deleted.
- Attendance responses lock and recheck the scheduled practice row before
  upsert, serializing them with practice cancellation or completion.
- Poll responses lock and recheck the open poll row before upsert, serializing
  them with poll cancellation or finalization. Poll finalization creates at
  most one resulting practice in the same transaction.
- Selecting the already-active target event returns its existing target ID
  without archiving it or creating duplicate target history.
- Resource URLs must be HTTPS, bounded, whitespace-free URLs and are confirmed
  again in Flutter before external launch.

## Live manual-test stabilization

- Live Crew Activity testing found that announcement feed cards discarded the
  announcement identifier and opened generic Crew Home. Home, Activity Center,
  and Crew announcement lists now use one server-backed announcement-detail
  route scoped by both Crew ID and announcement ID.
- Live testing also found that invalid resource URLs failed silently. The form
  now keeps its values, focuses the URL field, shows the controlled Japanese
  HTTPS validation message, and avoids the RPC until validation succeeds.
- These two corrections are implemented locally, but the complete Crew
  Activity manual retest has not yet been confirmed by the user.

## Flutter Web run

Supply only the normal project URL and publishable/anon key through the
existing local configuration mechanism. Never place a service-role key or any
secret in Flutter source, browser defines, documentation, or commits.

Typical STAGE run after local configuration:

```powershell
Set-Location app
flutter run -d chrome --dart-define=STAGE_PROFILE_FLOW=true
```

## Automated validation

Latest local validation on 2026-08-03:

- `dart analyze`: passed, no issues
- focused Crew activity contract/screen tests: 18 passed
- Home/Activity/My Page screen regressions: 12 passed
- Crew discovery/My Crew/management regressions: 25 passed
- selected Stage/Studio/profile regressions: 31 passed
- `flutter test test/stage_profile_flow`: 126 passed
- `flutter build web --dart-define=STAGE_PROFILE_FLOW=true`: passed
- `git diff --check`: passed (Windows LF-to-CRLF notices only)

No SQL was executed and no browser-based manual Crew activity verification was
performed during this sprint.

## Manual-test data and cleanup

- Existing Stage event and Studio seed records may be present. Preserve them.
- Earlier seed/cleanup SQL was supplied in conversation only; migrations do
  not seed manual-test data.
- Crew activity test records created through the UI should use the prefix
  `STAGE_MVP_ACTIVITY_TEST_`.
- Cleanup should archive resources/announcements, cancel test practices/polls,
  and replace the current target through the UI. Do not delete existing Stage
  or Studio seed records. If SQL cleanup is required, first capture the exact
  Crew and child UUIDs and delete only those dedicated test rows in dependency
  order inside a transaction.

## Known limits and deferred work

- Migration 043 must be reviewed and manually applied before real Crew
  activity calls can succeed.
- No Realtime, push notification, unread state, Crew group chat, native
  calendar, map SDK, media upload/proxy, payment, Crew deletion, or ownership
  transfer was added.
- Resource links are external references only.
- Activity is derived and has no persistent unread/read state.
- Browser URL deep links still use the current Navigator-based MVP shell and
  fall back safely to authenticated roots after a full refresh.
- The legacy `StageProfileService` still accesses the global Supabase singleton
  lazily; isolated shell widget tests intentionally log a missing-initialization
  diagnostic when that dependency is not injected, although the focused and
  full STAGE test groups pass.
- Messaging core loop, remaining wireframe coverage, public test deployment,
  and later block/report expansion remain next-stage work.

## Next priorities

1. Complete the current Crew Activity stabilization and manual retest.
2. Complete the messaging core loop.
3. Cover the remaining approximately 50-screen wireframe scope.
4. Stabilize and deploy the public test version.
5. Expand block/report later in MVP after the core operating loops are stable.

## Resume instructions for Claude Code

1. Read this file and the source-of-truth files above.
2. Check branch, HEAD, and the entire working tree before editing.
3. Confirm which migrations the user has actually applied; never infer remote
   state from local files.
4. Preserve Migration 001–042 and legacy BandMatch mode.
5. Keep DB work in numbered migrations, use caller-scoped RPCs, and test role
   and status negative paths before wiring new Flutter UI.
6. Do not commit, push, deploy, or execute remote SQL without explicit user
   instruction.

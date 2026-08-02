import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    migration = File(
      '../supabase/migrations/043_stage_crew_activity_operating_loop.sql',
    ).readAsStringSync();
  });

  test('Migration 043 creates the complete Crew activity object set', () {
    for (final table in [
      'stage_crew_practices',
      'stage_crew_attendance',
      'stage_crew_schedule_polls',
      'stage_crew_schedule_poll_options',
      'stage_crew_schedule_poll_responses',
      'stage_crew_announcements',
      'stage_crew_resources',
      'stage_crew_event_targets',
    ]) {
      expect(migration, contains('create table public.$table'));
      expect(
        migration,
        contains('alter table public.$table enable row level security'),
      );
      expect(migration, contains('revoke all on table public.$table'));
    }
  });

  test('caller identity and active Crew authorization are server derived', () {
    expect(migration, contains('public.require_stage_active_user_v1()'));
    expect(migration, contains("crew.account_status = 'active'"));
    expect(migration, contains("member.membership_status = 'active'"));
    expect(migration, contains("member.role in ('admin', 'member')"));
    expect(migration, isNot(contains('p_user_id')));
    expect(migration, isNot(contains('p_actor_id')));
  });

  test('member and admin RPCs use a safe SECURITY DEFINER boundary', () {
    expect(migration, contains('security definer'));
    expect(migration, contains('set search_path = public, pg_temp'));
    expect(
      migration,
      contains('require_stage_active_crew_member_v1(p_crew_id, true)'),
    );
    expect(migration, isNot(contains('service_role')));
  });

  test('attendance is a caller-only upsert with one row per practice', () {
    final function = migration.substring(
      migration.indexOf(
        'create or replace function public.respond_stage_crew_attendance_v1',
      ),
      migration.indexOf(
        'create or replace function public.create_stage_crew_poll_v1',
      ),
    );
    expect(migration, contains('primary key (practice_id, user_id)'));
    expect(function, contains('on conflict (practice_id, user_id) do update'));
    expect(function, contains("practice.status = 'scheduled'"));
    expect(function, contains('for update;\n  if not found then'));
    expect(migration, isNot(contains('p_attendance_user_id')));
  });

  test('poll responses are caller-only and option scoped', () {
    final function = migration.substring(
      migration.indexOf(
        'create or replace function public.respond_stage_crew_poll_v1',
      ),
      migration.indexOf(
        'create or replace function public.cancel_stage_crew_poll_v1',
      ),
    );
    expect(migration, contains('primary key (option_id, user_id)'));
    expect(function, contains('option.poll_id = p_poll_id'));
    expect(function, contains('on conflict (option_id, user_id) do update'));
    expect(function, contains("poll.status = 'open'\n  for update;"));
    expect(function, contains('for update;\n  if not found then'));
    expect(migration, isNot(contains('p_response_user_id')));
  });

  test('poll finalization locks once and creates at most one practice', () {
    final function = migration.substring(
      migration.indexOf(
        'create or replace function public.finalize_stage_crew_poll_v1',
      ),
      migration.indexOf(
        'create or replace function public.upsert_stage_crew_announcement_v1',
      ),
    );
    expect(function, contains('for update'));
    expect(function, contains("v_poll.status <> 'open'"));
    expect(function, contains("set status = 'finalized'"));
    expect(function, contains('resulting_practice_id = v_practice_id'));
  });

  test('practice cancellation preserves attendance history', () {
    expect(migration, contains("set status = p_status"));
    expect(
      migration,
      isNot(contains('delete from public.stage_crew_attendance')),
    );
  });

  test('announcements never project private author fields', () {
    expect(
      migration,
      contains("'author_display_name', author_profile.display_name"),
    );
    for (final privateField in ['auth_uid', 'phone_verified', 'admin_note']) {
      expect(migration, isNot(contains(privateField)));
    }
  });

  test('Crew resources enforce HTTPS and bounded URLs', () {
    expect(migration, contains(r"external_url ~ '^https://[^[:space:]]+$'"));
    expect(migration, contains('char_length(external_url) <= 2000'));
    expect(migration, isNot(contains('javascript:')));
    expect(migration, isNot(contains('data:')));
  });

  test('target history has one active target and hides private events', () {
    final function = migration.substring(
      migration.indexOf(
        'create or replace function public.set_stage_crew_target_event_v1',
      ),
      migration.indexOf(
        'create or replace function public.get_stage_crew_activity_feed_v1',
      ),
    );
    expect(migration, contains('stage_crew_event_targets_one_active_idx'));
    expect(function, contains("event.publication_status = 'published'"));
    expect(function, contains("organizer.verification_status = 'verified'"));
    expect(function, contains("genre.domain = 'dance'"));
    expect(
      function,
      contains("event.event_status not in ('cancelled', 'completed')"),
    );
    expect(
      function,
      contains(
        "target.event_id = p_event_id\n    and target.status = 'active';",
      ),
    );
    expect(function, contains('if found then\n    return v_target_id;'));
    expect(function, contains("set status = 'archived', ended_at = now()"));
  });

  test('PUBLIC and anon receive no RPC execution', () {
    for (final rpc in [
      'get_stage_crew_home_v1',
      'get_stage_crew_activity_v1',
      'upsert_stage_crew_practice_v1',
      'respond_stage_crew_attendance_v1',
      'create_stage_crew_poll_v1',
      'respond_stage_crew_poll_v1',
      'cancel_stage_crew_poll_v1',
      'finalize_stage_crew_poll_v1',
      'upsert_stage_crew_announcement_v1',
      'upsert_stage_crew_resource_v1',
      'set_stage_crew_target_event_v1',
      'get_stage_crew_activity_feed_v1',
    ]) {
      expect(migration, contains('function public.$rpc'));
    }
    expect(migration, contains('from public, anon'));
    expect(migration, contains('to authenticated'));
  });

  test('legacy recruiting and messaging state are untouched', () {
    expect(migration, isNot(contains('groups.is_recruiting')));
    expect(migration, isNot(contains('group_recruiting_parts')));
    expect(migration, isNot(contains('message_rooms')));
    expect(migration, isNot(contains('messages ')));
  });
}

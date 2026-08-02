import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    migration = File(
      '../supabase/migrations/042_stage_home_activity_profile.sql',
    ).readAsStringSync();
  });

  test('Migration 042 exposes only caller-scoped STAGE RPCs', () {
    expect(migration, contains('public.require_stage_active_user_v1()'));
    expect(migration, contains('public.get_stage_my_profile_v1()'));
    expect(migration, contains('public.update_stage_my_profile_v1('));
    expect(migration, contains('public.get_stage_activity_feed_v1()'));
    expect(migration, isNot(contains('p_user_id')));
    expect(migration, isNot(contains('p_auth_uid')));
    expect(migration, isNot(contains('service_role')));
    expect(migration, isNot(contains('email')));
    expect(migration, isNot(contains('phone')));
    expect(migration, isNot(contains('application.note')));
  });

  test('Migration 042 keeps RPC execution private to authenticated users', () {
    expect(
      RegExp(
        r'revoke all on function[\s\S]+?from public, anon;',
        multiLine: true,
      ).allMatches(migration).length,
      3,
    );
    expect(
      RegExp(
        r'grant execute on function[\s\S]+?to authenticated;',
        multiLine: true,
      ).allMatches(migration).length,
      3,
    );
    expect(migration, isNot(contains('grant select on public.users')));
    expect(migration, isNot(contains('alter table')));
    expect(migration, isNot(contains('create policy')));
  });

  test('activity feed scopes own and managed application data', () {
    expect(migration, contains('application.applicant_user_id = v_user_id'));
    expect(migration, contains('manager.user_id = v_user_id'));
    expect(migration, contains("manager.role = 'admin'"));
    expect(migration, contains("manager.membership_status = 'active'"));
    expect(migration, contains("crew.account_status = 'active'"));
    expect(migration, contains("genre.domain = 'dance'"));
    expect(
      migration,
      contains('distinct on (application.recruitment_post_id)'),
    );
  });
}

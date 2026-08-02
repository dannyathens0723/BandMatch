import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Migration 040 keeps the STAGE Crew loop session scoped and atomic', () {
    final migration = File(
      '../supabase/migrations/040_stage_crew_management.sql',
    ).readAsStringSync();
    final model = File(
      'lib/models/stage_crew_management.dart',
    ).readAsStringSync();

    for (final rpc in [
      'create_stage_crew_v1',
      'update_stage_crew_v1',
      'create_stage_recruitment_v1',
      'update_stage_recruitment_v1',
      'set_stage_recruitment_status_v1',
      'get_stage_recruitment_applicants_v1',
      'decide_stage_recruitment_application_v1',
    ]) {
      expect(migration, contains(rpc));
    }
    expect(migration, contains('public.current_user_id()'));
    expect(migration, contains("profile.account_status = 'active'"));
    expect(migration, contains("genre.domain = 'dance'"));
    expect(migration, contains('public.is_group_admin'));
    expect(migration, contains("application.status <> 'pending'"));
    expect(migration, contains('public.has_block_relationship'));
    expect(migration, contains('on conflict (user_id, group_id) do update'));
    expect(migration, contains('set search_path = public, pg_temp'));
    expect(migration, contains('from public, anon'));
    expect(migration, contains('to authenticated'));
    expect(migration, isNot(contains('service_role')));
    expect(migration, isNot(contains('alter table')));
    expect(migration, isNot(contains('drop table')));

    for (final privateField in [
      'email',
      'auth_uid',
      'phone_verified',
      'payment',
      'subscription',
    ]) {
      expect(model, isNot(contains(privateField)));
    }
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Migration 041 prevents repeat applications without deleting history', () {
    final migration = File(
      '../supabase/migrations/041_stage_recruitment_reapplication_guard.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains(
        'create or replace function public.get_my_recruitment_application_state',
      ),
    );
    expect(
      migration,
      contains('create or replace function public.apply_to_recruitment_post'),
    );
    expect(
      migration,
      contains(
        'create or replace function public.apply_to_stage_recruitment_post_v1',
      ),
    );
    expect(migration, contains('for update of post'));
    expect(migration, contains('application.applicant_user_id = v_user_id'));
    expect(migration, contains("using errcode = '23505'"));
    expect(migration, isNot(contains("application.status = 'pending'")));
    expect(migration, contains('public.current_user_id()'));
    expect(migration, contains("profile.account_status = 'active'"));
    expect(migration, contains("post.status = 'open'"));
    expect(migration, contains("genre.domain = 'dance'"));
    expect(migration, contains('public.has_block_relationship'));
    expect(migration, contains('set search_path = public, pg_temp'));
    expect(migration, contains('from public, anon'));
    expect(migration, contains('to authenticated'));
    expect(migration, isNot(contains('p_applicant_user_id')));
    expect(migration, isNot(contains('delete from')));
    expect(
      migration,
      isNot(contains('update public.recruitment_applications')),
    );
    expect(migration, isNot(contains('alter table')));
    expect(migration, isNot(contains('create unique index')));
  });
}

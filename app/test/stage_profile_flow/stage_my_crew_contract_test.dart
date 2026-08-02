import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'My Crew RPCs are caller-scoped and expose no private application data',
    () {
      final migration = File(
        '../supabase/migrations/039_stage_my_crew_overview.sql',
      ).readAsStringSync();
      final service = File(
        'lib/services/stage_my_crew_service.dart',
      ).readAsStringSync();

      expect(migration, contains('get_stage_my_crews_v1'));
      expect(migration, contains('get_stage_my_crew_applications_v1'));
      expect(migration, contains('v_user_id uuid := public.current_user_id()'));
      expect(migration, contains('profile.account_status = \'active\''));
      expect(migration, contains('membership.user_id = v_user_id'));
      expect(migration, contains('application.applicant_user_id = v_user_id'));
      expect(migration, contains("membership.membership_status = 'active'"));
      expect(migration, contains("genre.domain = 'dance'"));
      expect(migration, contains('set search_path = public, pg_temp'));
      expect(migration, contains('from public, anon'));
      expect(migration, contains('to authenticated'));
      expect(migration, isNot(contains('p_user_id')));
      expect(migration, isNot(contains('application.note')));
      expect(migration, isNot(contains('auth_uid')));
      expect(migration, isNot(contains('email')));

      expect(service, contains("rpc('get_stage_my_crews_v1')"));
      expect(service, contains("'get_stage_my_crew_applications_v1'"));
      expect(service, isNot(contains(".from('group_members')")));
      expect(service, isNot(contains('service_role')));
    },
  );
}

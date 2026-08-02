import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('STAGE Crew discovery uses a Dance-only safe authenticated RPC', () {
    final migration = File(
      '../supabase/migrations/036_stage_crew_discovery.sql',
    ).readAsStringSync();
    final service = File(
      'lib/services/stage_crew_discovery_service.dart',
    ).readAsStringSync();

    expect(migration, contains('get_stage_crew_recruitments_v1'));
    expect(migration, contains("genre.domain = 'dance'"));
    expect(migration, contains("post.status = 'open'"));
    expect(migration, contains("crew.account_status = 'active'"));
    expect(migration, contains('has_block_relationship'));
    expect(migration, contains('from public, anon'));
    expect(migration, contains('to authenticated'));
    expect(migration, isNot(contains('join public.parts')));
    expect(migration, isNot(contains('wanted_part_names')));
    expect(migration, isNot(contains('service_role')));

    expect(service, contains("rpc('get_stage_crew_recruitments_v1')"));
    expect(service, isNot(contains(".from('groups')")));
    expect(service, isNot(contains('service_role')));
  });
}

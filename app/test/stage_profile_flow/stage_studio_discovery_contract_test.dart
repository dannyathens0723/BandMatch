import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('STAGE studio discovery uses safe authenticated versioned RPCs', () {
    final migration = File(
      '../supabase/migrations/038_stage_studio_discovery.sql',
    ).readAsStringSync();
    final service = File(
      'lib/services/stage_studio_discovery_service.dart',
    ).readAsStringSync();

    expect(migration, contains('get_stage_studios_v1'));
    expect(migration, contains('get_stage_studio_detail_v1'));
    expect(migration, contains("studio.publication_status = 'published'"));
    expect(migration, contains("studio.verification_status = 'verified'"));
    expect(migration, contains("studio.operational_status = 'active'"));
    expect(migration, contains("and website_url ~* '^https://"));
    expect(migration, contains("and booking_url ~* '^https://"));
    expect(migration, contains('enable row level security'));
    expect(migration, contains('from public, anon, authenticated'));
    expect(migration, contains('to authenticated'));
    expect(migration, isNot(contains('service_role')));

    expect(service, contains("rpc('get_stage_studios_v1')"));
    expect(service, contains("'get_stage_studio_detail_v1'"));
    expect(service, contains("params: {'p_studio_id': studioId}"));
    expect(service, isNot(contains(".from('stage_studios')")));
    expect(service, isNot(contains('service_role')));
  });
}

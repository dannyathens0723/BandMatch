import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('STAGE event discovery uses safe authenticated versioned RPCs', () {
    final migration = File(
      '../supabase/migrations/037_stage_event_discovery.sql',
    ).readAsStringSync();
    final service = File(
      'lib/services/stage_event_discovery_service.dart',
    ).readAsStringSync();

    expect(migration, contains('get_stage_events_v1'));
    expect(migration, contains('get_stage_event_detail_v1'));
    expect(migration, contains("genre.domain = 'dance'"));
    expect(migration, contains("event.publication_status = 'published'"));
    expect(migration, contains("organizer.verification_status = 'verified'"));
    expect(migration, contains('enable row level security'));
    expect(migration, contains('from public, anon, authenticated'));
    expect(migration, contains('to authenticated'));
    expect(migration, isNot(contains('service_role')));

    expect(service, contains("rpc('get_stage_events_v1')"));
    expect(service, contains("'get_stage_event_detail_v1'"));
    expect(service, contains("params: {'p_event_id': eventId}"));
    expect(service, isNot(contains(".from('stage_events')")));
    expect(service, isNot(contains('service_role')));
  });
}

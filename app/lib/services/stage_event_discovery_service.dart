import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stage_event.dart';

abstract interface class StageEventDiscoveryRepository {
  Future<List<StageEvent>> fetchPublishedEvents();

  Future<StageEvent?> fetchPublishedEvent(String eventId);
}

class StageEventDiscoveryService implements StageEventDiscoveryRepository {
  StageEventDiscoveryService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<StageEvent>> fetchPublishedEvents() async {
    try {
      final response = await _client.rpc('get_stage_events_v1');
      return _parseRows(response, rpcName: 'get_stage_events_v1');
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrest('STAGE event discovery', error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      debugPrint('STAGE event discovery response parsing failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<StageEvent?> fetchPublishedEvent(String eventId) async {
    try {
      final response = await _client.rpc(
        'get_stage_event_detail_v1',
        params: {'p_event_id': eventId},
      );
      final rows = _parseRows(response, rpcName: 'get_stage_event_detail_v1');
      return rows.isEmpty ? null : rows.single;
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrest('STAGE event detail', error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      debugPrint('STAGE event detail response parsing failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  List<StageEvent> _parseRows(dynamic response, {required String rpcName}) {
    if (response is! List) {
      throw FormatException('$rpcName must return a list');
    }
    return response
        .map(
          (row) => StageEvent.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  void _logPostgrest(
    String operation,
    PostgrestException error,
    StackTrace stackTrace,
  ) {
    debugPrint(
      '$operation RPC failed: '
      'message=${error.message}, code=${error.code}, '
      'details=${error.details}, hint=${error.hint}',
    );
    debugPrintStack(stackTrace: stackTrace);
  }
}

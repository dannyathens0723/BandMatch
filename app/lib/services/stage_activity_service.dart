import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stage_activity.dart';

abstract interface class StageActivityRepository {
  Future<List<StageActivity>> fetchMyActivity();
}

class StageActivityService implements StageActivityRepository {
  factory StageActivityService({SupabaseClient? client}) {
    return StageActivityService._(client);
  }

  StageActivityService._(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  Future<List<StageActivity>> fetchMyActivity() async {
    try {
      final response = await _supabase.rpc('get_stage_activity_feed_v1');
      final activity = _parseRows(response, 'get_stage_activity_feed_v1');
      try {
        final crewResponse = await _supabase.rpc(
          'get_stage_crew_activity_feed_v1',
        );
        activity.addAll(
          _parseRows(crewResponse, 'get_stage_crew_activity_feed_v1'),
        );
        activity.sort((left, right) {
          final byDate = right.occurredAt.compareTo(left.occurredAt);
          return byDate != 0
              ? byDate
              : left.activityKey.compareTo(right.activityKey);
        });
      } on PostgrestException catch (error, stackTrace) {
        // Migration 043 may not have been applied yet. The existing activity
        // projection remains usable and this independent section degrades
        // without breaking Home or the Activity Center.
        debugPrint(
          'STAGE Crew activity feed unavailable: message=${error.message}, '
          'code=${error.code}, details=${error.details}, hint=${error.hint}',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      return activity;
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'STAGE activity RPC failed: message=${error.message}, '
        'code=${error.code}, details=${error.details}, hint=${error.hint}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  List<StageActivity> _parseRows(dynamic response, String rpcName) {
    if (response is! List) {
      throw FormatException('$rpcName must return a list');
    }
    return response
        .map(
          (row) =>
              StageActivity.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }
}

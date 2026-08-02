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
      if (response is! List) {
        throw const FormatException(
          'get_stage_activity_feed_v1 must return a list',
        );
      }
      return response
          .map(
            (row) =>
                StageActivity.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false);
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'STAGE activity RPC failed: message=${error.message}, '
        'code=${error.code}, details=${error.details}, hint=${error.hint}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}

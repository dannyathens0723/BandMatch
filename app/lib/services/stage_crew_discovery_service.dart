import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stage_crew_recruitment.dart';

abstract interface class StageCrewDiscoveryRepository {
  Future<List<StageCrewRecruitment>> fetchOpenRecruitments();
}

class StageCrewDiscoveryService implements StageCrewDiscoveryRepository {
  StageCrewDiscoveryService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<StageCrewRecruitment>> fetchOpenRecruitments() async {
    try {
      final response = await _client.rpc('get_stage_crew_recruitments_v1');
      if (response is! List) {
        throw const FormatException(
          'get_stage_crew_recruitments_v1 must return a list',
        );
      }
      return response
          .map(
            (row) => StageCrewRecruitment.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'STAGE Crew discovery RPC failed: '
        'message=${error.message}, code=${error.code}, '
        'details=${error.details}, hint=${error.hint}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      debugPrint('STAGE Crew discovery response parsing failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}

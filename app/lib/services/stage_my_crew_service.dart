import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stage_my_crew.dart';

abstract interface class StageMyCrewRepository {
  Future<StageMyCrewOverview> fetchMyCrewOverview();
}

class StageMyCrewService implements StageMyCrewRepository {
  StageMyCrewService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<StageMyCrewOverview> fetchMyCrewOverview() async {
    try {
      final crewResponse = await _client.rpc('get_stage_my_crews_v1');
      final applicationResponse = await _client.rpc(
        'get_stage_my_crew_applications_v1',
      );
      return StageMyCrewOverview(
        crews: _parseRows(
          crewResponse,
          'get_stage_my_crews_v1',
          StageMyCrew.fromJson,
        ),
        applications: _parseRows(
          applicationResponse,
          'get_stage_my_crew_applications_v1',
          StageMyCrewApplication.fromJson,
        ),
      );
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'STAGE My Crew RPC failed: message=${error.message}, '
        'code=${error.code}, details=${error.details}, hint=${error.hint}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      debugPrint('STAGE My Crew response parsing failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  List<T> _parseRows<T>(
    dynamic response,
    String rpcName,
    T Function(Map<String, dynamic>) parser,
  ) {
    if (response is! List) {
      throw FormatException('$rpcName must return a list');
    }
    return response
        .map((row) => parser(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }
}

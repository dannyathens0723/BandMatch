import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stage_studio.dart';

abstract interface class StageStudioDiscoveryRepository {
  Future<List<StageStudio>> fetchPublishedStudios();

  Future<StageStudio?> fetchPublishedStudio(String studioId);
}

class StageStudioDiscoveryService implements StageStudioDiscoveryRepository {
  StageStudioDiscoveryService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<StageStudio>> fetchPublishedStudios() async {
    try {
      final response = await _client.rpc('get_stage_studios_v1');
      return _parseRows(response, rpcName: 'get_stage_studios_v1');
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrest('STAGE studio discovery', error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      debugPrint('STAGE studio discovery response parsing failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<StageStudio?> fetchPublishedStudio(String studioId) async {
    try {
      final response = await _client.rpc(
        'get_stage_studio_detail_v1',
        params: {'p_studio_id': studioId},
      );
      final rows = _parseRows(response, rpcName: 'get_stage_studio_detail_v1');
      return rows.isEmpty ? null : rows.single;
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrest('STAGE studio detail', error, stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      debugPrint('STAGE studio detail response parsing failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  List<StageStudio> _parseRows(dynamic response, {required String rpcName}) {
    if (response is! List) {
      throw FormatException('$rpcName must return a list');
    }
    return response
        .map(
          (row) => StageStudio.fromJson(Map<String, dynamic>.from(row as Map)),
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

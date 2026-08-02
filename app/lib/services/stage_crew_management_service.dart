import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stage_crew_management.dart';

abstract interface class StageCrewManagementRepository {
  Future<StageCrewFormOptions> fetchFormOptions();
  Future<StageManagedCrew> fetchManagedCrew(String crewId);
  Future<List<StageManagedRecruitment>> fetchRecruitments(String crewId);
  Future<String> createCrew({
    required String name,
    required String bio,
    required String? activityFrequency,
    required List<String> genreIds,
    required String? areaId,
  });
  Future<void> updateCrew({
    required String crewId,
    required String name,
    required String bio,
    required String? activityFrequency,
    required List<String> genreIds,
    required String? areaId,
  });
  Future<String> createRecruitment({
    required String crewId,
    required String title,
    required String body,
    required List<String> genreIds,
    required String? areaId,
  });
  Future<void> updateRecruitment({
    required String postId,
    required String title,
    required String body,
    required List<String> genreIds,
    required String? areaId,
  });
  Future<void> setRecruitmentStatus(String postId, String status);
  Future<List<StageRecruitmentApplicant>> fetchApplicants(String postId);
  Future<StageApplicationDecision> decideApplication(
    String applicationId,
    String decision,
  );
}

class StageCrewManagementService implements StageCrewManagementRepository {
  StageCrewManagementService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<StageCrewFormOptions> fetchFormOptions() async =>
      StageCrewFormOptions.fromJson(
        await _singleRow('get_stage_crew_form_options_v1'),
      );

  @override
  Future<StageManagedCrew> fetchManagedCrew(String crewId) async =>
      StageManagedCrew.fromJson(
        await _singleRow(
          'get_stage_managed_crew_v1',
          params: {'p_crew_id': crewId},
        ),
      );

  @override
  Future<List<StageManagedRecruitment>> fetchRecruitments(
    String crewId,
  ) async => _rows(
    'get_stage_managed_recruitments_v1',
    params: {'p_crew_id': crewId},
    parser: StageManagedRecruitment.fromJson,
  );

  @override
  Future<String> createCrew({
    required String name,
    required String bio,
    required String? activityFrequency,
    required List<String> genreIds,
    required String? areaId,
  }) async => _scalar('create_stage_crew_v1', {
    'p_name': name,
    'p_bio': bio,
    'p_activity_frequency': activityFrequency,
    'p_genre_ids': genreIds,
    'p_area_id': areaId,
  });

  @override
  Future<void> updateCrew({
    required String crewId,
    required String name,
    required String bio,
    required String? activityFrequency,
    required List<String> genreIds,
    required String? areaId,
  }) async {
    await _scalar('update_stage_crew_v1', {
      'p_crew_id': crewId,
      'p_name': name,
      'p_bio': bio,
      'p_activity_frequency': activityFrequency,
      'p_genre_ids': genreIds,
      'p_area_id': areaId,
    });
  }

  @override
  Future<String> createRecruitment({
    required String crewId,
    required String title,
    required String body,
    required List<String> genreIds,
    required String? areaId,
  }) async => _scalar('create_stage_recruitment_v1', {
    'p_crew_id': crewId,
    'p_title': title,
    'p_body': body,
    'p_genre_ids': genreIds,
    'p_area_id': areaId,
  });

  @override
  Future<void> updateRecruitment({
    required String postId,
    required String title,
    required String body,
    required List<String> genreIds,
    required String? areaId,
  }) async {
    await _scalar('update_stage_recruitment_v1', {
      'p_post_id': postId,
      'p_title': title,
      'p_body': body,
      'p_genre_ids': genreIds,
      'p_area_id': areaId,
    });
  }

  @override
  Future<void> setRecruitmentStatus(String postId, String status) async {
    await _scalar('set_stage_recruitment_status_v1', {
      'p_post_id': postId,
      'p_status': status,
    });
  }

  @override
  Future<List<StageRecruitmentApplicant>> fetchApplicants(String postId) =>
      _rows(
        'get_stage_recruitment_applicants_v1',
        params: {'p_post_id': postId},
        parser: StageRecruitmentApplicant.fromJson,
      );

  @override
  Future<StageApplicationDecision> decideApplication(
    String applicationId,
    String decision,
  ) async => StageApplicationDecision.fromJson(
    await _singleRow(
      'decide_stage_recruitment_application_v1',
      params: {'p_application_id': applicationId, 'p_decision': decision},
    ),
  );

  Future<dynamic> _call(String rpc, [Map<String, dynamic>? params]) async {
    try {
      return await _client.rpc(rpc, params: params);
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'STAGE Crew RPC $rpc failed: message=${error.message}, '
        'code=${error.code}, details=${error.details}, hint=${error.hint}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      debugPrint('STAGE Crew RPC $rpc response failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _singleRow(
    String rpc, {
    Map<String, dynamic>? params,
  }) async {
    final response = await _call(rpc, params);
    if (response is! List || response.length != 1) {
      throw FormatException('$rpc must return exactly one row');
    }
    return Map<String, dynamic>.from(response.single as Map);
  }

  Future<List<T>> _rows<T>(
    String rpc, {
    Map<String, dynamic>? params,
    required T Function(Map<String, dynamic>) parser,
  }) async {
    final response = await _call(rpc, params);
    if (response is! List) throw FormatException('$rpc must return a list');
    return response
        .map((row) => parser(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  Future<String> _scalar(String rpc, Map<String, dynamic> params) async {
    final response = await _call(rpc, params);
    if (response is! String) throw FormatException('$rpc must return a UUID');
    return response;
  }
}

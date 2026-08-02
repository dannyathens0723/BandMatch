import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stage_user_profile.dart';

abstract interface class StageProfileRepository {
  Future<StageUserProfile> fetchMyProfile();

  Future<List<StageActivityArea>> fetchActivePublicAreas();

  Future<StageUserProfile> updateMyProfile({
    required String displayName,
    required String? bio,
    required String? experienceLevel,
    required String? activityFrequency,
    required String? areaId,
  });
}

class StageProfileService implements StageProfileRepository {
  factory StageProfileService({SupabaseClient? client}) {
    return StageProfileService._(client);
  }

  StageProfileService._(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  Future<StageUserProfile> fetchMyProfile() async {
    try {
      return _parseSingle(
        await _supabase.rpc('get_stage_my_profile_v1'),
        'get_stage_my_profile_v1',
      );
    } on PostgrestException catch (error, stackTrace) {
      _log('profile read', error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<StageActivityArea>> fetchActivePublicAreas() async {
    try {
      final response = await _supabase
          .from('areas')
          .select('id, name, sort_order')
          .eq('is_active', true)
          .inFilter('level', const ['prefecture', 'city'])
          .order('sort_order')
          .order('name');
      return (response as List<dynamic>)
          .map(
            (row) => StageActivityArea.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error, stackTrace) {
      _log('activity area read', error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<StageUserProfile> updateMyProfile({
    required String displayName,
    required String? bio,
    required String? experienceLevel,
    required String? activityFrequency,
    required String? areaId,
  }) async {
    try {
      return _parseSingle(
        await _supabase.rpc(
          'update_stage_my_profile_v1',
          params: {
            'p_display_name': displayName.trim(),
            'p_bio': bio?.trim(),
            'p_experience_level': experienceLevel,
            'p_activity_frequency': activityFrequency,
            'p_area_id': areaId,
          },
        ),
        'update_stage_my_profile_v1',
      );
    } on PostgrestException catch (error, stackTrace) {
      _log('profile update', error, stackTrace);
      rethrow;
    }
  }

  StageUserProfile _parseSingle(dynamic response, String rpcName) {
    if (response is! List || response.length != 1) {
      throw FormatException('$rpcName must return exactly one row');
    }
    return StageUserProfile.fromJson(
      Map<String, dynamic>.from(response.single as Map),
    );
  }

  void _log(String operation, PostgrestException error, StackTrace stackTrace) {
    debugPrint(
      'STAGE $operation failed: message=${error.message}, code=${error.code}, '
      'details=${error.details}, hint=${error.hint}',
    );
    debugPrintStack(stackTrace: stackTrace);
  }
}

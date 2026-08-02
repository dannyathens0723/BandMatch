import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stage_crew_activity.dart';

class StageCrewResourceUrlException implements Exception {
  const StageCrewResourceUrlException();

  @override
  String toString() => 'StageCrewResourceUrlException';
}

abstract interface class StageCrewActivityRepository {
  Future<StageCrewHome> fetchCrewHome(String crewId);
  Future<StageCrewActivitySnapshot> fetchCrewActivity(String crewId);
  Future<String> savePractice({
    required String crewId,
    String? practiceId,
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    String? areaId,
    String? locationName,
    String? meetingNote,
    String? description,
    DateTime? attendanceDeadline,
  });
  Future<void> setPracticeStatus({
    required String crewId,
    required String practiceId,
    required String status,
  });
  Future<void> respondAttendance({
    required String crewId,
    required String practiceId,
    required String response,
  });
  Future<String> createPoll({
    required String crewId,
    required String title,
    required List<({DateTime startsAt, DateTime endsAt})> options,
  });
  Future<void> respondPoll({
    required String crewId,
    required String pollId,
    required Map<String, String> responses,
  });
  Future<void> cancelPoll({required String crewId, required String pollId});
  Future<void> finalizePoll({
    required String crewId,
    required String pollId,
    required String optionId,
    bool createPractice,
  });
  Future<String> saveAnnouncement({
    required String crewId,
    String? announcementId,
    required String title,
    required String body,
    required String status,
  });
  Future<String> saveResource({
    required String crewId,
    String? resourceId,
    required String title,
    required String resourceType,
    required String externalUrl,
    String? description,
    required String status,
  });
  Future<String> setTargetEvent({
    required String crewId,
    required String eventId,
  });
}

class StageCrewActivityService implements StageCrewActivityRepository {
  StageCrewActivityService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<StageCrewHome> fetchCrewHome(String crewId) async =>
      StageCrewHome.fromJson(
        await _mapRpc('get_stage_crew_home_v1', {'p_crew_id': crewId}),
      );

  @override
  Future<StageCrewActivitySnapshot> fetchCrewActivity(String crewId) async =>
      StageCrewActivitySnapshot.fromJson(
        await _mapRpc('get_stage_crew_activity_v1', {'p_crew_id': crewId}),
      );

  @override
  Future<String> savePractice({
    required String crewId,
    String? practiceId,
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    String? areaId,
    String? locationName,
    String? meetingNote,
    String? description,
    DateTime? attendanceDeadline,
  }) => _stringRpc('upsert_stage_crew_practice_v1', {
    'p_crew_id': crewId,
    'p_practice_id': practiceId,
    'p_title': title,
    'p_starts_at': startsAt.toUtc().toIso8601String(),
    'p_ends_at': endsAt.toUtc().toIso8601String(),
    'p_area_id': areaId,
    'p_location_name': locationName,
    'p_meeting_note': meetingNote,
    'p_description': description,
    'p_attendance_deadline': attendanceDeadline?.toUtc().toIso8601String(),
  });

  @override
  Future<void> setPracticeStatus({
    required String crewId,
    required String practiceId,
    required String status,
  }) async {
    await _rpc('set_stage_crew_practice_status_v1', {
      'p_crew_id': crewId,
      'p_practice_id': practiceId,
      'p_status': status,
    });
  }

  @override
  Future<void> respondAttendance({
    required String crewId,
    required String practiceId,
    required String response,
  }) async {
    await _rpc('respond_stage_crew_attendance_v1', {
      'p_crew_id': crewId,
      'p_practice_id': practiceId,
      'p_response': response,
    });
  }

  @override
  Future<String> createPoll({
    required String crewId,
    required String title,
    required List<({DateTime startsAt, DateTime endsAt})> options,
  }) => _stringRpc('create_stage_crew_poll_v1', {
    'p_crew_id': crewId,
    'p_title': title,
    'p_options': options
        .map(
          (option) => {
            'starts_at': option.startsAt.toUtc().toIso8601String(),
            'ends_at': option.endsAt.toUtc().toIso8601String(),
          },
        )
        .toList(growable: false),
  });

  @override
  Future<void> respondPoll({
    required String crewId,
    required String pollId,
    required Map<String, String> responses,
  }) async {
    await _rpc('respond_stage_crew_poll_v1', {
      'p_crew_id': crewId,
      'p_poll_id': pollId,
      'p_responses': responses.entries
          .map((entry) => {'option_id': entry.key, 'response': entry.value})
          .toList(growable: false),
    });
  }

  @override
  Future<void> cancelPoll({
    required String crewId,
    required String pollId,
  }) async {
    await _rpc('cancel_stage_crew_poll_v1', {
      'p_crew_id': crewId,
      'p_poll_id': pollId,
    });
  }

  @override
  Future<void> finalizePoll({
    required String crewId,
    required String pollId,
    required String optionId,
    bool createPractice = true,
  }) async {
    await _rpc('finalize_stage_crew_poll_v1', {
      'p_crew_id': crewId,
      'p_poll_id': pollId,
      'p_option_id': optionId,
      'p_create_practice': createPractice,
    });
  }

  @override
  Future<String> saveAnnouncement({
    required String crewId,
    String? announcementId,
    required String title,
    required String body,
    required String status,
  }) => _stringRpc('upsert_stage_crew_announcement_v1', {
    'p_crew_id': crewId,
    'p_announcement_id': announcementId,
    'p_title': title,
    'p_body': body,
    'p_status': status,
  });

  @override
  Future<String> saveResource({
    required String crewId,
    String? resourceId,
    required String title,
    required String resourceType,
    required String externalUrl,
    String? description,
    required String status,
  }) async {
    try {
      return await _stringRpc('upsert_stage_crew_resource_v1', {
        'p_crew_id': crewId,
        'p_resource_id': resourceId,
        'p_title': title,
        'p_resource_type': resourceType,
        'p_external_url': externalUrl,
        'p_description': description,
        'p_status': status,
      });
    } on PostgrestException catch (error) {
      if (_isKnownResourceUrlFailure(error)) {
        throw const StageCrewResourceUrlException();
      }
      rethrow;
    }
  }

  @override
  Future<String> setTargetEvent({
    required String crewId,
    required String eventId,
  }) => _stringRpc('set_stage_crew_target_event_v1', {
    'p_crew_id': crewId,
    'p_event_id': eventId,
  });

  Future<Map<String, dynamic>> _mapRpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    final value = await _rpc(name, params);
    if (value is! Map) throw FormatException('$name must return an object');
    return Map<String, dynamic>.from(value);
  }

  Future<String> _stringRpc(String name, Map<String, dynamic> params) async {
    final value = await _rpc(name, params);
    if (value is! String) throw FormatException('$name must return a UUID');
    return value;
  }

  Future<dynamic> _rpc(String name, Map<String, dynamic> params) async {
    try {
      return await _client.rpc(name, params: params);
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'STAGE Crew activity RPC $name failed: message=${error.message}, '
        'code=${error.code}, details=${error.details}, hint=${error.hint}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } on Object catch (error, stackTrace) {
      debugPrint('STAGE Crew activity RPC $name parsing failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  bool _isKnownResourceUrlFailure(PostgrestException error) {
    final diagnostic = [
      error.message,
      error.details,
      error.hint,
    ].whereType<Object>().join(' ').toLowerCase();
    return (error.code == '22023' &&
            error.message == 'invalid Crew resource') ||
        (error.code == '23514' &&
            diagnostic.contains('stage_crew_resources') &&
            diagnostic.contains('external_url'));
  }
}

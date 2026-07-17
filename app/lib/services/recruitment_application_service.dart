import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/recruitment_application.dart';

class RecruitmentApplicationService {
  RecruitmentApplicationService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<RecruitmentApplicationState> fetchMyApplicationState(
    String postId,
  ) async {
    try {
      final response = await _client.rpc(
        'get_my_recruitment_application_state',
        params: {'p_post_id': postId},
      );
      final row = _firstRow(response);
      if (row == null) {
        debugPrint(
          'Recruitment application state response was empty or unexpected: '
          '${response.runtimeType} $response',
        );
        return const RecruitmentApplicationState(
          state: 'none',
          applicationId: null,
        );
      }
      return RecruitmentApplicationState.fromJson(row);
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestException(
        'Recruitment application state load failed',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<RecruitmentApplicationState> applyToPost({
    required String postId,
    required String message,
  }) async {
    dynamic response;
    try {
      response = await _client.rpc(
        'apply_to_recruitment_post',
        params: {'p_post_id': postId, 'p_message': message},
      );
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestException(
        'Recruitment application submit failed',
        error,
        stackTrace,
      );
      rethrow;
    }

    final row = _firstRow(response);
    if (row == null) {
      debugPrint(
        'Recruitment application submit succeeded but returned an unexpected '
        'response shape: ${response.runtimeType} $response',
      );
      return const RecruitmentApplicationState(
        state: 'pending',
        applicationId: null,
      );
    }

    return RecruitmentApplicationState(
      state: row['status'] as String? ?? 'pending',
      applicationId: row['application_id'] as String?,
    );
  }

  Future<List<RecruitmentApplication>> fetchGroupApplications(
    String groupId,
  ) async {
    try {
      final rows = await _client.rpc(
        'get_my_group_recruitment_applications',
        params: {'p_group_id': groupId},
      );
      return (rows as List<dynamic>)
          .map(
            (row) =>
                RecruitmentApplication.fromJson(row as Map<String, dynamic>),
          )
          .toList(growable: false);
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestException(
        'Recruitment applications load failed',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<void> acceptApplication(String applicationId) async {
    try {
      await _client.rpc(
        'accept_recruitment_application',
        params: {'p_application_id': applicationId},
      );
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestException(
        'Recruitment application accept failed',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<void> rejectApplication(String applicationId) async {
    try {
      await _client.rpc(
        'reject_recruitment_application',
        params: {'p_application_id': applicationId},
      );
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestException(
        'Recruitment application reject failed',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  void _logPostgrestException(
    String label,
    PostgrestException error,
    StackTrace stackTrace,
  ) {
    debugPrint(
      '$label: message=${error.message}, code=${error.code}, '
      'details=${error.details}, hint=${error.hint}',
    );
    debugPrintStack(stackTrace: stackTrace);
  }

  Map<String, dynamic>? _firstRow(dynamic response) {
    if (response is Map<String, dynamic>) {
      return response;
    }
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    if (response is List && response.isNotEmpty) {
      final first = response.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }
    return null;
  }
}

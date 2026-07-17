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
      final rows = await _client.rpc(
        'get_my_recruitment_application_state',
        params: {'p_post_id': postId},
      );
      final list = rows as List<dynamic>;
      if (list.isEmpty) {
        return const RecruitmentApplicationState(
          state: 'none',
          applicationId: null,
        );
      }
      return RecruitmentApplicationState.fromJson(
        list.first as Map<String, dynamic>,
      );
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
    try {
      final rows = await _client.rpc(
        'apply_to_recruitment_post',
        params: {'p_post_id': postId, 'p_message': message},
      );
      final list = rows as List<dynamic>;
      if (list.isEmpty) {
        throw StateError('empty application response');
      }
      final row = list.first as Map<String, dynamic>;
      return RecruitmentApplicationState(
        state: row['status'] as String? ?? 'pending',
        applicationId: row['application_id'] as String?,
      );
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestException(
        'Recruitment application submit failed',
        error,
        stackTrace,
      );
      rethrow;
    }
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
}

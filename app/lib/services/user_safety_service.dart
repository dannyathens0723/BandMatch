import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_safety_state.dart';

class UserSafetyService {
  UserSafetyService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<UserSafetyState> fetchState(String targetUserId) async {
    try {
      final result = await _client.rpc(
        'get_user_safety_state',
        params: {'p_target_user_id': targetUserId},
      );
      final row = _firstRow(result);
      if (row == null) {
        debugPrint(
          'User safety state response was empty or unexpected: '
          '${result.runtimeType} $result',
        );
        throw StateError('安全状態を確認できませんでした。');
      }
      return UserSafetyState.fromValue(row['state'] as String?);
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestException(
        'User safety state query failed',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<void> blockUser(String targetUserId) async {
    try {
      await _client.rpc(
        'block_user',
        params: {'p_blocked_user_id': targetUserId},
      );
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestException('Block user failed', error, stackTrace);
      rethrow;
    }
  }

  Future<void> unblockUser(String targetUserId) async {
    try {
      await _client.rpc(
        'unblock_user',
        params: {'p_blocked_user_id': targetUserId},
      );
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestException('Unblock user failed', error, stackTrace);
      rethrow;
    }
  }

  Future<void> reportUser({
    required String targetUserId,
    required String reason,
    String? note,
  }) async {
    try {
      await _client.rpc(
        'report_user',
        params: {
          'p_reported_user_id': targetUserId,
          'p_reason': reason,
          'p_note': note?.trim(),
        },
      );
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestException('Report user failed', error, stackTrace);
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
    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    return null;
  }
}

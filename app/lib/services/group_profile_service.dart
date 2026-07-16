import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/my_group_profile.dart';

class GroupProfileService {
  GroupProfileService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<MyGroupProfile>> fetchMyGroups() async {
    try {
      final rows = await _client.rpc('get_my_group_profiles');
      return (rows as List<dynamic>)
          .map((row) => MyGroupProfile.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestException('My group list load failed', error, stackTrace);
      rethrow;
    }
  }

  Future<String> createGroup(GroupEditData data) async {
    try {
      final id = await _client.rpc(
        'create_my_group_profile',
        params: data.toCreateRpcParams(),
      );
      return id as String;
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestException('Group create failed', error, stackTrace);
      rethrow;
    }
  }

  Future<String> updateGroup(String groupId, GroupEditData data) async {
    try {
      final id = await _client.rpc(
        'update_my_group_profile',
        params: data.toUpdateRpcParams(groupId),
      );
      return id as String;
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestException('Group update failed', error, stackTrace);
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

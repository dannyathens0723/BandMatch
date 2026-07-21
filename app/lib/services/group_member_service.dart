import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/group_member.dart';

class GroupMemberService {
  GroupMemberService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<GroupMember>> fetchGroupMembers(String groupId) async {
    try {
      final rows = await _client.rpc(
        'get_group_members',
        params: {'p_group_id': groupId},
      );
      return (rows as List<dynamic>)
          .map((row) => GroupMember.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'Group member list load failed: message=${error.message}, '
        'code=${error.code}, details=${error.details}, hint=${error.hint}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> leaveGroup(String groupId) async {
    try {
      await _client.rpc('leave_group', params: {'p_group_id': groupId});
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'Group leave failed: message=${error.message}, '
        'code=${error.code}, details=${error.details}, hint=${error.hint}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> removeGroupMember({
    required String groupId,
    required String memberUserId,
  }) async {
    try {
      await _client.rpc(
        'remove_group_member',
        params: {'p_group_id': groupId, 'p_member_user_id': memberUserId},
      );
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'Group member removal failed: message=${error.message}, '
        'code=${error.code}, details=${error.details}, hint=${error.hint}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}

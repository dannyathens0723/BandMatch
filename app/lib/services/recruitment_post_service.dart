import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/recruitment_post.dart';

class RecruitmentPostService {
  RecruitmentPostService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<RecruitmentPost>> fetchMyGroupPosts(String groupId) async {
    try {
      final rows = await _client.rpc(
        'get_my_group_recruitment_posts',
        params: {'p_group_id': groupId},
      );
      return (rows as List<dynamic>)
          .map((row) => RecruitmentPost.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestException(
        'Recruitment post list load failed',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<String> createPost(
    String groupId,
    RecruitmentPostEditData data,
  ) async {
    try {
      final id = await _client.rpc(
        'create_my_group_recruitment_post',
        params: data.toCreateRpcParams(groupId),
      );
      return id as String;
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestException(
        'Recruitment post create failed',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<String> updatePost(String postId, RecruitmentPostEditData data) async {
    try {
      final id = await _client.rpc(
        'update_my_group_recruitment_post',
        params: data.toUpdateRpcParams(postId),
      );
      return id as String;
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestException(
        'Recruitment post update failed',
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

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/recruitment_post.dart';

class PublicRecruitmentPostService {
  PublicRecruitmentPostService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<PublicRecruitmentPost>> fetchOpenPosts() async {
    try {
      final rows = await _client.rpc('get_public_recruitment_posts');
      return (rows as List<dynamic>)
          .map(
            (row) =>
                PublicRecruitmentPost.fromJson(row as Map<String, dynamic>),
          )
          .toList(growable: false);
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'Public recruitment posts load failed: '
        'message=${error.message}, code=${error.code}, '
        'details=${error.details}, hint=${error.hint}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}

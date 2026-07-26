import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/blocked_user.dart';

class BlockedUserService {
  BlockedUserService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<BlockedUser>> fetchMyBlockedUsers() async {
    try {
      final response = await _client.rpc('get_my_blocked_users');
      final rows = switch (response) {
        List value => value,
        Map value => [value],
        _ => throw StateError('ブロック一覧を読み込めませんでした。'),
      };
      return rows
          .whereType<Map>()
          .map((row) => BlockedUser.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'Blocked users query failed: message=${error.message}, '
        'code=${error.code}, details=${error.details}, hint=${error.hint}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}

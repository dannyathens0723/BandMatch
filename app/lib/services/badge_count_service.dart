import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/badge_counts.dart';

class BadgeCountService {
  BadgeCountService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<BadgeCounts> fetchMyBadgeCounts() async {
    try {
      final response = await _client.rpc('get_my_badge_counts');
      final row = _firstRow(response);
      if (row == null) {
        throw StateError('バッジ件数を読み込めませんでした。');
      }
      return BadgeCounts.fromJson(row);
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'Badge count query failed: message=${error.message}, '
        'code=${error.code}, details=${error.details}, hint=${error.hint}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
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

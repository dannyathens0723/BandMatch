import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/my_page_profile.dart';

class MyPageService {
  MyPageService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<MyPageProfile> fetchMyPageProfile() async {
    try {
      final rows = await _client.rpc('get_my_page_profile');
      final list = rows as List<dynamic>;
      if (list.isEmpty) {
        throw StateError('My Page profile was not found.');
      }
      return MyPageProfile.fromJson(list.first as Map<String, dynamic>);
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'My Page load failed: message=${error.message}, code=${error.code}, '
        'details=${error.details}, hint=${error.hint}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}

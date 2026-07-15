import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/member_search_filters.dart';
import '../models/member_profile.dart';

class MemberSearchService {
  MemberSearchService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<MemberProfile>> fetchMembers({
    MemberSearchFilters filters = const MemberSearchFilters(),
  }) async {
    try {
      final rows = filters.hasActiveFilters
          ? await _client.rpc(
              'search_member_profiles',
              params: filters.toRpcParams(),
            )
          : await _client
                .from('member_search_profiles')
                .select()
                .order('display_name')
                .limit(60);

      return (rows as List<dynamic>)
          .map((row) => MemberProfile.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestException('Failed to fetch members', error, stackTrace);
      rethrow;
    }
  }

  Future<MemberProfile?> fetchMemberDetail(String memberId) async {
    final row = await _client
        .from('member_public_profile_details')
        .select()
        .eq('id', memberId)
        .maybeSingle();

    return row == null ? null : MemberProfile.fromJson(row);
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

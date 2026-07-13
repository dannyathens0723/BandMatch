import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/member_profile.dart';

class MemberSearchService {
  MemberSearchService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<MemberProfile>> fetchMembers() async {
    final rows = await _client
        .from('member_search_profiles')
        .select()
        .order('display_name')
        .limit(60);

    return (rows as List<dynamic>)
        .map((row) => MemberProfile.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<MemberProfile?> fetchMemberDetail(String memberId) async {
    final row = await _client
        .from('member_public_profile_details')
        .select()
        .eq('id', memberId)
        .maybeSingle();

    return row == null ? null : MemberProfile.fromJson(row);
  }
}

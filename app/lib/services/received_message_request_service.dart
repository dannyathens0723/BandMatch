import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/received_message_request.dart';
import 'profile_service.dart';

class ReceivedMessageRequestService {
  ReceivedMessageRequestService({
    SupabaseClient? client,
    ProfileService? profileService,
  }) : _client = client ?? Supabase.instance.client,
       _profileService = profileService ?? ProfileService(client: client);

  final SupabaseClient _client;
  final ProfileService _profileService;

  Future<List<ReceivedMessageRequest>> fetchReceivedRequests() async {
    final rows = await _client
        .from('received_message_requests_view')
        .select()
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ReceivedMessageRequest.fromJson)
        .toList(growable: false);
  }

  Future<int> fetchPendingReceivedRequestCount() async {
    final rows = await _client
        .from('received_message_requests_view')
        .select('id')
        .eq('status', 'pending');
    return (rows as List<dynamic>).length;
  }

  /// The database function verifies the recipient and atomically creates the
  /// message room and participants with the accepted request.
  Future<void> acceptRequest(String requestId) async {
    await _client.rpc(
      'accept_message_request',
      params: {'p_request_id': requestId},
    );
  }

  Future<void> rejectRequest(String requestId) async {
    final profileId = await _currentProfileId();
    final updated = await _client
        .from('message_requests')
        .update({
          'status': 'rejected',
          'responded_by': profileId,
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', requestId)
        .eq('status', 'pending')
        .select('id')
        .maybeSingle();

    if (updated == null) {
      throw StateError('このリクエストはすでに処理されています。');
    }
  }

  Future<String> _currentProfileId() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw StateError('サインインが必要です。');

    final profile = await _profileService.fetchCurrentProfile(authUser.id);
    if (profile == null) throw StateError('プロフィールが見つかりません。');
    return profile.id;
  }
}

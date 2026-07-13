import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_service.dart';

class MessageRequestAlreadyPending implements Exception {
  const MessageRequestAlreadyPending();
}

class MessageRequestService {
  MessageRequestService({
    SupabaseClient? client,
    ProfileService? profileService,
  }) : _client = client ?? Supabase.instance.client,
       _profileService = profileService ?? ProfileService(client: client);

  final SupabaseClient _client;
  final ProfileService _profileService;

  Future<bool> hasPendingRequest(String receiverUserId) async {
    final senderUserId = await _currentProfileId();
    if (senderUserId == receiverUserId) return false;

    final row = await _client
        .from('message_requests')
        .select('id')
        .eq('sender_user_id', senderUserId)
        .eq('receiver_user_id', receiverUserId)
        .eq('status', 'pending')
        .isFilter('sender_group_id', null)
        .isFilter('receiver_group_id', null)
        .maybeSingle();

    return row != null;
  }

  Future<void> sendRequest({
    required String receiverUserId,
    required String message,
  }) async {
    final senderUserId = await _currentProfileId();
    final note = message.trim();

    if (senderUserId == receiverUserId) {
      throw ArgumentError('自分自身にはメッセージリクエストを送信できません。');
    }
    if (note.isEmpty || note.length > 300) {
      throw ArgumentError('メッセージは1〜300文字で入力してください。');
    }

    try {
      await _client.from('message_requests').insert({
        'sender_user_id': senderUserId,
        'receiver_user_id': receiverUserId,
        'status': 'pending',
        'note': note,
      });
    } on PostgrestException catch (error) {
      if (error.code == '23505') throw const MessageRequestAlreadyPending();
      rethrow;
    }
  }

  Future<String> _currentProfileId() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw StateError('サインインが必要です。');

    final profile = await _profileService.fetchCurrentProfile(authUser.id);
    if (profile == null) throw StateError('プロフィールを設定してください。');
    return profile.id;
  }
}

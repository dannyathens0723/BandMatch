import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_room_message.dart';
import 'profile_service.dart';

class ChatRoomMessageService {
  ChatRoomMessageService({
    SupabaseClient? client,
    ProfileService? profileService,
  }) : _client = client ?? Supabase.instance.client,
       _profileService = profileService ?? ProfileService(client: client);

  final SupabaseClient _client;
  final ProfileService _profileService;

  Future<List<ChatRoomMessage>> fetchMessages(String roomId) async {
    try {
      final rows = await _client.rpc(
        'get_room_messages',
        params: {'p_room_id': roomId},
      );
      if (rows is! List) {
        throw StateError('メッセージを読み込めませんでした。');
      }
      return rows
          .whereType<Map>()
          .map(
            (row) => ChatRoomMessage.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'Chat message query failed: '
        'message=${error.message}, code=${error.code}, '
        'details=${error.details}, hint=${error.hint}\n$stackTrace',
      );
      rethrow;
    }
  }

  Future<String> fetchCurrentProfileId() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw StateError('サインインが必要です。');

    final profile = await _profileService.fetchCurrentProfile(authUser.id);
    if (profile == null) throw StateError('プロフィールが見つかりません。');
    return profile.id;
  }
}

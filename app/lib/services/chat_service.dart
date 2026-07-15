import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';
import '../models/chat_room.dart';
import 'profile_service.dart';

class ChatService {
  ChatService({SupabaseClient? client, ProfileService? profileService})
    : _client = client ?? Supabase.instance.client,
      _profileService = profileService ?? ProfileService(client: client);

  final SupabaseClient _client;
  final ProfileService _profileService;

  Future<List<ChatRoom>> fetchRooms() async {
    final rows = await _client
        .from('my_chat_rooms')
        .select()
        .order('last_message_at', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ChatRoom.fromJson)
        .toList(growable: false);
  }

  Future<List<ChatMessage>> fetchMessages(String roomId) async {
    final rows = await _client.rpc(
      'get_room_messages',
      params: {'p_room_id': roomId},
    );
    if (rows is! List) throw StateError('メッセージを読み込めませんでした。');
    return rows
        .whereType<Map>()
        .map((row) => ChatMessage.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<ChatMessage> sendMessage({
    required String roomId,
    required String body,
    required String senderUserId,
  }) async {
    final message = body.trim();
    if (message.isEmpty || message.length > 1000) {
      throw ArgumentError('メッセージは1〜1000文字で入力してください。');
    }
    // `messages_insert_participant` already enforces room membership and the
    // sender ID in RLS. This keeps the write tightly scoped without relying on
    // a custom RPC response.
    final result = await _client
        .from('messages')
        .insert({
          'room_id': roomId,
          'sender_user_id': senderUserId,
          'message_type': 'text',
          'body': message,
        })
        .select('id, body, sender_user_id, created_at')
        .single();
    return ChatMessage.fromJson(Map<String, dynamic>.from(result));
  }

  Future<String> currentProfileId() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('サインインが必要です。');
    final profile = await _profileService.fetchCurrentProfile(user.id);
    if (profile == null) throw StateError('プロフィールが見つかりません。');
    return profile.id;
  }
}

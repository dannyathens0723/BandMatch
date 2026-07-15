import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_room_summary.dart';

class ChatRoomService {
  ChatRoomService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<ChatRoomSummary>> fetchMyChatRooms() async {
    try {
      final rows = await _client
          .from('my_chat_rooms')
          .select()
          .order('last_message_at', ascending: false)
          .order('created_at', ascending: false);

      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ChatRoomSummary.fromJson)
          .toList(growable: false);
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'Chat room list query failed: '
        'message=${error.message}, code=${error.code}, '
        'details=${error.details}, hint=${error.hint}\n$stackTrace',
      );
      rethrow;
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_room_message.dart';

class ChatRoomMessageService {
  ChatRoomMessageService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

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

  Future<ChatRoomMessage> sendMessage({
    required String roomId,
    required String body,
  }) async {
    final trimmedBody = body.trim();
    final hasSession = _client.auth.currentSession != null;
    debugPrint(
      'Chat message send requested: roomId=$roomId, '
      'trimmedBodyLength=${trimmedBody.length}, hasSession=$hasSession',
    );

    try {
      final rows = await _client.rpc(
        'send_room_message',
        params: {'p_room_id': roomId, 'p_body': trimmedBody},
      );
      if (rows is! List || rows.length != 1 || rows.first is! Map) {
        throw StateError('メッセージを送信できませんでした。');
      }
      return ChatRoomMessage.fromJson(
        Map<String, dynamic>.from(rows.first as Map),
      );
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'Chat message send failed: '
        'message=${error.message}, code=${error.code}, '
        'details=${error.details}, hint=${error.hint}\n$stackTrace',
      );
      rethrow;
    } catch (error, stackTrace) {
      debugPrint(
        'Chat message send failed (non-Postgrest): '
        'roomId=$roomId, trimmedBodyLength=${trimmedBody.length}, '
        'hasSession=$hasSession, error=$error\n$stackTrace',
      );
      rethrow;
    }
  }

  Future<String> fetchCurrentProfileId() async {
    final profileId = await _client.rpc('current_user_id');
    if (profileId is! String || profileId.isEmpty) {
      throw StateError('プロフィールが見つかりません。');
    }
    return profileId;
  }
}

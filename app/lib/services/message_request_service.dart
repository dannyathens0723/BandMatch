import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/member_relationship.dart';

class MessageRequestRelationshipExists implements Exception {
  const MessageRequestRelationshipExists();
}

class MessageRequestService {
  MessageRequestService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<MemberRelationship> fetchRelationship(String targetUserId) async {
    final result = await _client.rpc(
      'get_member_relationship_state',
      params: {'p_target_user_id': targetUserId},
    );
    if (result is! List || result.isEmpty || result.first is! Map) {
      throw StateError('メンバーとの関係を確認できませんでした。');
    }
    return MemberRelationship.fromJson(
      Map<String, dynamic>.from(result.first as Map),
    );
  }

  Future<void> sendRequest({
    required String receiverUserId,
    required String message,
  }) async {
    final note = message.trim();
    if (note.isEmpty || note.length > 300) {
      throw ArgumentError('メッセージは1〜300文字で入力してください。');
    }

    try {
      await _client.rpc(
        'send_message_request',
        params: {'p_target_user_id': receiverUserId, 'p_note': note},
      );
    } on PostgrestException catch (error) {
      if (error.code == '23505') throw const MessageRequestRelationshipExists();
      rethrow;
    }
  }
}

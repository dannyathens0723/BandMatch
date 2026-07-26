import 'package:flutter_test/flutter_test.dart';

import 'package:app/models/chat_room_summary.dart';

void main() {
  test('ChatRoomSummary parses unread count and keeps missing count safe', () {
    final baseJson = <String, dynamic>{
      'room_id': 'room-id',
      'other_user_id': 'other-user-id',
      'display_name': 'テストユーザー',
      'created_at': '2026-07-26T00:00:00Z',
    };

    final unreadRoom = ChatRoomSummary.fromJson({
      ...baseJson,
      'unread_count': 3,
    });
    final backwardCompatibleRoom = ChatRoomSummary.fromJson(baseJson);

    expect(unreadRoom.unreadCount, 3);
    expect(backwardCompatibleRoom.unreadCount, 0);
    expect(unreadRoom.copyWith(unreadCount: 0).unreadCount, 0);
  });
}

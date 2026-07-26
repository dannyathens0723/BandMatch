class ChatRoomSummary {
  const ChatRoomSummary({
    required this.roomId,
    required this.otherUserId,
    required this.displayName,
    required this.createdAt,
    this.avatarUrl,
    this.experienceLevel,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  final String roomId;
  final String otherUserId;
  final String displayName;
  final String? avatarUrl;
  final String? experienceLevel;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final int unreadCount;

  factory ChatRoomSummary.fromJson(Map<String, dynamic> json) {
    return ChatRoomSummary(
      roomId: json['room_id'] as String,
      otherUserId: json['other_user_id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      experienceLevel: json['experience_level'] as String?,
      lastMessageAt: json['last_message_at'] == null
          ? null
          : DateTime.parse(json['last_message_at'] as String).toLocal(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      unreadCount: _nonNegativeInt(json['unread_count']),
    );
  }

  ChatRoomSummary copyWith({int? unreadCount}) {
    return ChatRoomSummary(
      roomId: roomId,
      otherUserId: otherUserId,
      displayName: displayName,
      createdAt: createdAt,
      avatarUrl: avatarUrl,
      experienceLevel: experienceLevel,
      lastMessageAt: lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  static int _nonNegativeInt(dynamic value) {
    final parsed = switch (value) {
      int count => count,
      num count => count.toInt(),
      String count => int.tryParse(count) ?? 0,
      _ => 0,
    };
    return parsed < 0 ? 0 : parsed;
  }
}

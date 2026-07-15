class ChatRoomSummary {
  const ChatRoomSummary({
    required this.roomId,
    required this.otherUserId,
    required this.displayName,
    required this.createdAt,
    this.avatarUrl,
    this.experienceLevel,
    this.lastMessageAt,
  });

  final String roomId;
  final String otherUserId;
  final String displayName;
  final String? avatarUrl;
  final String? experienceLevel;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

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
    );
  }
}

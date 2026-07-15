class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.otherDisplayName,
    required this.createdAt,
    this.otherAvatarUrl,
    this.otherExperienceLevel,
    this.lastMessageBody,
    this.lastMessageCreatedAt,
  });

  final String id;
  final String otherDisplayName;
  final DateTime createdAt;
  final String? otherAvatarUrl;
  final String? otherExperienceLevel;
  final String? lastMessageBody;
  final DateTime? lastMessageCreatedAt;

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as String,
      otherDisplayName: json['other_display_name'] as String,
      otherAvatarUrl: json['other_avatar_url'] as String?,
      otherExperienceLevel: json['other_experience_level'] as String?,
      lastMessageBody: json['last_message_body'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      lastMessageCreatedAt: json['last_message_created_at'] == null
          ? null
          : DateTime.parse(json['last_message_created_at'] as String).toLocal(),
    );
  }
}

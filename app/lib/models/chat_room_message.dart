class ChatRoomMessage {
  const ChatRoomMessage({
    required this.messageId,
    required this.roomId,
    required this.senderUserId,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final String messageId;
  final String roomId;
  final String senderUserId;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ChatRoomMessage.fromJson(Map<String, dynamic> json) {
    return ChatRoomMessage(
      messageId: json['message_id'] as String,
      roomId: json['room_id'] as String,
      senderUserId: json['sender_user_id'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}

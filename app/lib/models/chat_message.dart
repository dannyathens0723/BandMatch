class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.senderUserId,
    required this.createdAt,
    this.isPending = false,
  });

  final String id;
  final String body;
  final String senderUserId;
  final DateTime createdAt;
  final bool isPending;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      body: json['body'] as String,
      senderUserId: json['sender_user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

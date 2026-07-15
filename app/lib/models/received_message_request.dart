class ReceivedMessageRequest {
  const ReceivedMessageRequest({
    required this.id,
    required this.senderUserId,
    required this.senderDisplayName,
    required this.status,
    required this.createdAt,
    required this.partNames,
    required this.genreNames,
    this.senderAvatarUrl,
    this.senderExperienceLevel,
    this.note,
    this.respondedAt,
    this.roomId,
  });

  final String id;
  final String senderUserId;
  final String senderDisplayName;
  final String status;
  final DateTime createdAt;
  final List<String> partNames;
  final List<String> genreNames;
  final String? senderAvatarUrl;
  final String? senderExperienceLevel;
  final String? note;
  final DateTime? respondedAt;
  final String? roomId;

  bool get isPending => status == 'pending' && roomId == null;

  factory ReceivedMessageRequest.fromJson(Map<String, dynamic> json) {
    return ReceivedMessageRequest(
      id: json['id'] as String,
      senderUserId: json['sender_user_id'] as String,
      senderDisplayName: json['display_name'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      respondedAt: json['responded_at'] == null
          ? null
          : DateTime.parse(json['responded_at'] as String).toLocal(),
      senderAvatarUrl: json['avatar_url'] as String?,
      senderExperienceLevel: json['experience_level'] as String?,
      note: json['note'] as String?,
      roomId: json['room_id'] as String?,
      partNames: _stringList(json['part_names']),
      genreNames: _stringList(json['genre_names']),
    );
  }

  static List<String> _stringList(dynamic value) {
    return (value as List<dynamic>? ?? const []).whereType<String>().toList(
      growable: false,
    );
  }
}

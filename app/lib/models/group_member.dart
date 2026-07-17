class GroupMember {
  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.experienceLevel,
    required this.partNames,
    required this.genreNames,
    required this.role,
    required this.joinedAt,
    required this.createdAt,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? experienceLevel;
  final List<String> partNames;
  final List<String> genreNames;
  final String role;
  final DateTime joinedAt;
  final DateTime createdAt;

  bool get isAdmin => role == 'admin';

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      experienceLevel: json['experience_level'] as String?,
      partNames: _stringList(json['part_names']),
      genreNames: _stringList(json['genre_names']),
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String).toLocal(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

List<String> _stringList(dynamic value) {
  return (value as List<dynamic>? ?? const [])
      .map((item) => item.toString())
      .toList(growable: false);
}

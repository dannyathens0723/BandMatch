class BlockedUser {
  const BlockedUser({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.experienceLevel,
    required this.partNames,
    required this.genreNames,
    required this.blockedAt,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? experienceLevel;
  final List<String> partNames;
  final List<String> genreNames;
  final DateTime blockedAt;

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      userId: json['blocked_user_id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      experienceLevel: json['experience_level'] as String?,
      partNames: _stringList(json['part_names']),
      genreNames: _stringList(json['genre_names']),
      blockedAt: DateTime.parse(json['blocked_at'] as String).toLocal(),
    );
  }

  static List<String> _stringList(dynamic value) {
    return (value as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false);
  }
}

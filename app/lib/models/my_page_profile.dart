class MyPageProfile {
  const MyPageProfile({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
    required this.experienceLevel,
    required this.partNames,
    required this.genreNames,
    required this.areaNames,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? experienceLevel;
  final List<String> partNames;
  final List<String> genreNames;
  final List<String> areaNames;

  factory MyPageProfile.fromJson(Map<String, dynamic> json) {
    return MyPageProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      experienceLevel: json['experience_level'] as String?,
      partNames: _stringList(json['part_names']),
      genreNames: _stringList(json['genre_names']),
      areaNames: _stringList(json['area_names']),
    );
  }

  static List<String> _stringList(dynamic value) {
    return (value as List<dynamic>? ?? const []).whereType<String>().toList(
      growable: false,
    );
  }
}

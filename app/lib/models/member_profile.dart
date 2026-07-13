class MemberProfile {
  const MemberProfile({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
    required this.age,
    required this.gender,
    required this.experienceLevel,
    required this.bio,
    required this.purposes,
    required this.partNames,
    required this.genreNames,
    required this.areaNames,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final int? age;
  final String? gender;
  final String? experienceLevel;
  final String? bio;
  final List<String> purposes;
  final List<String> partNames;
  final List<String> genreNames;
  final List<String> areaNames;

  factory MemberProfile.fromJson(Map<String, dynamic> json) {
    return MemberProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      experienceLevel: json['experience_level'] as String?,
      bio: json['bio'] as String?,
      purposes: _stringList(json['purposes']),
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

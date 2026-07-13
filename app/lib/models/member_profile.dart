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
    this.favoriteArtists,
    this.gear,
    this.activityFrequency,
    this.activityDays,
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
  final String? favoriteArtists;
  final String? gear;
  final String? activityFrequency;
  final String? activityDays;

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
      favoriteArtists: json['favorite_artists'] as String?,
      gear: json['gear'] as String?,
      activityFrequency: json['activity_frequency'] as String?,
      activityDays: json['activity_days'] as String?,
    );
  }

  static List<String> _stringList(dynamic value) {
    return (value as List<dynamic>? ?? const []).whereType<String>().toList(
      growable: false,
    );
  }
}

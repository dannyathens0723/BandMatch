class StageUserProfile {
  const StageUserProfile({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.experienceLevel,
    required this.activityFrequency,
    required this.areaId,
    required this.areaName,
    required this.danceGenreNames,
    required this.performanceRoleNames,
    required this.primaryPerformanceRoleName,
    required this.hasSavedTaxonomy,
    required this.profileCompleteness,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String? experienceLevel;
  final String? activityFrequency;
  final String? areaId;
  final String? areaName;
  final List<String> danceGenreNames;
  final List<String> performanceRoleNames;
  final String? primaryPerformanceRoleName;
  final bool hasSavedTaxonomy;
  final int profileCompleteness;

  factory StageUserProfile.fromJson(Map<String, dynamic> json) {
    return StageUserProfile(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      experienceLevel: json['experience_level'] as String?,
      activityFrequency: json['activity_frequency'] as String?,
      areaId: json['area_id'] as String?,
      areaName: json['area_name'] as String?,
      danceGenreNames: _strings(json['dance_genre_names']),
      performanceRoleNames: _strings(json['performance_role_names']),
      primaryPerformanceRoleName:
          json['primary_performance_role_name'] as String?,
      hasSavedTaxonomy: json['has_saved_taxonomy'] as bool,
      profileCompleteness: _integer(json['profile_completeness']),
    );
  }
}

class StageActivityArea {
  const StageActivityArea({required this.id, required this.name});

  final String id;
  final String name;

  factory StageActivityArea.fromJson(Map<String, dynamic> json) {
    return StageActivityArea(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

int _integer(dynamic value) =>
    value is num ? value.toInt() : int.parse(value.toString());

List<String> _strings(dynamic value) =>
    (value as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString())
        .toList(growable: false);

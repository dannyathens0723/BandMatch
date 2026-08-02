class StageCrewRecruitment {
  const StageCrewRecruitment({
    required this.postId,
    required this.crewId,
    required this.crewName,
    required this.crewAvatarUrl,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    required this.danceGenreNames,
    required this.areaNames,
  });

  final String postId;
  final String crewId;
  final String crewName;
  final String? crewAvatarUrl;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> danceGenreNames;
  final List<String> areaNames;

  factory StageCrewRecruitment.fromJson(Map<String, dynamic> json) {
    return StageCrewRecruitment(
      postId: json['post_id'] as String,
      crewId: json['crew_id'] as String,
      crewName: json['crew_name'] as String,
      crewAvatarUrl: json['crew_avatar_url'] as String?,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      danceGenreNames: _stringList(json['dance_genre_names']),
      areaNames: _stringList(json['area_names']),
    );
  }

  bool matches(String keyword, String? genre) {
    final normalizedKeyword = keyword.trim().toLowerCase();
    final matchesKeyword = normalizedKeyword.isEmpty ||
        crewName.toLowerCase().contains(normalizedKeyword) ||
        title.toLowerCase().contains(normalizedKeyword) ||
        body.toLowerCase().contains(normalizedKeyword) ||
        danceGenreNames.any(
          (name) => name.toLowerCase().contains(normalizedKeyword),
        ) ||
        areaNames.any(
          (name) => name.toLowerCase().contains(normalizedKeyword),
        );
    final matchesGenre = genre == null || danceGenreNames.contains(genre);
    return matchesKeyword && matchesGenre;
  }

  static List<String> _stringList(dynamic value) {
    return (value as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString())
        .toList(growable: false);
  }
}

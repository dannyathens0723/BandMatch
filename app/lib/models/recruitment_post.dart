class RecruitmentPost {
  const RecruitmentPost({
    required this.id,
    required this.groupId,
    required this.title,
    required this.body,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.wantedPartIds,
    required this.wantedPartNames,
    required this.genreIds,
    required this.genreNames,
    required this.areaIds,
    required this.areaNames,
  });

  final String id;
  final String groupId;
  final String title;
  final String body;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Set<String> wantedPartIds;
  final List<String> wantedPartNames;
  final Set<String> genreIds;
  final List<String> genreNames;
  final Set<String> areaIds;
  final List<String> areaNames;

  factory RecruitmentPost.fromJson(Map<String, dynamic> json) {
    return RecruitmentPost(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      wantedPartIds: _stringSet(json['wanted_part_ids']),
      wantedPartNames: _stringList(json['wanted_part_names']),
      genreIds: _stringSet(json['genre_ids']),
      genreNames: _stringList(json['genre_names']),
      areaIds: _stringSet(json['area_ids']),
      areaNames: _stringList(json['area_names']),
    );
  }

  static List<String> _stringList(dynamic value) {
    return (value as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false);
  }

  static Set<String> _stringSet(dynamic value) => _stringList(value).toSet();
}

class RecruitmentPostEditData {
  const RecruitmentPostEditData({
    required this.title,
    required this.body,
    required this.status,
    required this.wantedPartIds,
    required this.genreIds,
    required this.areaIds,
  });

  final String title;
  final String body;
  final String status;
  final Set<String> wantedPartIds;
  final Set<String> genreIds;
  final Set<String> areaIds;

  Map<String, dynamic> toCreateRpcParams(String groupId) {
    return {
      'p_group_id': groupId,
      'p_title': title,
      'p_body': body,
      'p_status': status,
      'p_wanted_part_ids': wantedPartIds.toList(growable: false),
      'p_genre_ids': genreIds.toList(growable: false),
      'p_area_ids': areaIds.toList(growable: false),
    };
  }

  Map<String, dynamic> toUpdateRpcParams(String postId) {
    return {
      'p_post_id': postId,
      'p_title': title,
      'p_body': body,
      'p_status': status,
      'p_wanted_part_ids': wantedPartIds.toList(growable: false),
      'p_genre_ids': genreIds.toList(growable: false),
      'p_area_ids': areaIds.toList(growable: false),
    };
  }
}

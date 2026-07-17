class MyGroupProfile {
  const MyGroupProfile({
    required this.id,
    required this.createdBy,
    required this.name,
    required this.bio,
    required this.activityFrequency,
    required this.accountStatus,
    required this.membershipRole,
    required this.createdAt,
    required this.updatedAt,
    required this.genreIds,
    required this.genreNames,
    required this.recruitingPartIds,
    required this.recruitingPartNames,
    required this.areaIds,
    required this.areaNames,
  });

  final String id;
  final String createdBy;
  final String name;
  final String? bio;
  final String? activityFrequency;
  final String accountStatus;
  final String membershipRole;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Set<String> genreIds;
  final List<String> genreNames;
  final Set<String> recruitingPartIds;
  final List<String> recruitingPartNames;
  final Set<String> areaIds;
  final List<String> areaNames;

  bool get isAdmin => membershipRole == 'admin';

  factory MyGroupProfile.fromJson(Map<String, dynamic> json) {
    return MyGroupProfile(
      id: json['id'] as String,
      createdBy: json['created_by'] as String,
      name: json['name'] as String,
      bio: json['bio'] as String?,
      activityFrequency: json['activity_frequency'] as String?,
      accountStatus: json['account_status'] as String,
      membershipRole: json['membership_role'] as String? ?? 'admin',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      genreIds: _stringSet(json['genre_ids']),
      genreNames: _stringList(json['genre_names']),
      recruitingPartIds: _stringSet(json['recruiting_part_ids']),
      recruitingPartNames: _stringList(json['recruiting_part_names']),
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

class GroupEditData {
  const GroupEditData({
    required this.name,
    required this.bio,
    required this.genreIds,
    required this.recruitingPartIds,
    required this.areaIds,
  });

  final String name;
  final String bio;
  final Set<String> genreIds;
  final Set<String> recruitingPartIds;
  final Set<String> areaIds;

  Map<String, dynamic> toCreateRpcParams() {
    return {
      'p_name': name,
      'p_bio': bio,
      'p_genre_ids': genreIds.toList(growable: false),
      'p_recruiting_part_ids': recruitingPartIds.toList(growable: false),
      'p_area_ids': areaIds.toList(growable: false),
    };
  }

  Map<String, dynamic> toUpdateRpcParams(String groupId) {
    return {'p_group_id': groupId, ...toCreateRpcParams()};
  }
}

class StageMyCrew {
  const StageMyCrew({
    required this.crewId,
    required this.crewName,
    required this.crewAvatarUrl,
    required this.crewBio,
    required this.membershipRole,
    required this.isCreator,
    required this.joinedAt,
    required this.activeMemberCount,
    required this.openRecruitmentCount,
    required this.danceGenreNames,
    required this.areaNames,
  });

  final String crewId;
  final String crewName;
  final String? crewAvatarUrl;
  final String? crewBio;
  final String membershipRole;
  final bool isCreator;
  final DateTime joinedAt;
  final int activeMemberCount;
  final int openRecruitmentCount;
  final List<String> danceGenreNames;
  final List<String> areaNames;

  bool get isManaged => membershipRole == 'admin';

  factory StageMyCrew.fromJson(Map<String, dynamic> json) {
    return StageMyCrew(
      crewId: json['crew_id'] as String,
      crewName: json['crew_name'] as String,
      crewAvatarUrl: json['crew_avatar_url'] as String?,
      crewBio: json['crew_bio'] as String?,
      membershipRole: json['membership_role'] as String,
      isCreator: json['is_creator'] as bool,
      joinedAt: DateTime.parse(json['joined_at'] as String).toLocal(),
      activeMemberCount: _integer(json['active_member_count']),
      openRecruitmentCount: _integer(json['open_recruitment_count']),
      danceGenreNames: _strings(json['dance_genre_names']),
      areaNames: _strings(json['area_names']),
    );
  }
}

class StageMyCrewApplication {
  const StageMyCrewApplication({
    required this.applicationId,
    required this.postId,
    required this.crewId,
    required this.crewName,
    required this.crewAvatarUrl,
    required this.title,
    required this.body,
    required this.applicationStatus,
    required this.appliedAt,
    required this.respondedAt,
    required this.postStatus,
    required this.danceGenreNames,
    required this.areaNames,
  });

  final String applicationId;
  final String postId;
  final String crewId;
  final String crewName;
  final String? crewAvatarUrl;
  final String title;
  final String body;
  final String applicationStatus;
  final DateTime appliedAt;
  final DateTime? respondedAt;
  final String postStatus;
  final List<String> danceGenreNames;
  final List<String> areaNames;

  factory StageMyCrewApplication.fromJson(Map<String, dynamic> json) {
    return StageMyCrewApplication(
      applicationId: json['application_id'] as String,
      postId: json['post_id'] as String,
      crewId: json['crew_id'] as String,
      crewName: json['crew_name'] as String,
      crewAvatarUrl: json['crew_avatar_url'] as String?,
      title: json['title'] as String,
      body: json['body'] as String,
      applicationStatus: json['application_status'] as String,
      appliedAt: DateTime.parse(json['applied_at'] as String).toLocal(),
      respondedAt: _dateTime(json['responded_at']),
      postStatus: json['post_status'] as String,
      danceGenreNames: _strings(json['dance_genre_names']),
      areaNames: _strings(json['area_names']),
    );
  }
}

class StageMyCrewOverview {
  const StageMyCrewOverview({required this.crews, required this.applications});

  final List<StageMyCrew> crews;
  final List<StageMyCrewApplication> applications;

  List<StageMyCrew> get managedCrews =>
      crews.where((crew) => crew.isManaged).toList(growable: false);

  List<StageMyCrew> get participatingCrews =>
      crews.where((crew) => !crew.isManaged).toList(growable: false);

  bool get isEmpty => crews.isEmpty && applications.isEmpty;
}

int _integer(dynamic value) =>
    value is num ? value.toInt() : int.parse(value.toString());

DateTime? _dateTime(dynamic value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();

List<String> _strings(dynamic value) =>
    (value as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString())
        .toList(growable: false);

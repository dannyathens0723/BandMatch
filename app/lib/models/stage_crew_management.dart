class StageCrewOption {
  const StageCrewOption({required this.id, required this.name});

  final String id;
  final String name;

  factory StageCrewOption.fromJson(Map<String, dynamic> json) =>
      StageCrewOption(id: json['id'] as String, name: json['name'] as String);
}

class StageCrewFormOptions {
  const StageCrewFormOptions({required this.genres, required this.areas});

  final List<StageCrewOption> genres;
  final List<StageCrewOption> areas;

  factory StageCrewFormOptions.fromJson(Map<String, dynamic> json) =>
      StageCrewFormOptions(
        genres: _objects(
          json['dance_genres'],
        ).map(StageCrewOption.fromJson).toList(growable: false),
        areas: _objects(
          json['areas'],
        ).map(StageCrewOption.fromJson).toList(growable: false),
      );
}

class StageManagedCrew {
  const StageManagedCrew({
    required this.crewId,
    required this.name,
    required this.bio,
    required this.activityFrequency,
    required this.danceGenreIds,
    required this.danceGenreNames,
    required this.areaId,
    required this.areaName,
    required this.activeMemberCount,
  });

  final String crewId;
  final String name;
  final String? bio;
  final String? activityFrequency;
  final List<String> danceGenreIds;
  final List<String> danceGenreNames;
  final String? areaId;
  final String? areaName;
  final int activeMemberCount;

  factory StageManagedCrew.fromJson(Map<String, dynamic> json) =>
      StageManagedCrew(
        crewId: json['crew_id'] as String,
        name: json['name'] as String,
        bio: json['bio'] as String?,
        activityFrequency: json['activity_frequency'] as String?,
        danceGenreIds: _strings(json['dance_genre_ids']),
        danceGenreNames: _strings(json['dance_genre_names']),
        areaId: json['area_id'] as String?,
        areaName: json['area_name'] as String?,
        activeMemberCount: _integer(json['active_member_count']),
      );
}

class StageManagedRecruitment {
  const StageManagedRecruitment({
    required this.postId,
    required this.crewId,
    required this.title,
    required this.body,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.danceGenreIds,
    required this.danceGenreNames,
    required this.areaId,
    required this.areaName,
    required this.pendingApplicationCount,
  });

  final String postId;
  final String crewId;
  final String title;
  final String body;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> danceGenreIds;
  final List<String> danceGenreNames;
  final String? areaId;
  final String? areaName;
  final int pendingApplicationCount;

  bool get isOpen => status == 'open';

  factory StageManagedRecruitment.fromJson(Map<String, dynamic> json) =>
      StageManagedRecruitment(
        postId: json['post_id'] as String,
        crewId: json['crew_id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
        danceGenreIds: _strings(json['dance_genre_ids']),
        danceGenreNames: _strings(json['dance_genre_names']),
        areaId: json['area_id'] as String?,
        areaName: json['area_name'] as String?,
        pendingApplicationCount: _integer(json['pending_application_count']),
      );
}

class StageRecruitmentApplicant {
  const StageRecruitmentApplicant({
    required this.applicationId,
    required this.postId,
    required this.crewId,
    required this.applicantUserId,
    required this.displayName,
    required this.avatarUrl,
    required this.experienceLevel,
    required this.danceGenreNames,
    required this.performanceRoleNames,
    required this.primaryPerformanceRoleName,
    required this.applicationNote,
    required this.applicationStatus,
    required this.appliedAt,
    required this.respondedAt,
  });

  final String applicationId;
  final String postId;
  final String crewId;
  final String applicantUserId;
  final String displayName;
  final String? avatarUrl;
  final String? experienceLevel;
  final List<String> danceGenreNames;
  final List<String> performanceRoleNames;
  final String? primaryPerformanceRoleName;
  final String? applicationNote;
  final String applicationStatus;
  final DateTime appliedAt;
  final DateTime? respondedAt;

  bool get isPending => applicationStatus == 'pending';

  factory StageRecruitmentApplicant.fromJson(Map<String, dynamic> json) =>
      StageRecruitmentApplicant(
        applicationId: json['application_id'] as String,
        postId: json['post_id'] as String,
        crewId: json['crew_id'] as String,
        applicantUserId: json['applicant_user_id'] as String,
        displayName: json['display_name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        experienceLevel: json['experience_level'] as String?,
        danceGenreNames: _strings(json['dance_genre_names']),
        performanceRoleNames: _strings(json['performance_role_names']),
        primaryPerformanceRoleName:
            json['primary_performance_role_name'] as String?,
        applicationNote: json['application_note'] as String?,
        applicationStatus: json['application_status'] as String,
        appliedAt: DateTime.parse(json['applied_at'] as String).toLocal(),
        respondedAt: json['responded_at'] == null
            ? null
            : DateTime.parse(json['responded_at'] as String).toLocal(),
      );
}

class StageApplicationDecision {
  const StageApplicationDecision({
    required this.applicationId,
    required this.applicationStatus,
    required this.membershipStatus,
  });

  final String applicationId;
  final String applicationStatus;
  final String? membershipStatus;

  factory StageApplicationDecision.fromJson(Map<String, dynamic> json) =>
      StageApplicationDecision(
        applicationId: json['application_id'] as String,
        applicationStatus: json['application_status'] as String,
        membershipStatus: json['membership_status'] as String?,
      );
}

List<Map<String, dynamic>> _objects(dynamic value) =>
    (value as List<dynamic>? ?? const <dynamic>[])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);

List<String> _strings(dynamic value) =>
    (value as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString())
        .toList(growable: false);

int _integer(dynamic value) =>
    value is num ? value.toInt() : int.parse(value.toString());

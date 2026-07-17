class RecruitmentApplicationState {
  const RecruitmentApplicationState({
    required this.state,
    required this.applicationId,
  });

  final String state;
  final String? applicationId;

  bool get canApply => state == 'none';

  factory RecruitmentApplicationState.fromJson(Map<String, dynamic> json) {
    return RecruitmentApplicationState(
      state: json['state'] as String? ?? 'none',
      applicationId: json['application_id'] as String?,
    );
  }
}

class RecruitmentApplication {
  const RecruitmentApplication({
    required this.id,
    required this.recruitmentPostId,
    required this.groupId,
    required this.postTitle,
    required this.applicantUserId,
    required this.applicantDisplayName,
    required this.applicantAvatarUrl,
    required this.applicantExperienceLevel,
    required this.applicantPartNames,
    required this.applicantGenreNames,
    required this.note,
    required this.status,
    required this.createdAt,
    required this.respondedAt,
  });

  final String id;
  final String recruitmentPostId;
  final String groupId;
  final String postTitle;
  final String applicantUserId;
  final String applicantDisplayName;
  final String? applicantAvatarUrl;
  final String? applicantExperienceLevel;
  final List<String> applicantPartNames;
  final List<String> applicantGenreNames;
  final String? note;
  final String status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  bool get isPending => status == 'pending';

  factory RecruitmentApplication.fromJson(Map<String, dynamic> json) {
    return RecruitmentApplication(
      id: json['id'] as String,
      recruitmentPostId: json['recruitment_post_id'] as String,
      groupId: json['group_id'] as String,
      postTitle: json['post_title'] as String,
      applicantUserId: json['applicant_user_id'] as String,
      applicantDisplayName: json['applicant_display_name'] as String,
      applicantAvatarUrl: json['applicant_avatar_url'] as String?,
      applicantExperienceLevel: json['applicant_experience_level'] as String?,
      applicantPartNames: _stringList(json['applicant_part_names']),
      applicantGenreNames: _stringList(json['applicant_genre_names']),
      note: json['note'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      respondedAt: json['responded_at'] == null
          ? null
          : DateTime.parse(json['responded_at'] as String).toLocal(),
    );
  }
}

List<String> _stringList(dynamic value) {
  return (value as List<dynamic>? ?? const [])
      .map((item) => item.toString())
      .toList(growable: false);
}

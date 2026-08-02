class StageActivity {
  const StageActivity({
    required this.activityKey,
    required this.activityType,
    required this.activityStatus,
    required this.occurredAt,
    required this.crewId,
    required this.crewName,
    required this.postId,
    required this.postTitle,
    required this.applicationId,
    required this.actorDisplayName,
  });

  final String activityKey;
  final String activityType;
  final String activityStatus;
  final DateTime occurredAt;
  final String crewId;
  final String crewName;
  final String? postId;
  final String? postTitle;
  final String? applicationId;
  final String? actorDisplayName;

  bool get requiresAttention =>
      activityType == 'managed_application' && activityStatus == 'pending';

  String? get announcementId {
    const prefix = 'crew_announcement:';
    if (activityType != 'crew_announcement' ||
        !activityKey.startsWith(prefix)) {
      return null;
    }
    final value = activityKey.substring(prefix.length);
    return value.isEmpty ? null : value;
  }

  factory StageActivity.fromJson(Map<String, dynamic> json) {
    return StageActivity(
      activityKey: json['activity_key'] as String,
      activityType: json['activity_type'] as String,
      activityStatus: json['activity_status'] as String,
      occurredAt: DateTime.parse(json['occurred_at'] as String).toLocal(),
      crewId: json['crew_id'] as String,
      crewName: json['crew_name'] as String,
      postId: json['post_id'] as String?,
      postTitle: json['post_title'] as String?,
      applicationId: json['application_id'] as String?,
      actorDisplayName: json['actor_display_name'] as String?,
    );
  }
}

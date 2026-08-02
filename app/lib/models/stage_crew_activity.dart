class StageCrewHome {
  const StageCrewHome({
    required this.crewId,
    required this.crewName,
    required this.membershipRole,
    this.crewAvatarUrl,
    this.crewBio,
    this.targetEvent,
    this.nextPractice,
    this.openPoll,
    this.latestAnnouncement,
    this.latestResource,
  });

  final String crewId;
  final String crewName;
  final String membershipRole;
  final String? crewAvatarUrl;
  final String? crewBio;
  final StageCrewTarget? targetEvent;
  final StageCrewPractice? nextPractice;
  final StageCrewPoll? openPoll;
  final StageCrewAnnouncement? latestAnnouncement;
  final StageCrewResource? latestResource;

  bool get isAdmin => membershipRole == 'admin';

  factory StageCrewHome.fromJson(Map<String, dynamic> json) => StageCrewHome(
    crewId: json['crew_id'] as String,
    crewName: json['crew_name'] as String,
    membershipRole: json['membership_role'] as String,
    crewAvatarUrl: json['crew_avatar_url'] as String?,
    crewBio: json['crew_bio'] as String?,
    targetEvent: _optionalMap(json['target_event'], StageCrewTarget.fromJson),
    nextPractice: _optionalMap(
      json['next_practice'],
      StageCrewPractice.fromJson,
    ),
    openPoll: _optionalMap(json['open_poll'], StageCrewPoll.fromJson),
    latestAnnouncement: _optionalMap(
      json['latest_announcement'],
      StageCrewAnnouncement.fromJson,
    ),
    latestResource: _optionalMap(
      json['latest_resource'],
      StageCrewResource.fromJson,
    ),
  );
}

class StageCrewActivitySnapshot {
  const StageCrewActivitySnapshot({
    required this.isAdmin,
    required this.practices,
    required this.polls,
    required this.announcements,
    required this.resources,
    required this.targets,
  });

  final bool isAdmin;
  final List<StageCrewPractice> practices;
  final List<StageCrewPoll> polls;
  final List<StageCrewAnnouncement> announcements;
  final List<StageCrewResource> resources;
  final List<StageCrewTarget> targets;

  factory StageCrewActivitySnapshot.fromJson(Map<String, dynamic> json) =>
      StageCrewActivitySnapshot(
        isAdmin: json['is_admin'] as bool,
        practices: _list(json['practices'], StageCrewPractice.fromJson),
        polls: _list(json['polls'], StageCrewPoll.fromJson),
        announcements: _list(
          json['announcements'],
          StageCrewAnnouncement.fromJson,
        ),
        resources: _list(json['resources'], StageCrewResource.fromJson),
        targets: _list(json['targets'], StageCrewTarget.fromJson),
      );
}

class StageCrewPractice {
  const StageCrewPractice({
    required this.practiceId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.attendingCount,
    required this.maybeCount,
    required this.notAttendingCount,
    this.areaId,
    this.locationName,
    this.meetingNote,
    this.description,
    this.attendanceDeadline,
    this.myAttendance,
  });

  final String practiceId;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final String? areaId;
  final String? locationName;
  final String? meetingNote;
  final String? description;
  final DateTime? attendanceDeadline;
  final String? myAttendance;
  final int attendingCount;
  final int maybeCount;
  final int notAttendingCount;

  bool get acceptsAttendance =>
      status == 'scheduled' &&
      endsAt.isAfter(DateTime.now()) &&
      (attendanceDeadline == null ||
          attendanceDeadline!.isAfter(DateTime.now()));

  factory StageCrewPractice.fromJson(Map<String, dynamic> json) {
    final counts = _map(json['attendance_counts']);
    return StageCrewPractice(
      practiceId: json['practice_id'] as String,
      title: json['title'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
      status: json['status'] as String,
      areaId: json['area_id'] as String?,
      locationName: json['location_name'] as String?,
      meetingNote: json['meeting_note'] as String?,
      description: json['description'] as String?,
      attendanceDeadline: _date(json['attendance_deadline']),
      myAttendance: json['my_attendance'] as String?,
      attendingCount: (counts['attending'] as num?)?.toInt() ?? 0,
      maybeCount: (counts['maybe'] as num?)?.toInt() ?? 0,
      notAttendingCount: (counts['not_attending'] as num?)?.toInt() ?? 0,
    );
  }
}

class StageCrewPoll {
  const StageCrewPoll({
    required this.pollId,
    required this.title,
    required this.status,
    required this.options,
    this.finalizedOptionId,
    this.resultingPracticeId,
  });

  final String pollId;
  final String title;
  final String status;
  final String? finalizedOptionId;
  final String? resultingPracticeId;
  final List<StageCrewPollOption> options;

  factory StageCrewPoll.fromJson(Map<String, dynamic> json) => StageCrewPoll(
    pollId: json['poll_id'] as String,
    title: json['title'] as String,
    status: json['status'] as String,
    finalizedOptionId: json['finalized_option_id'] as String?,
    resultingPracticeId: json['resulting_practice_id'] as String?,
    options: _list(json['options'], StageCrewPollOption.fromJson),
  );
}

class StageCrewPollOption {
  const StageCrewPollOption({
    required this.optionId,
    required this.startsAt,
    required this.endsAt,
    required this.availableCount,
    required this.maybeCount,
    required this.unavailableCount,
    this.myResponse,
  });

  final String optionId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? myResponse;
  final int availableCount;
  final int maybeCount;
  final int unavailableCount;

  factory StageCrewPollOption.fromJson(Map<String, dynamic> json) {
    final counts = _map(json['counts']);
    return StageCrewPollOption(
      optionId: json['option_id'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
      myResponse: json['my_response'] as String?,
      availableCount: (counts['available'] as num?)?.toInt() ?? 0,
      maybeCount: (counts['maybe'] as num?)?.toInt() ?? 0,
      unavailableCount: (counts['unavailable'] as num?)?.toInt() ?? 0,
    );
  }
}

class StageCrewAnnouncement {
  const StageCrewAnnouncement({
    required this.announcementId,
    required this.title,
    required this.status,
    this.body,
    this.authorDisplayName,
    this.publishedAt,
    this.createdAt,
  });

  final String announcementId;
  final String title;
  final String status;
  final String? body;
  final String? authorDisplayName;
  final DateTime? publishedAt;
  final DateTime? createdAt;

  factory StageCrewAnnouncement.fromJson(Map<String, dynamic> json) =>
      StageCrewAnnouncement(
        announcementId: json['announcement_id'] as String,
        title: json['title'] as String,
        status: json['status'] as String? ?? 'published',
        body: json['body'] as String?,
        authorDisplayName: json['author_display_name'] as String?,
        publishedAt: _date(json['published_at']),
        createdAt: _date(json['created_at']),
      );
}

class StageCrewResource {
  const StageCrewResource({
    required this.resourceId,
    required this.title,
    required this.resourceType,
    required this.status,
    this.externalUrl,
    this.description,
    this.createdAt,
  });

  final String resourceId;
  final String title;
  final String resourceType;
  final String status;
  final String? externalUrl;
  final String? description;
  final DateTime? createdAt;

  Uri? get safeExternalUri => parseStageCrewResourceHttpsUri(externalUrl ?? '');

  factory StageCrewResource.fromJson(Map<String, dynamic> json) =>
      StageCrewResource(
        resourceId: json['resource_id'] as String,
        title: json['title'] as String,
        resourceType: json['resource_type'] as String,
        status: json['status'] as String? ?? 'active',
        externalUrl: json['external_url'] as String?,
        description: json['description'] as String?,
        createdAt: _date(json['created_at']),
      );
}

const stageCrewResourceUrlErrorMessage = '有効なHTTPS URLを入力してください。';

Uri? parseStageCrewResourceHttpsUri(String value) {
  if (value.isEmpty ||
      value.length > 2000 ||
      value != value.trim() ||
      RegExp(r'\s').hasMatch(value)) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.isAbsolute ||
      !uri.hasAuthority ||
      uri.scheme != 'https' ||
      !_isValidExternalHost(uri.host)) {
    return null;
  }
  return uri;
}

bool _isValidExternalHost(String host) {
  if (host.isEmpty || host.length > 253) return false;
  if (host.contains(':')) {
    return RegExp(r'^[0-9a-fA-F:.]+$').hasMatch(host);
  }
  final labelPattern = RegExp(
    r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$',
  );
  return host.split('.').every(labelPattern.hasMatch);
}

class StageCrewTarget {
  const StageCrewTarget({
    required this.targetId,
    required this.eventId,
    required this.title,
    required this.status,
    this.startsAt,
    this.venueName,
    this.startedAt,
    this.endedAt,
  });

  final String targetId;
  final String eventId;
  final String title;
  final String status;
  final DateTime? startsAt;
  final String? venueName;
  final DateTime? startedAt;
  final DateTime? endedAt;

  factory StageCrewTarget.fromJson(Map<String, dynamic> json) =>
      StageCrewTarget(
        targetId: json['target_id'] as String,
        eventId: json['event_id'] as String,
        title: json['title'] as String,
        status: json['status'] as String? ?? 'active',
        startsAt: _date(json['starts_at']),
        venueName: json['venue_name'] as String?,
        startedAt: _date(json['started_at']),
        endedAt: _date(json['ended_at']),
      );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

T? _optionalMap<T>(Object? value, T Function(Map<String, dynamic>) parser) =>
    value == null ? null : parser(_map(value));

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) parser) =>
    value is List
    ? value.map((item) => parser(_map(item))).toList(growable: false)
    : const [];

DateTime? _date(Object? value) =>
    value is String ? DateTime.parse(value).toLocal() : null;

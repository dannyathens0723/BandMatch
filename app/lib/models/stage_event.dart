class StageEvent {
  const StageEvent({
    required this.eventId,
    required this.organizerId,
    required this.organizerName,
    required this.organizerOfficialUrl,
    required this.title,
    required this.category,
    required this.summary,
    required this.eligibilitySummary,
    required this.venueName,
    required this.startsAt,
    required this.endsAt,
    required this.applicationDeadline,
    required this.feeSummary,
    required this.officialUrl,
    required this.sourceUrl,
    required this.sourceType,
    required this.lastVerifiedAt,
    required this.eventStatus,
    required this.danceGenreNames,
    required this.areaNames,
  });

  final String eventId;
  final String organizerId;
  final String organizerName;
  final String? organizerOfficialUrl;
  final String title;
  final String category;
  final String summary;
  final String? eligibilitySummary;
  final String venueName;
  final DateTime startsAt;
  final DateTime? endsAt;
  final DateTime? applicationDeadline;
  final String? feeSummary;
  final String? officialUrl;
  final String sourceUrl;
  final String sourceType;
  final DateTime lastVerifiedAt;
  final String eventStatus;
  final List<String> danceGenreNames;
  final List<String> areaNames;

  Uri get primaryExternalUri => Uri.parse(officialUrl ?? sourceUrl);

  factory StageEvent.fromJson(Map<String, dynamic> json) {
    return StageEvent(
      eventId: json['event_id'] as String,
      organizerId: json['organizer_id'] as String,
      organizerName: json['organizer_name'] as String,
      organizerOfficialUrl: json['organizer_official_url'] as String?,
      title: json['title'] as String,
      category: json['category'] as String,
      summary: json['summary'] as String,
      eligibilitySummary: json['eligibility_summary'] as String?,
      venueName: json['venue_name'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      endsAt: _dateTimeOrNull(json['ends_at']),
      applicationDeadline: _dateTimeOrNull(json['application_deadline']),
      feeSummary: json['fee_summary'] as String?,
      officialUrl: json['official_url'] as String?,
      sourceUrl: json['source_url'] as String,
      sourceType: json['source_type'] as String,
      lastVerifiedAt: DateTime.parse(
        json['last_verified_at'] as String,
      ).toLocal(),
      eventStatus: json['event_status'] as String,
      danceGenreNames: _stringList(json['dance_genre_names']),
      areaNames: _stringList(json['area_names']),
    );
  }

  static DateTime? _dateTimeOrNull(dynamic value) {
    if (value == null) return null;
    return DateTime.parse(value as String).toLocal();
  }

  static List<String> _stringList(dynamic value) {
    return (value as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString())
        .toList(growable: false);
  }
}

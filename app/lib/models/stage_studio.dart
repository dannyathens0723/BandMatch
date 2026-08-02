class StageStudioRoom {
  const StageStudioRoom({
    required this.roomId,
    required this.name,
    required this.capacity,
    required this.sizeSqm,
    required this.hourlyPriceYen,
    required this.facilityNames,
  });

  final String roomId;
  final String name;
  final int? capacity;
  final double? sizeSqm;
  final int? hourlyPriceYen;
  final List<String> facilityNames;

  factory StageStudioRoom.fromJson(Map<String, dynamic> json) {
    return StageStudioRoom(
      roomId: json['room_id'] as String,
      name: json['name'] as String,
      capacity: _integerOrNull(json['capacity']),
      sizeSqm: _doubleOrNull(json['size_sqm']),
      hourlyPriceYen: _integerOrNull(json['hourly_price_yen']),
      facilityNames: _stringList(json['facility_names']),
    );
  }
}

class StageStudio {
  const StageStudio({
    required this.studioId,
    required this.name,
    required this.areaId,
    required this.areaName,
    required this.addressDisplay,
    required this.latitude,
    required this.longitude,
    required this.nearestStationName,
    required this.walkingMinutes,
    required this.accessNote,
    required this.openingHoursSummary,
    required this.minimumHourlyPriceYen,
    required this.websiteUrl,
    required this.bookingUrl,
    required this.reviewSummary,
    required this.rating,
    required this.ratingCount,
    required this.sourceLabel,
    required this.sourceUrl,
    required this.lastVerifiedAt,
    required this.roomCount,
    required this.maxCapacity,
    required this.largestRoomSizeSqm,
    required this.facilityNames,
    required this.rooms,
  });

  final String studioId;
  final String name;
  final String? areaId;
  final String? areaName;
  final String addressDisplay;
  final double? latitude;
  final double? longitude;
  final String? nearestStationName;
  final int? walkingMinutes;
  final String? accessNote;
  final String? openingHoursSummary;
  final int? minimumHourlyPriceYen;
  final String? websiteUrl;
  final String? bookingUrl;
  final String? reviewSummary;
  final double? rating;
  final int ratingCount;
  final String sourceLabel;
  final String sourceUrl;
  final DateTime lastVerifiedAt;
  final int roomCount;
  final int? maxCapacity;
  final double? largestRoomSizeSqm;
  final List<String> facilityNames;
  final List<StageStudioRoom> rooms;

  Uri? get primaryExternalUri {
    for (final candidate in [bookingUrl, websiteUrl]) {
      if (candidate == null) continue;
      final uri = Uri.tryParse(candidate);
      if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
        return uri;
      }
    }
    return null;
  }

  bool matchesKeyword(String keyword) {
    final normalized = keyword.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return [name, areaName, addressDisplay, nearestStationName, accessNote]
        .whereType<String>()
        .any((value) => value.toLowerCase().contains(normalized));
  }

  factory StageStudio.fromJson(Map<String, dynamic> json) {
    final roomRows = json['room_summaries'] as List<dynamic>? ?? const [];
    return StageStudio(
      studioId: json['studio_id'] as String,
      name: json['name'] as String,
      areaId: json['area_id'] as String?,
      areaName: json['area_name'] as String?,
      addressDisplay: json['address_display'] as String,
      latitude: _doubleOrNull(json['latitude']),
      longitude: _doubleOrNull(json['longitude']),
      nearestStationName: json['nearest_station_name'] as String?,
      walkingMinutes: _integerOrNull(json['walking_minutes']),
      accessNote: json['access_note'] as String?,
      openingHoursSummary: json['opening_hours_summary'] as String?,
      minimumHourlyPriceYen: _integerOrNull(json['minimum_hourly_price_yen']),
      websiteUrl: json['website_url'] as String?,
      bookingUrl: json['booking_url'] as String?,
      reviewSummary: json['review_summary'] as String?,
      rating: _doubleOrNull(json['rating']),
      ratingCount: _integerOrNull(json['rating_count']) ?? 0,
      sourceLabel: json['source_label'] as String,
      sourceUrl: json['source_url'] as String,
      lastVerifiedAt: DateTime.parse(
        json['last_verified_at'] as String,
      ).toLocal(),
      roomCount: _integerOrNull(json['room_count']) ?? 0,
      maxCapacity: _integerOrNull(json['max_capacity']),
      largestRoomSizeSqm: _doubleOrNull(json['largest_room_size_sqm']),
      facilityNames: _stringList(json['facility_names']),
      rooms: roomRows
          .map(
            (row) =>
                StageStudioRoom.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false),
    );
  }
}

int? _integerOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.parse(value as String);
}

double? _doubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.parse(value as String);
}

List<String> _stringList(dynamic value) {
  return (value as List<dynamic>? ?? const <dynamic>[])
      .map((item) => item.toString())
      .toList(growable: false);
}

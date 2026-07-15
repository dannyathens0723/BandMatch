class EditableProfile {
  const EditableProfile({
    required this.id,
    required this.displayName,
    required this.experienceLevel,
    required this.purposes,
    required this.partIds,
    required this.genreIds,
    required this.areaIds,
  });

  final String id;
  final String displayName;
  final String? experienceLevel;
  final Set<String> purposes;
  final Set<String> partIds;
  final Set<String> genreIds;
  final Set<String> areaIds;
}

class ProfileEditData {
  const ProfileEditData({
    required this.displayName,
    required this.experienceLevel,
    required this.purposes,
    required this.partIds,
    required this.genreIds,
    required this.areaIds,
  });

  final String displayName;
  final String experienceLevel;
  final Set<String> purposes;
  final Set<String> partIds;
  final Set<String> genreIds;
  final Set<String> areaIds;
}

class MemberSearchFilters {
  const MemberSearchFilters({
    this.partIds = const {},
    this.genreIds = const {},
    this.areaIds = const {},
    this.experienceLevels = const {},
    this.purposes = const {},
    this.keyword = '',
  });

  final Set<String> partIds;
  final Set<String> genreIds;
  final Set<String> areaIds;
  final Set<String> experienceLevels;
  final Set<String> purposes;
  final String keyword;

  bool get hasActiveFilters {
    return partIds.isNotEmpty ||
        genreIds.isNotEmpty ||
        areaIds.isNotEmpty ||
        experienceLevels.isNotEmpty ||
        purposes.isNotEmpty ||
        keyword.trim().isNotEmpty;
  }

  Map<String, dynamic> toRpcParams() {
    return {
      'p_part_ids': partIds.isEmpty ? null : partIds.toList(),
      'p_genre_ids': genreIds.isEmpty ? null : genreIds.toList(),
      'p_area_ids': areaIds.isEmpty ? null : areaIds.toList(),
      'p_experience_levels': experienceLevels.isEmpty
          ? null
          : experienceLevels.toList(),
      'p_purposes': purposes.isEmpty ? null : purposes.toList(),
      'p_keyword': keyword.trim().isEmpty ? null : keyword.trim(),
    };
  }
}

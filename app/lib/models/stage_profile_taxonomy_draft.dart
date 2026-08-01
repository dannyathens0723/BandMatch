final class StageProfileTaxonomyDraft {
  StageProfileTaxonomyDraft({
    required List<String> selectedGenreIds,
    required List<String> selectedRoleIds,
    required this.primaryRoleId,
  }) : selectedGenreIds = List.unmodifiable(selectedGenreIds),
       selectedRoleIds = List.unmodifiable(selectedRoleIds);

  final List<String> selectedGenreIds;
  final List<String> selectedRoleIds;
  final String primaryRoleId;
}

final class StageProfileTaxonomyValidation {
  const StageProfileTaxonomyValidation({
    this.genreMessage,
    this.roleMessage,
    this.primaryRoleMessage,
  });

  final String? genreMessage;
  final String? roleMessage;
  final String? primaryRoleMessage;

  bool get isValid =>
      genreMessage == null && roleMessage == null && primaryRoleMessage == null;
}

final class StageProfileTaxonomySelection {
  StageProfileTaxonomySelection({
    Set<String> selectedGenreIds = const {},
    Set<String> selectedRoleIds = const {},
    String? primaryRoleId,
  }) : selectedGenreIds = Set.unmodifiable(selectedGenreIds),
       selectedRoleIds = Set.unmodifiable(selectedRoleIds),
       primaryRoleId = selectedRoleIds.contains(primaryRoleId)
           ? primaryRoleId
           : null;

  final Set<String> selectedGenreIds;
  final Set<String> selectedRoleIds;
  final String? primaryRoleId;

  StageProfileTaxonomySelection toggleGenre(String genreId) {
    final nextGenres = {...selectedGenreIds};
    if (!nextGenres.add(genreId)) {
      nextGenres.remove(genreId);
    }
    return StageProfileTaxonomySelection(
      selectedGenreIds: nextGenres,
      selectedRoleIds: selectedRoleIds,
      primaryRoleId: primaryRoleId,
    );
  }

  StageProfileTaxonomySelection toggleRole(
    String roleId,
    List<String> orderedRoleIds,
  ) {
    final nextRoles = {...selectedRoleIds};
    String? nextPrimary = primaryRoleId;

    if (!nextRoles.add(roleId)) {
      nextRoles.remove(roleId);
      if (nextPrimary == roleId) {
        nextPrimary = _firstOrderedSelection(nextRoles, orderedRoleIds);
      }
    } else {
      nextPrimary ??= roleId;
    }

    return StageProfileTaxonomySelection(
      selectedGenreIds: selectedGenreIds,
      selectedRoleIds: nextRoles,
      primaryRoleId: nextPrimary,
    );
  }

  StageProfileTaxonomySelection choosePrimaryRole(String roleId) {
    if (!selectedRoleIds.contains(roleId)) return this;
    return StageProfileTaxonomySelection(
      selectedGenreIds: selectedGenreIds,
      selectedRoleIds: selectedRoleIds,
      primaryRoleId: roleId,
    );
  }

  StageProfileTaxonomySelection retainAvailableGenres(
    Iterable<String> availableGenreIds,
  ) {
    final available = availableGenreIds.toSet();
    return StageProfileTaxonomySelection(
      selectedGenreIds: selectedGenreIds.intersection(available),
      selectedRoleIds: selectedRoleIds,
      primaryRoleId: primaryRoleId,
    );
  }

  StageProfileTaxonomySelection retainAvailableRoles(
    List<String> orderedRoleIds,
  ) {
    final available = orderedRoleIds.toSet();
    final retainedRoles = selectedRoleIds.intersection(available);
    final retainedPrimary = retainedRoles.contains(primaryRoleId)
        ? primaryRoleId
        : _firstOrderedSelection(retainedRoles, orderedRoleIds);
    return StageProfileTaxonomySelection(
      selectedGenreIds: selectedGenreIds,
      selectedRoleIds: retainedRoles,
      primaryRoleId: retainedPrimary,
    );
  }

  StageProfileTaxonomyValidation validate() {
    return StageProfileTaxonomyValidation(
      genreMessage: selectedGenreIds.isEmpty ? 'ダンスジャンルを1つ以上選択してください' : null,
      roleMessage: selectedRoleIds.isEmpty ? '役割を1つ以上選択してください' : null,
      primaryRoleMessage: selectedRoleIds.isNotEmpty && primaryRoleId == null
          ? 'メインの役割を選択してください'
          : null,
    );
  }

  StageProfileTaxonomyDraft toDraft({
    required List<String> orderedGenreIds,
    required List<String> orderedRoleIds,
  }) {
    final validation = validate();
    if (!validation.isValid || primaryRoleId == null) {
      throw StateError('A valid taxonomy selection is required.');
    }
    return StageProfileTaxonomyDraft(
      selectedGenreIds: orderedGenreIds
          .where(selectedGenreIds.contains)
          .toList(growable: false),
      selectedRoleIds: orderedRoleIds
          .where(selectedRoleIds.contains)
          .toList(growable: false),
      primaryRoleId: primaryRoleId!,
    );
  }
}

String? _firstOrderedSelection(
  Set<String> selectedIds,
  List<String> orderedIds,
) {
  for (final id in orderedIds) {
    if (selectedIds.contains(id)) return id;
  }
  return null;
}

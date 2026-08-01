import 'performance_domain.dart';
import 'stage_uuid.dart';

final class StageProfileTaxonomyPersistenceResult {
  StageProfileTaxonomyPersistenceResult._({
    required this.domain,
    required this.hasSavedTaxonomy,
    required List<String> genreIds,
    required List<String> roleIds,
    required this.primaryRoleId,
  }) : genreIds = List.unmodifiable(genreIds),
       roleIds = List.unmodifiable(roleIds);

  final PerformanceDomain domain;
  final bool hasSavedTaxonomy;
  final List<String> genreIds;
  final List<String> roleIds;
  final String? primaryRoleId;

  factory StageProfileTaxonomyPersistenceResult.fromRpcRow(
    Map<String, dynamic> row,
  ) {
    const requiredFields = {
      'domain',
      'has_saved_taxonomy',
      'genre_ids',
      'role_ids',
      'primary_role_id',
    };
    for (final field in requiredFields) {
      if (!row.containsKey(field)) {
        throw StageProfileTaxonomyPersistenceParseException(
          'Missing required field: $field',
        );
      }
    }

    final PerformanceDomain domain;
    try {
      domain = PerformanceDomain.fromRpcValue(row['domain']);
    } on UnsupportedPerformanceDomainException catch (error) {
      throw StageProfileTaxonomyPersistenceParseException(
        'domain must be Dance',
        cause: error,
      );
    }
    if (domain != PerformanceDomain.dance) {
      throw const StageProfileTaxonomyPersistenceParseException(
        'domain must be Dance',
      );
    }

    final hasSavedTaxonomy = row['has_saved_taxonomy'];
    if (hasSavedTaxonomy is! bool) {
      throw const StageProfileTaxonomyPersistenceParseException(
        'has_saved_taxonomy must be a boolean',
      );
    }

    final genreIds = _parseUuidList(row['genre_ids'], 'genre_ids');
    final roleIds = _parseUuidList(row['role_ids'], 'role_ids');
    final primaryRoleId = _parseNullableUuid(
      row['primary_role_id'],
      'primary_role_id',
    );

    if (!hasSavedTaxonomy) {
      if (genreIds.isNotEmpty || roleIds.isNotEmpty || primaryRoleId != null) {
        throw const StageProfileTaxonomyPersistenceParseException(
          'Unsaved taxonomy must not contain selections',
        );
      }
    } else {
      if (genreIds.isEmpty || roleIds.isEmpty || primaryRoleId == null) {
        throw const StageProfileTaxonomyPersistenceParseException(
          'Saved taxonomy must contain genres, roles, and a primary role',
        );
      }
      if (!roleIds.contains(primaryRoleId)) {
        throw const StageProfileTaxonomyPersistenceParseException(
          'The primary role must be one of the selected roles',
        );
      }
    }

    return StageProfileTaxonomyPersistenceResult._(
      domain: domain,
      hasSavedTaxonomy: hasSavedTaxonomy,
      genreIds: genreIds,
      roleIds: roleIds,
      primaryRoleId: primaryRoleId,
    );
  }
}

final class StageProfileTaxonomyPersistenceParseException implements Exception {
  const StageProfileTaxonomyPersistenceParseException(
    this.message, {
    this.cause,
  });

  final String message;
  final Object? cause;

  String get userMessage => '保存済みのプロフィール情報を確認できませんでした。';

  @override
  String toString() =>
      'StageProfileTaxonomyPersistenceParseException: $message';
}

List<String> _parseUuidList(Object? value, String field) {
  if (value is! List) {
    throw StageProfileTaxonomyPersistenceParseException(
      '$field must be a list',
    );
  }

  final ids = <String>[];
  for (var index = 0; index < value.length; index++) {
    final id = value[index];
    if (!isValidStageUuid(id)) {
      throw StageProfileTaxonomyPersistenceParseException(
        '$field item $index must be a UUID',
      );
    }
    ids.add(id as String);
  }
  return ids;
}

String? _parseNullableUuid(Object? value, String field) {
  if (value == null) return null;
  if (!isValidStageUuid(value)) {
    throw StageProfileTaxonomyPersistenceParseException(
      '$field must be a UUID or null',
    );
  }
  return value as String;
}

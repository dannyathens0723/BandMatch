import 'performance_domain.dart';

final class StageGenre {
  const StageGenre({
    required this.id,
    required this.code,
    required this.name,
    required this.domain,
    required this.category,
    required this.sortOrder,
  });

  final String id;
  final String code;
  final String name;
  final PerformanceDomain domain;
  final String category;
  final int sortOrder;

  factory StageGenre.fromJson(Map<String, dynamic> json) {
    return StageGenre(
      id: _requiredUuid(json, 'id'),
      code: _requiredString(json, 'code'),
      name: _requiredString(json, 'name'),
      domain: PerformanceDomain.fromRpcValue(json['domain']),
      category: _requiredString(json, 'category'),
      sortOrder: _requiredSmallInt(json, 'sort_order'),
    );
  }
}

final class StagePerformanceRole {
  const StagePerformanceRole({
    required this.id,
    required this.code,
    required this.name,
    required this.domain,
    required this.sortOrder,
  });

  final String id;
  final String code;
  final String name;
  final PerformanceDomain domain;
  final int sortOrder;

  factory StagePerformanceRole.fromJson(Map<String, dynamic> json) {
    return StagePerformanceRole(
      id: _requiredUuid(json, 'id'),
      code: _requiredString(json, 'code'),
      name: _requiredString(json, 'name'),
      domain: PerformanceDomain.fromRpcValue(json['domain']),
      sortOrder: _requiredSmallInt(json, 'sort_order'),
    );
  }
}

final class StageMasterDataParseException implements Exception {
  const StageMasterDataParseException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'StageMasterDataParseException: $message';
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

String _requiredUuid(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  if (!_uuidPattern.hasMatch(value)) {
    throw StageMasterDataParseException('$key must be a UUID');
  }
  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw StageMasterDataParseException('$key must be a non-empty string');
  }
  return value;
}

int _requiredSmallInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < -32768 || value > 32767) {
    throw StageMasterDataParseException('$key must be a PostgreSQL smallint');
  }
  return value;
}

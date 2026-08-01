final RegExp _stageUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool isValidStageUuid(Object? value) {
  return value is String && _stageUuidPattern.hasMatch(value);
}

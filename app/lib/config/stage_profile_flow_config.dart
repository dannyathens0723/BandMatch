abstract final class StageProfileFlowConfig {
  static const enabled = bool.fromEnvironment(
    'STAGE_PROFILE_FLOW',
    defaultValue: false,
  );
}

abstract final class StagePreviewConfig {
  static const enabled = bool.fromEnvironment(
    'STAGE_PREVIEW',
    defaultValue: false,
  );
}

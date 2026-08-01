abstract final class StageTaxonomyCheckConfig {
  static const enabled = bool.fromEnvironment(
    'STAGE_TAXONOMY_CHECK',
    defaultValue: false,
  );
}

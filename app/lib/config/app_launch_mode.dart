enum AppLaunchMode {
  stagePreview,
  stageTaxonomyCheck,
  stageProfileFlow,
  bandMatch,
}

AppLaunchMode resolveAppLaunchMode({
  required bool stagePreviewEnabled,
  required bool stageTaxonomyCheckEnabled,
  bool stageProfileFlowEnabled = false,
}) {
  if (stagePreviewEnabled) {
    return AppLaunchMode.stagePreview;
  }
  if (stageTaxonomyCheckEnabled) {
    return AppLaunchMode.stageTaxonomyCheck;
  }
  if (stageProfileFlowEnabled) {
    return AppLaunchMode.stageProfileFlow;
  }
  return AppLaunchMode.bandMatch;
}

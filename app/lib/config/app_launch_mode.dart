enum AppLaunchMode { stagePreview, stageTaxonomyCheck, bandMatch }

AppLaunchMode resolveAppLaunchMode({
  required bool stagePreviewEnabled,
  required bool stageTaxonomyCheckEnabled,
}) {
  if (stagePreviewEnabled) {
    return AppLaunchMode.stagePreview;
  }
  if (stageTaxonomyCheckEnabled) {
    return AppLaunchMode.stageTaxonomyCheck;
  }
  return AppLaunchMode.bandMatch;
}

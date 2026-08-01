import 'dart:io';

import 'package:app/config/app_launch_mode.dart';
import 'package:app/config/stage_taxonomy_check_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('STAGE Preview keeps priority when both flags are enabled', () {
    expect(
      resolveAppLaunchMode(
        stagePreviewEnabled: true,
        stageTaxonomyCheckEnabled: true,
      ),
      AppLaunchMode.stagePreview,
    );
  });

  test('taxonomy flag selects the real-data connection check', () {
    expect(
      resolveAppLaunchMode(
        stagePreviewEnabled: false,
        stageTaxonomyCheckEnabled: true,
      ),
      AppLaunchMode.stageTaxonomyCheck,
    );
  });

  test('normal execution still selects BandMatch', () {
    expect(
      resolveAppLaunchMode(
        stagePreviewEnabled: false,
        stageTaxonomyCheckEnabled: false,
      ),
      AppLaunchMode.bandMatch,
    );
    expect(StageTaxonomyCheckConfig.enabled, isFalse);
  });

  test('main initializes Supabase only after the preview return boundary', () {
    final source = File('lib/main.dart').readAsStringSync();
    final previewFlag = source.indexOf('StagePreviewConfig.enabled');
    final taxonomyFlag = source.indexOf('StageTaxonomyCheckConfig.enabled');
    final previewReturn = source.indexOf(
      'launchMode == AppLaunchMode.stagePreview',
    );
    final initialization = source.indexOf('Supabase.initialize');

    expect(previewFlag, greaterThanOrEqualTo(0));
    expect(taxonomyFlag, greaterThan(previewFlag));
    expect(previewReturn, greaterThan(taxonomyFlag));
    expect(initialization, greaterThan(previewReturn));
    expect(source, contains('StageTaxonomyCheckApp'));
    expect(source, contains('BandMatchApp'));
  });

  test('mock preview remains isolated from the taxonomy service', () {
    final previewSources = Directory('lib/stage_preview')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(previewSources, isNot(contains('StageMasterDataService')));
    expect(previewSources, isNot(contains('StageTaxonomyReadOnlyScreen')));
    expect(previewSources, isNot(contains('STAGE_TAXONOMY_CHECK')));
  });
}

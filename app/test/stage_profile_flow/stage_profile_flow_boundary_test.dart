import 'dart:io';

import 'package:app/config/app_launch_mode.dart';
import 'package:app/config/stage_profile_flow_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'launch priority is Preview, taxonomy check, profile flow, BandMatch',
    () {
      expect(
        resolveAppLaunchMode(
          stagePreviewEnabled: true,
          stageTaxonomyCheckEnabled: true,
          stageProfileFlowEnabled: true,
        ),
        AppLaunchMode.stagePreview,
      );
      expect(
        resolveAppLaunchMode(
          stagePreviewEnabled: false,
          stageTaxonomyCheckEnabled: true,
          stageProfileFlowEnabled: true,
        ),
        AppLaunchMode.stageTaxonomyCheck,
      );
      expect(
        resolveAppLaunchMode(
          stagePreviewEnabled: false,
          stageTaxonomyCheckEnabled: false,
          stageProfileFlowEnabled: true,
        ),
        AppLaunchMode.stageProfileFlow,
      );
      expect(
        resolveAppLaunchMode(
          stagePreviewEnabled: false,
          stageTaxonomyCheckEnabled: false,
          stageProfileFlowEnabled: false,
        ),
        AppLaunchMode.bandMatch,
      );
      expect(StageProfileFlowConfig.enabled, isFalse);
    },
  );

  test('profile flow contains no persistence or write RPC path', () {
    final sources = _readDartSources([
      'lib/stage_profile_flow',
      'lib/screens/stage_profile_taxonomy_selection_screen.dart',
      'lib/screens/stage_profile_taxonomy_summary_screen.dart',
      'lib/models/stage_profile_taxonomy_draft.dart',
    ]);

    expect(sources, contains('StageMasterDataService'));
    expect(sources, isNot(contains('replace_my_performance_roles_v1')));
    expect(sources, isNot(contains('.insert(')));
    expect(sources, isNot(contains('.update(')));
    expect(sources, isNot(contains('.delete(')));
    expect(sources, isNot(contains('service_role')));
    expect(sources, isNot(contains('保存する')));
  });

  test('existing Preview stays isolated and taxonomy check stays present', () {
    final previewSources = _readDartSources(['lib/stage_preview']);
    final mainSource = File('lib/main.dart').readAsStringSync();

    expect(previewSources, isNot(contains('StageMasterDataService')));
    expect(previewSources, isNot(contains('STAGE_PROFILE_FLOW')));
    expect(mainSource, contains('StagePreviewApp'));
    expect(mainSource, contains('StageTaxonomyCheckApp'));
    expect(mainSource, contains('StageProfileFlowApp'));
    expect(mainSource, contains('BandMatchApp'));
  });
}

String _readDartSources(List<String> paths) {
  final files = <File>[];
  for (final path in paths) {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.file) {
      files.add(File(path));
    } else if (type == FileSystemEntityType.directory) {
      files.addAll(
        Directory(path)
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart')),
      );
    }
  }
  return files.map((file) => file.readAsStringSync()).join('\n');
}

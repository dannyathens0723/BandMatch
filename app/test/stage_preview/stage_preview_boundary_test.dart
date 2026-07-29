import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preview source has no production service or Supabase imports', () {
    final previewDirectory = Directory('lib/stage_preview');
    expect(previewDirectory.existsSync(), isTrue);

    final violations = <String>[];
    for (final entity in previewDirectory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      const forbidden = [
        'supabase_flutter',
        'Supabase.instance',
        '/services/',
        '../services/',
        'package:app/services/',
        'master_data_service.dart',
        'MasterDataService',
        'package:app/models/',
        '../models/member_',
        '../models/profile_',
      ];
      for (final token in forbidden) {
        if (source.contains(token)) {
          violations.add('${entity.path}: $token');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test(
    'preview does not import or call the production master-data service',
    () {
      final previewDirectory = Directory('lib/stage_preview');
      final violations = previewDirectory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) {
            final source = file.readAsStringSync();
            return source.contains('master_data_service.dart') ||
                source.contains('MasterDataService') ||
                source.contains('fetchActiveMasterData');
          })
          .map((file) => file.path)
          .toList();

      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );

  test('preview entry branch occurs before Supabase initialization', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final previewBranch = mainSource.indexOf('StagePreviewConfig.enabled');
    final supabaseInitialization = mainSource.indexOf('Supabase.initialize');

    expect(previewBranch, greaterThanOrEqualTo(0));
    expect(supabaseInitialization, greaterThan(previewBranch));
  });

  test('go_router is isolated to the STAGE preview source', () {
    final previewApp = File(
      'lib/stage_preview/stage_preview_app.dart',
    ).readAsStringSync();
    final productionApp = File('lib/app.dart').readAsStringSync();

    expect(previewApp, contains('MaterialApp.router'));
    expect(productionApp, isNot(contains('go_router')));
    expect(productionApp, contains('MaterialApp('));
  });
}

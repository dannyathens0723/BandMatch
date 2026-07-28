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
        '/services/',
        '../services/',
        'package:app/services/',
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

  test('preview entry branch occurs before Supabase initialization', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final previewBranch = mainSource.indexOf('StagePreviewConfig.enabled');
    final supabaseInitialization = mainSource.indexOf('Supabase.initialize');

    expect(previewBranch, greaterThanOrEqualTo(0));
    expect(supabaseInitialization, greaterThan(previewBranch));
  });
}

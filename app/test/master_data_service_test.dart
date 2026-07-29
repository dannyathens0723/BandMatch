import 'dart:io';

import 'package:app/services/master_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('legacy selectable master data compatibility', () {
    late Map<String, MasterDataQuerySpec> capturedQueries;
    late MasterDataService service;

    setUp(() {
      capturedQueries = <String, MasterDataQuerySpec>{};
      final fixtures = <String, List<Map<String, dynamic>>>{
        'parts': [
          _row('part-guitar', 'guitar', 'Guitar', 20, isActive: true),
          _row('part-drums', 'drums', 'Drums', 10, isActive: true),
          _row('part-old', 'old_part', 'Old part', 5, isActive: false),
        ],
        'genres': [
          _row(
            'genre-rock',
            'rock',
            'Rock',
            20,
            isActive: true,
            domain: 'band',
          ),
          _row(
            'genre-jazz',
            'jazz',
            'Jazz',
            10,
            isActive: true,
            domain: 'band',
          ),
          _row(
            'genre-dance',
            'dance_kpop',
            'K-POP',
            5,
            isActive: true,
            domain: 'dance',
          ),
          _row(
            'genre-inactive-band',
            'inactive_band',
            'Inactive band',
            1,
            isActive: false,
            domain: 'band',
          ),
        ],
        'areas': [
          _row(
            'area-tokyo',
            'tokyo',
            'Tokyo',
            20,
            isActive: true,
            level: 'prefecture',
          ),
          _row(
            'area-osaka',
            'osaka',
            'Osaka',
            10,
            isActive: true,
            level: 'prefecture',
          ),
          _row(
            'area-old',
            'old_area',
            'Old area',
            5,
            isActive: false,
            level: 'prefecture',
          ),
        ],
      };

      service = MasterDataService(
        rowsFetcher: (query) async {
          capturedQueries[query.table] = query;
          final rows = fixtures[query.table]!
              .where(
                (row) => query.filters.entries.every(
                  (filter) => row[filter.key] == filter.value,
                ),
              )
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
          rows.sort(
            (left, right) => (left[query.orderColumn] as int).compareTo(
              right[query.orderColumn] as int,
            ),
          );
          return rows;
        },
      );
    });

    test('returns existing active Band genres', () async {
      final data = await service.fetchActiveMasterData();

      expect(
        data.genres.map((item) => item.code),
        containsAll(['jazz', 'rock']),
      );
      expect(capturedQueries['genres']!.filters, {
        'is_active': true,
        'domain': 'band',
      });
    });

    test('excludes active Dance genres', () async {
      final data = await service.fetchActiveMasterData();

      expect(
        data.genres.map((item) => item.code),
        isNot(contains('dance_kpop')),
      );
    });

    test('excludes inactive Band genres', () async {
      final data = await service.fetchActiveMasterData();

      expect(
        data.genres.map((item) => item.code),
        isNot(contains('inactive_band')),
      );
    });

    test('orders genres by sort_order', () async {
      final data = await service.fetchActiveMasterData();

      expect(data.genres.map((item) => item.code), ['jazz', 'rock']);
    });

    test('keeps the Parts query active-only and ordered', () async {
      final data = await service.fetchActiveMasterData();

      expect(capturedQueries['parts']!.filters, {'is_active': true});
      expect(data.parts.map((item) => item.code), ['drums', 'guitar']);
    });

    test('keeps the Areas query active-only and ordered', () async {
      final data = await service.fetchActiveMasterData();

      expect(capturedQueries['areas']!.filters, {'is_active': true});
      expect(data.areas.map((item) => item.code), ['osaka', 'tokyo']);
    });
  });

  group('legacy selectable genre consumers', () {
    test('profile setup and edit use the filtered master-data source', () {
      _expectMasterDataConsumer('lib/screens/profile_setup_screen.dart');
      _expectMasterDataConsumer('lib/screens/profile_edit_screen.dart');
    });

    test('group create and edit use the filtered master-data source', () {
      final source = _expectMasterDataConsumer(
        'lib/screens/group_edit_screen.dart',
      );

      expect(source, contains('widget.group'));
    });

    test('recruitment create and edit use the filtered master-data source', () {
      final source = _expectMasterDataConsumer(
        'lib/screens/recruitment_post_edit_screen.dart',
      );

      expect(source, contains('widget.post'));
    });

    test('member search filter uses the filtered master-data source', () {
      _expectMasterDataConsumer('lib/screens/member_list_screen.dart');
    });
  });
}

Map<String, dynamic> _row(
  String id,
  String code,
  String name,
  int sortOrder, {
  required bool isActive,
  String? domain,
  String? level,
}) {
  return {
    'id': id,
    'code': code,
    'name': name,
    'sort_order': sortOrder,
    'is_active': isActive,
    'domain': ?domain,
    'level': ?level,
  };
}

String _expectMasterDataConsumer(String path) {
  final source = File(path).readAsStringSync();
  expect(source, contains('master_data_service.dart'), reason: path);
  expect(source, contains('fetchActiveMasterData()'), reason: path);
  expect(source, contains('masterData.genres'), reason: path);
  return source;
}

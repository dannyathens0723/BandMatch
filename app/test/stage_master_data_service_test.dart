import 'dart:io';

import 'package:app/models/performance_domain.dart';
import 'package:app/models/stage_master_data.dart';
import 'package:app/services/stage_master_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PerformanceDomain', () {
    test('serializes the supported RPC domain values', () {
      expect(PerformanceDomain.band.rpcValue, 'band');
      expect(PerformanceDomain.dance.rpcValue, 'dance');
    });

    test('parses only band and dance', () {
      expect(PerformanceDomain.fromRpcValue('band'), PerformanceDomain.band);
      expect(PerformanceDomain.fromRpcValue('dance'), PerformanceDomain.dance);
      expect(
        () => PerformanceDomain.fromRpcValue('multi_domain'),
        throwsA(isA<UnsupportedPerformanceDomainException>()),
      );
    });
  });

  group('STAGE master-data models', () {
    test('parses the complete safe genre projection', () {
      final genre = StageGenre.fromJson(
        _genreRow(id: _genreIdA, code: 'dance_kpop', sortOrder: 20),
      );

      expect(genre.id, _genreIdA);
      expect(genre.code, 'dance_kpop');
      expect(genre.name, 'K-POP');
      expect(genre.domain, PerformanceDomain.dance);
      expect(genre.category, 'street');
      expect(genre.sortOrder, 20);
    });

    test('parses only the performance-role RPC projection', () {
      final role = StagePerformanceRole.fromJson({
        ..._roleRow(id: _roleIdA, code: 'dancer', sortOrder: 10),
        'part_id': 'legacy-part',
        'governance_role': 'admin',
        'professional_state': 'professional_unverified',
        'experience_level': 'advanced',
      });

      expect(role.id, _roleIdA);
      expect(role.code, 'dancer');
      expect(role.name, 'ダンサー');
      expect(role.domain, PerformanceDomain.dance);
      expect(role.sortOrder, 10);
    });

    test('rejects malformed required genre fields', () {
      expect(
        () => StageGenre.fromJson(
          _genreRow(id: 'not-a-uuid', code: 'dance_kpop', sortOrder: 10),
        ),
        throwsA(isA<StageMasterDataParseException>()),
      );
      expect(
        () => StageGenre.fromJson({
          ..._genreRow(id: _genreIdA, code: 'dance_kpop', sortOrder: 10),
          'category': '',
        }),
        throwsA(isA<StageMasterDataParseException>()),
      );
      expect(
        () => StageGenre.fromJson({
          ..._genreRow(id: _genreIdA, code: 'dance_kpop', sortOrder: 10),
          'sort_order': '10',
        }),
        throwsA(isA<StageMasterDataParseException>()),
      );
    });

    test('rejects malformed required performance-role fields', () {
      expect(
        () => StagePerformanceRole.fromJson({
          ..._roleRow(id: _roleIdA, code: 'dancer', sortOrder: 10),
          'name': null,
        }),
        throwsA(isA<StageMasterDataParseException>()),
      );
    });

    test('keeps unsupported response domains distinct from parse failures', () {
      expect(
        () => StageGenre.fromJson({
          ..._genreRow(id: _genreIdA, code: 'dance_kpop', sortOrder: 10),
          'domain': 'multi_domain',
        }),
        throwsA(isA<UnsupportedPerformanceDomainException>()),
      );
    });
  });

  group('StageMasterDataService genres', () {
    test('calls the versioned genre RPC with the selected domain', () async {
      String? functionName;
      Map<String, dynamic>? parameters;
      final service = StageMasterDataService(
        authenticationChecker: () => false,
        rpcFetcher: (calledFunction, calledParameters) async {
          functionName = calledFunction;
          parameters = calledParameters;
          return [_genreRow(id: _genreIdA, code: 'dance_kpop', sortOrder: 10)];
        },
      );

      final genres = await service.fetchActiveGenres(PerformanceDomain.dance);

      expect(functionName, 'get_active_genres_v1');
      expect(parameters, {'p_domain': 'dance'});
      expect(genres.single, isA<StageGenre>());
      expect(genres.single.domain, PerformanceDomain.dance);
    });

    test(
      'supports the band domain without using the legacy table query',
      () async {
        Map<String, dynamic>? parameters;
        final service = StageMasterDataService(
          rpcFetcher: (_, calledParameters) async {
            parameters = calledParameters;
            return [
              _genreRow(
                id: _genreIdA,
                code: 'rock',
                sortOrder: 10,
                domain: 'band',
                category: 'legacy_music',
                name: 'ロック',
              ),
            ];
          },
        );

        final genres = await service.fetchActiveGenres(PerformanceDomain.band);

        expect(parameters, {'p_domain': 'band'});
        expect(genres.single.domain, PerformanceDomain.band);
      },
    );

    test(
      'returns an immutable deterministic sort_order then code list',
      () async {
        final service = StageMasterDataService(
          rpcFetcher: (_, _) async => [
            _genreRow(id: _genreIdC, code: 'z_code', sortOrder: 20),
            _genreRow(id: _genreIdB, code: 'b_code', sortOrder: 10),
            _genreRow(id: _genreIdA, code: 'a_code', sortOrder: 10),
          ],
        );

        final genres = await service.fetchActiveGenres(PerformanceDomain.dance);

        expect(genres.map((genre) => genre.code), [
          'a_code',
          'b_code',
          'z_code',
        ]);
        expect(
          () => genres.add(
            StageGenre.fromJson(
              _genreRow(id: _genreIdA, code: 'other', sortOrder: 40),
            ),
          ),
          throwsUnsupportedError,
        );
      },
    );

    test('returns an empty list for a valid empty RPC result', () async {
      final service = StageMasterDataService(
        rpcFetcher: (_, _) async => <dynamic>[],
      );

      final genres = await service.fetchActiveGenres(PerformanceDomain.dance);

      expect(genres, isEmpty);
    });
  });

  group('StageMasterDataService performance roles', () {
    test('calls the authenticated role RPC with the selected domain', () async {
      String? functionName;
      Map<String, dynamic>? parameters;
      final service = StageMasterDataService(
        authenticationChecker: () => true,
        rpcFetcher: (calledFunction, calledParameters) async {
          functionName = calledFunction;
          parameters = calledParameters;
          return [_roleRow(id: _roleIdA, code: 'dancer', sortOrder: 10)];
        },
      );

      final roles = await service.fetchActivePerformanceRoles(
        PerformanceDomain.dance,
      );

      expect(functionName, 'get_active_performance_roles_v1');
      expect(parameters, {'p_domain': 'dance'});
      expect(roles.single, isA<StagePerformanceRole>());
      expect(roles.single.domain, PerformanceDomain.dance);
    });

    test(
      'rejects an unauthenticated role request before calling RPC',
      () async {
        var callCount = 0;
        final service = StageMasterDataService(
          authenticationChecker: () => false,
          rpcFetcher: (_, _) async {
            callCount++;
            return <dynamic>[];
          },
        );

        await expectLater(
          service.fetchActivePerformanceRoles(PerformanceDomain.dance),
          throwsA(isA<StageMasterDataAuthenticationException>()),
        );
        expect(callCount, 0);
      },
    );

    test('orders performance roles by sort_order then code', () async {
      final service = StageMasterDataService(
        authenticationChecker: () => true,
        rpcFetcher: (_, _) async => [
          _roleRow(id: _roleIdC, code: 'z_role', sortOrder: 20),
          _roleRow(id: _roleIdB, code: 'b_role', sortOrder: 10),
          _roleRow(id: _roleIdA, code: 'a_role', sortOrder: 10),
        ],
      );

      final roles = await service.fetchActivePerformanceRoles(
        PerformanceDomain.dance,
      );

      expect(roles.map((role) => role.code), ['a_role', 'b_role', 'z_role']);
    });
  });

  group('StageMasterDataService failures', () {
    test('wraps RPC and network failures in a distinct exception', () async {
      final cause = StateError('network unavailable');
      final service = StageMasterDataService(
        rpcFetcher: (_, _) async => throw cause,
      );

      await expectLater(
        service.fetchActiveGenres(PerformanceDomain.dance),
        throwsA(
          isA<StageMasterDataRpcException>()
              .having(
                (error) => error.functionName,
                'functionName',
                'get_active_genres_v1',
              )
              .having((error) => error.cause, 'cause', same(cause)),
        ),
      );
    });

    test('reports a malformed top-level response as a parse failure', () async {
      final service = StageMasterDataService(
        rpcFetcher: (_, _) async => {'unexpected': true},
      );

      await expectLater(
        service.fetchActiveGenres(PerformanceDomain.dance),
        throwsA(isA<StageMasterDataParseException>()),
      );
    });

    test('reports a malformed row as a parse failure', () async {
      final service = StageMasterDataService(
        rpcFetcher: (_, _) async => [
          _genreRow(id: _genreIdA, code: '', sortOrder: 10),
        ],
      );

      await expectLater(
        service.fetchActiveGenres(PerformanceDomain.dance),
        throwsA(isA<StageMasterDataParseException>()),
      );
    });
  });

  test(
    'Flutter production source contains no service-role credential path',
    () {
      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync().toLowerCase())
          .join('\n');

      expect(sources, isNot(contains('service_role')));
      expect(sources, isNot(contains('supabase_service_role')));
    },
  );
}

const _genreIdA = '11111111-1111-4111-8111-111111111111';
const _genreIdB = '22222222-2222-4222-8222-222222222222';
const _genreIdC = '33333333-3333-4333-8333-333333333333';
const _roleIdA = '44444444-4444-4444-8444-444444444444';
const _roleIdB = '55555555-5555-4555-8555-555555555555';
const _roleIdC = '66666666-6666-4666-8666-666666666666';

Map<String, dynamic> _genreRow({
  required String id,
  required String code,
  required int sortOrder,
  String name = 'K-POP',
  String domain = 'dance',
  String category = 'street',
}) {
  return {
    'id': id,
    'code': code,
    'name': name,
    'domain': domain,
    'category': category,
    'sort_order': sortOrder,
  };
}

Map<String, dynamic> _roleRow({
  required String id,
  required String code,
  required int sortOrder,
  String name = 'ダンサー',
  String domain = 'dance',
}) {
  return {
    'id': id,
    'code': code,
    'name': name,
    'domain': domain,
    'sort_order': sortOrder,
  };
}

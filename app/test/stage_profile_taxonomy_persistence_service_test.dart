import 'dart:io';

import 'package:app/models/performance_domain.dart';
import 'package:app/models/stage_profile_taxonomy_draft.dart';
import 'package:app/models/stage_profile_taxonomy_persistence_result.dart';
import 'package:app/services/stage_profile_taxonomy_persistence_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('StageProfileTaxonomyPersistenceResult unsaved state', () {
    test('parses and retains the complete no-saved contract', () {
      final result = StageProfileTaxonomyPersistenceResult.fromRpcRow(
        _resultRow(saved: false),
      );

      expect(result.domain, PerformanceDomain.dance);
      expect(result.hasSavedTaxonomy, isFalse);
      expect(result.genreIds, isEmpty);
      expect(result.roleIds, isEmpty);
      expect(result.primaryRoleId, isNull);
    });

    test('rejects genres in a no-saved result', () {
      expect(
        () => StageProfileTaxonomyPersistenceResult.fromRpcRow(
          _resultRow(saved: false, genreIds: [_genreIdA]),
        ),
        throwsA(isA<StageProfileTaxonomyPersistenceParseException>()),
      );
    });

    test('rejects roles in a no-saved result', () {
      expect(
        () => StageProfileTaxonomyPersistenceResult.fromRpcRow(
          _resultRow(saved: false, roleIds: [_roleIdA]),
        ),
        throwsA(isA<StageProfileTaxonomyPersistenceParseException>()),
      );
    });

    test('rejects a primary role in a no-saved result', () {
      expect(
        () => StageProfileTaxonomyPersistenceResult.fromRpcRow(
          _resultRow(saved: false, primaryRoleId: _roleIdA),
        ),
        throwsA(isA<StageProfileTaxonomyPersistenceParseException>()),
      );
    });
  });

  group('StageProfileTaxonomyPersistenceResult saved state', () {
    test('parses Dance and preserves immutable server ordering', () {
      final result = StageProfileTaxonomyPersistenceResult.fromRpcRow(
        _resultRow(
          genreIds: [_genreIdB, _genreIdA],
          roleIds: [_roleIdB, _roleIdA],
          primaryRoleId: _roleIdA,
        ),
      );

      expect(result.domain, PerformanceDomain.dance);
      expect(result.hasSavedTaxonomy, isTrue);
      expect(result.genreIds, [_genreIdB, _genreIdA]);
      expect(result.roleIds, [_roleIdB, _roleIdA]);
      expect(result.primaryRoleId, _roleIdA);
      expect(() => result.genreIds.add(_genreIdC), throwsUnsupportedError);
      expect(() => result.roleIds.clear(), throwsUnsupportedError);
    });

    test('rejects empty genres', () {
      expect(
        () => StageProfileTaxonomyPersistenceResult.fromRpcRow(
          _resultRow(genreIds: const []),
        ),
        throwsA(isA<StageProfileTaxonomyPersistenceParseException>()),
      );
    });

    test('rejects empty roles', () {
      expect(
        () => StageProfileTaxonomyPersistenceResult.fromRpcRow(
          _resultRow(roleIds: const [], primaryRoleId: null),
        ),
        throwsA(isA<StageProfileTaxonomyPersistenceParseException>()),
      );
    });

    test('rejects a null primary role', () {
      expect(
        () => StageProfileTaxonomyPersistenceResult.fromRpcRow(
          _resultRow(primaryRoleId: null),
        ),
        throwsA(isA<StageProfileTaxonomyPersistenceParseException>()),
      );
    });

    test('rejects a primary role outside selected roles', () {
      expect(
        () => StageProfileTaxonomyPersistenceResult.fromRpcRow(
          _resultRow(primaryRoleId: _roleIdB),
        ),
        throwsA(isA<StageProfileTaxonomyPersistenceParseException>()),
      );
    });

    test('rejects malformed genre, role, and primary UUIDs', () {
      for (final row in [
        _resultRow(genreIds: const ['bad-id']),
        _resultRow(roleIds: const ['bad-id'], primaryRoleId: 'bad-id'),
        _resultRow(primaryRoleId: 'bad-id'),
      ]) {
        expect(
          () => StageProfileTaxonomyPersistenceResult.fromRpcRow(row),
          throwsA(isA<StageProfileTaxonomyPersistenceParseException>()),
        );
      }
    });

    test('rejects unsupported Band and unknown domains', () {
      for (final domain in ['band', 'multi_domain']) {
        expect(
          () => StageProfileTaxonomyPersistenceResult.fromRpcRow(
            _resultRow(domain: domain),
          ),
          throwsA(isA<StageProfileTaxonomyPersistenceParseException>()),
        );
      }
    });
  });

  group('single-row response contract', () {
    test('accepts exactly one compatible row', () async {
      final result = await _service(
        response: [_resultRow(saved: false)],
      ).fetchMyStageTaxonomy(PerformanceDomain.dance);

      expect(result.hasSavedTaxonomy, isFalse);
    });

    test('rejects null and non-list responses', () async {
      for (final response in <dynamic>[
        null,
        {'unexpected': true},
        'bad',
      ]) {
        await expectLater(
          _service(
            response: response,
          ).fetchMyStageTaxonomy(PerformanceDomain.dance),
          throwsA(isA<StageProfileTaxonomyPersistenceParseException>()),
        );
      }
    });

    test('rejects zero and multiple rows', () async {
      for (final response in <dynamic>[
        <dynamic>[],
        [_resultRow(), _resultRow()],
      ]) {
        await expectLater(
          _service(
            response: response,
          ).fetchMyStageTaxonomy(PerformanceDomain.dance),
          throwsA(isA<StageProfileTaxonomyPersistenceParseException>()),
        );
      }
    });

    test('rejects a non-map row', () async {
      await expectLater(
        _service(
          response: const ['not-a-row'],
        ).fetchMyStageTaxonomy(PerformanceDomain.dance),
        throwsA(isA<StageProfileTaxonomyPersistenceParseException>()),
      );
    });

    test('rejects every missing required field', () async {
      for (final field in [
        'domain',
        'has_saved_taxonomy',
        'genre_ids',
        'role_ids',
        'primary_role_id',
      ]) {
        final row = _resultRow()..remove(field);
        await expectLater(
          _service(
            response: [row],
          ).fetchMyStageTaxonomy(PerformanceDomain.dance),
          throwsA(isA<StageProfileTaxonomyPersistenceParseException>()),
        );
      }
    });

    test('rejects incorrect scalar and array field types', () async {
      for (final row in [
        {..._resultRow(), 'has_saved_taxonomy': 'true'},
        {..._resultRow(), 'genre_ids': _genreIdA},
        {..._resultRow(), 'role_ids': <String, String>{}},
        {..._resultRow(), 'primary_role_id': 42},
      ]) {
        await expectLater(
          _service(
            response: [row],
          ).fetchMyStageTaxonomy(PerformanceDomain.dance),
          throwsA(isA<StageProfileTaxonomyPersistenceParseException>()),
        );
      }
    });
  });

  group('fetchMyStageTaxonomy', () {
    test('calls the exact read RPC and parameter map', () async {
      String? functionName;
      Map<String, dynamic>? parameters;
      final service = StageProfileTaxonomyPersistenceService(
        authenticationChecker: () => true,
        rpcFetcher: (calledFunction, calledParameters) async {
          functionName = calledFunction;
          parameters = calledParameters;
          return [_resultRow(saved: false)];
        },
      );

      await service.fetchMyStageTaxonomy(PerformanceDomain.dance);

      expect(functionName, 'get_my_stage_taxonomy_v1');
      expect(parameters, {'p_performance_domain': 'dance'});
    });

    test('rejects no session before invoking the RPC', () async {
      var calls = 0;
      final service = StageProfileTaxonomyPersistenceService(
        authenticationChecker: () => false,
        rpcFetcher: (_, _) async {
          calls++;
          return [_resultRow(saved: false)];
        },
      );

      await expectLater(
        service.fetchMyStageTaxonomy(PerformanceDomain.dance),
        throwsA(_failureKind(_FailureKind.authenticationRequired)),
      );
      expect(calls, 0);
    });

    test('rejects Band locally without invoking the RPC', () async {
      var calls = 0;
      final service = StageProfileTaxonomyPersistenceService(
        authenticationChecker: () => true,
        rpcFetcher: (_, _) async {
          calls++;
          return [_resultRow(saved: false)];
        },
      );

      await expectLater(
        service.fetchMyStageTaxonomy(PerformanceDomain.band),
        throwsA(_failureKind(_FailureKind.invalidLocalRequest)),
      );
      expect(calls, 0);
    });

    test('parses both no-saved and saved responses', () async {
      final noSaved = await _service(
        response: [_resultRow(saved: false)],
      ).fetchMyStageTaxonomy(PerformanceDomain.dance);
      final saved = await _service(
        response: [_resultRow()],
      ).fetchMyStageTaxonomy(PerformanceDomain.dance);

      expect(noSaved.hasSavedTaxonomy, isFalse);
      expect(saved.hasSavedTaxonomy, isTrue);
    });

    test(
      'keeps RPC failures distinct from response parsing failures',
      () async {
        final rpcService = StageProfileTaxonomyPersistenceService(
          authenticationChecker: () => true,
          rpcFetcher: (_, _) async => throw StateError('offline'),
        );
        final parseService = _service(response: null);

        await expectLater(
          rpcService.fetchMyStageTaxonomy(PerformanceDomain.dance),
          throwsA(_failureKind(_FailureKind.rpc)),
        );
        await expectLater(
          parseService.fetchMyStageTaxonomy(PerformanceDomain.dance),
          throwsA(isA<StageProfileTaxonomyPersistenceParseException>()),
        );
      },
    );
  });

  group('replaceMyStageTaxonomy', () {
    test('calls the exact write RPC and preserves draft ordering', () async {
      String? functionName;
      Map<String, dynamic>? parameters;
      final draft = StageProfileTaxonomyDraft(
        selectedGenreIds: [_genreIdB, _genreIdA],
        selectedRoleIds: [_roleIdB, _roleIdA],
        primaryRoleId: _roleIdA,
      );
      final service = StageProfileTaxonomyPersistenceService(
        authenticationChecker: () => true,
        rpcFetcher: (calledFunction, calledParameters) async {
          functionName = calledFunction;
          parameters = calledParameters;
          return [
            _resultRow(
              genreIds: [_genreIdB, _genreIdA],
              roleIds: [_roleIdB, _roleIdA],
              primaryRoleId: _roleIdA,
            ),
          ];
        },
      );

      final result = await service.replaceMyStageTaxonomy(
        domain: PerformanceDomain.dance,
        draft: draft,
      );

      expect(functionName, 'replace_my_stage_taxonomy_v1');
      expect(parameters, {
        'p_performance_domain': 'dance',
        'p_genre_ids': [_genreIdB, _genreIdA],
        'p_role_ids': [_roleIdB, _roleIdA],
        'p_primary_role_id': _roleIdA,
      });
      expect(parameters, isNot(containsPair('p_user_id', anything)));
      expect(parameters, isNot(containsPair('p_auth_uid', anything)));
      expect(result.genreIds, [_genreIdB, _genreIdA]);
    });

    test('rejects no session before validating or invoking the RPC', () async {
      var calls = 0;
      final service = StageProfileTaxonomyPersistenceService(
        authenticationChecker: () => false,
        rpcFetcher: (_, _) async {
          calls++;
          return [_resultRow()];
        },
      );

      await expectLater(
        service.replaceMyStageTaxonomy(
          domain: PerformanceDomain.dance,
          draft: _validDraft(),
        ),
        throwsA(_failureKind(_FailureKind.authenticationRequired)),
      );
      expect(calls, 0);
    });

    test('rejects empty genres and roles locally without RPC', () async {
      for (final draft in [
        StageProfileTaxonomyDraft(
          selectedGenreIds: const [],
          selectedRoleIds: const [_roleIdA],
          primaryRoleId: _roleIdA,
        ),
        StageProfileTaxonomyDraft(
          selectedGenreIds: const [_genreIdA],
          selectedRoleIds: const [],
          primaryRoleId: _roleIdA,
        ),
      ]) {
        var calls = 0;
        final service = StageProfileTaxonomyPersistenceService(
          authenticationChecker: () => true,
          rpcFetcher: (_, _) async {
            calls++;
            return [_resultRow()];
          },
        );

        await expectLater(
          service.replaceMyStageTaxonomy(
            domain: PerformanceDomain.dance,
            draft: draft,
          ),
          throwsA(_failureKind(_FailureKind.invalidLocalRequest)),
        );
        expect(calls, 0);
      }
    });

    test('rejects duplicate genre and role IDs locally without RPC', () async {
      for (final draft in [
        StageProfileTaxonomyDraft(
          selectedGenreIds: const [_genreIdA, _genreIdA],
          selectedRoleIds: const [_roleIdA],
          primaryRoleId: _roleIdA,
        ),
        StageProfileTaxonomyDraft(
          selectedGenreIds: const [_genreIdA],
          selectedRoleIds: const [_roleIdA, _roleIdA],
          primaryRoleId: _roleIdA,
        ),
      ]) {
        var calls = 0;
        final service = StageProfileTaxonomyPersistenceService(
          authenticationChecker: () => true,
          rpcFetcher: (_, _) async {
            calls++;
            return [_resultRow()];
          },
        );

        await expectLater(
          service.replaceMyStageTaxonomy(
            domain: PerformanceDomain.dance,
            draft: draft,
          ),
          throwsA(_failureKind(_FailureKind.invalidLocalRequest)),
        );
        expect(calls, 0);
      }
    });

    test('rejects malformed IDs and an unselected primary locally', () async {
      for (final draft in [
        StageProfileTaxonomyDraft(
          selectedGenreIds: const ['bad-id'],
          selectedRoleIds: const [_roleIdA],
          primaryRoleId: _roleIdA,
        ),
        StageProfileTaxonomyDraft(
          selectedGenreIds: const [_genreIdA],
          selectedRoleIds: const ['bad-id'],
          primaryRoleId: 'bad-id',
        ),
        StageProfileTaxonomyDraft(
          selectedGenreIds: const [_genreIdA],
          selectedRoleIds: const [_roleIdA],
          primaryRoleId: _roleIdB,
        ),
      ]) {
        await expectLater(
          _service(response: [_resultRow()]).replaceMyStageTaxonomy(
            domain: PerformanceDomain.dance,
            draft: draft,
          ),
          throwsA(_failureKind(_FailureKind.invalidLocalRequest)),
        );
      }
    });

    test('rejects an unsupported domain locally without RPC', () async {
      var calls = 0;
      final service = StageProfileTaxonomyPersistenceService(
        authenticationChecker: () => true,
        rpcFetcher: (_, _) async {
          calls++;
          return [_resultRow()];
        },
      );

      await expectLater(
        service.replaceMyStageTaxonomy(
          domain: PerformanceDomain.band,
          draft: _validDraft(),
        ),
        throwsA(_failureKind(_FailureKind.invalidLocalRequest)),
      );
      expect(calls, 0);
    });
  });

  group('PostgREST failure mapping', () {
    test('maps the supported SQLSTATE categories', () async {
      final cases = <({String code, String message, _FailureKind expected})>[
        (
          code: '28000',
          message: 'sign in is required',
          expected: _FailureKind.authenticationRequired,
        ),
        (
          code: '22004',
          message: 'genre IDs are required',
          expected: _FailureKind.serverInputContract,
        ),
        (
          code: '22023',
          message: 'duplicate genre ID',
          expected: _FailureKind.rejectedTaxonomyInput,
        ),
        (
          code: '22023',
          message: 'requested genre is missing, inactive, or not Dance',
          expected: _FailureKind.invalidTaxonomyIdentifier,
        ),
        (
          code: '55000',
          message: 'active profile is required',
          expected: _FailureKind.profileState,
        ),
        (
          code: '55000',
          message: 'stored STAGE taxonomy state is inconsistent',
          expected: _FailureKind.storedTaxonomyInconsistency,
        ),
        (
          code: '55000',
          message: 'stored non-Dance primary role is incompatible',
          expected: _FailureKind.primaryRoleConflict,
        ),
        (
          code: '55000',
          message: 'saved STAGE taxonomy state does not match the request',
          expected: _FailureKind.postWriteStateConflict,
        ),
      ];

      for (final testCase in cases) {
        final service = StageProfileTaxonomyPersistenceService(
          authenticationChecker: () => true,
          rpcFetcher: (_, _) async => throw PostgrestException(
            message: testCase.message,
            code: testCase.code,
          ),
        );

        await expectLater(
          service.fetchMyStageTaxonomy(PerformanceDomain.dance),
          throwsA(_failureKind(testCase.expected)),
        );
      }
    });

    test(
      'maps unknown PostgREST and network failures to RPC failure',
      () async {
        final causes = <Object>[
          const PostgrestException(message: 'unknown', code: 'PGRST999'),
          StateError('network unavailable'),
        ];
        for (final cause in causes) {
          final service = StageProfileTaxonomyPersistenceService(
            authenticationChecker: () => true,
            rpcFetcher: (_, _) async => throw cause,
          );
          await expectLater(
            service.fetchMyStageTaxonomy(PerformanceDomain.dance),
            throwsA(_failureKind(_FailureKind.rpc)),
          );
        }
      },
    );

    test('never uses raw database messages as user-facing text', () async {
      const rawMessage = 'internal database row detail';
      final service = StageProfileTaxonomyPersistenceService(
        authenticationChecker: () => true,
        rpcFetcher: (_, _) async =>
            throw const PostgrestException(message: rawMessage, code: '55000'),
      );

      try {
        await service.fetchMyStageTaxonomy(PerformanceDomain.dance);
        fail('Expected a mapped exception');
      } on StageProfileTaxonomyPersistenceException catch (error) {
        expect(error.userMessage, isNot(contains(rawMessage)));
        expect(error.toString(), isNot(contains(rawMessage)));
      }
    });
  });

  test(
    'production persistence source stays inside the RPC security boundary',
    () {
      final source = File(
        'lib/services/stage_profile_taxonomy_persistence_service.dart',
      ).readAsStringSync();
      final sensitiveCredentialName = ['service', 'role'].join('_');
      final forbiddenDirectTables = [
        ['user', 's'].join(),
        ['user', 'genres'].join('_'),
        ['user', 'performance', 'roles'].join('_'),
      ];

      expect(source.toLowerCase(), isNot(contains(sensitiveCredentialName)));
      for (final table in forbiddenDirectTables) {
        expect(source, isNot(contains(".from('$table')")));
      }
      expect(source, isNot(contains('.insert(')));
      expect(source, isNot(contains('.update(')));
      expect(source, isNot(contains('.delete(')));
      expect(source, isNot(contains('replace_my_performance_roles_v1')));
      expect(source, isNot(contains('p_user_id')));
      expect(source, isNot(contains('p_auth_uid')));
    },
  );
}

typedef _FailureKind = StageProfileTaxonomyPersistenceFailureKind;

Matcher _failureKind(_FailureKind kind) {
  return isA<StageProfileTaxonomyPersistenceException>().having(
    (error) => error.kind,
    'kind',
    kind,
  );
}

StageProfileTaxonomyPersistenceService _service({required dynamic response}) {
  return StageProfileTaxonomyPersistenceService(
    authenticationChecker: () => true,
    rpcFetcher: (_, _) async => response,
  );
}

StageProfileTaxonomyDraft _validDraft() {
  return StageProfileTaxonomyDraft(
    selectedGenreIds: const [_genreIdA],
    selectedRoleIds: const [_roleIdA],
    primaryRoleId: _roleIdA,
  );
}

Map<String, dynamic> _resultRow({
  bool saved = true,
  String domain = 'dance',
  List<dynamic>? genreIds,
  List<dynamic>? roleIds,
  Object? primaryRoleId = _defaultPrimary,
}) {
  return {
    'domain': domain,
    'has_saved_taxonomy': saved,
    'genre_ids': genreIds ?? (saved ? [_genreIdA] : <String>[]),
    'role_ids': roleIds ?? (saved ? [_roleIdA] : <String>[]),
    'primary_role_id': identical(primaryRoleId, _defaultPrimary)
        ? (saved ? _roleIdA : null)
        : primaryRoleId,
  };
}

const _defaultPrimary = Object();
const _genreIdA = '11111111-1111-4111-8111-111111111111';
const _genreIdB = '22222222-2222-4222-8222-222222222222';
const _genreIdC = '33333333-3333-4333-8333-333333333333';
const _roleIdA = '44444444-4444-4444-8444-444444444444';
const _roleIdB = '55555555-5555-4555-8555-555555555555';

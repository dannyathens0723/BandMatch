import 'dart:async';

import 'package:app/screens/stage_profile_taxonomy_selection_screen.dart';
import 'package:app/services/stage_profile_taxonomy_persistence_service.dart';
import 'package:app/stage_preview/theme/stage_design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'stage_profile_test_data.dart';

void main() {
  group('STAGE taxonomy persistence initialization', () {
    testWidgets('no-saved result initializes an empty selection once', (
      tester,
    ) async {
      var readCalls = 0;
      final persistence = fakeStagePersistenceService(
        fetcher: (functionName, parameters) async {
          expect(functionName, 'get_my_stage_taxonomy_v1');
          expect(parameters, {'p_performance_domain': 'dance'});
          readCalls++;
          return [stageTaxonomyResultRow(saved: false)];
        },
      );

      await _pumpLoaded(tester, persistence);
      await tester.pump();

      expect(readCalls, 1);
      expect(_genreChip(tester, 1).selected, isFalse);
      expect(_roleChip(tester, 101).selected, isFalse);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('saved result restores genres, roles, and primary role', (
      tester,
    ) async {
      final persistence = fakeStagePersistenceService(
        fetcher: (_, _) async => [
          stageTaxonomyResultRow(
            genreIds: [testUuid(2), testUuid(1)],
            roleIds: [testUuid(102), testUuid(101)],
            primaryRoleId: testUuid(102),
          ),
        ],
      );

      await _pumpLoaded(tester, persistence);

      expect(_genreChip(tester, 1).selected, isTrue);
      expect(_genreChip(tester, 2).selected, isTrue);
      expect(_roleChip(tester, 101).selected, isTrue);
      expect(_roleChip(tester, 102).selected, isTrue);
      expect(_primaryChip(tester, 102).selected, isTrue);
    });

    testWidgets('initialization blocks Continue and does not duplicate reads', (
      tester,
    ) async {
      final readCompleter = Completer<dynamic>();
      var readCalls = 0;
      final persistence = fakeStagePersistenceService(
        fetcher: (_, _) {
          readCalls++;
          return readCompleter.future;
        },
      );

      await _pump(tester, persistence);
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(
          const ValueKey('profile-taxonomy-persistence-loading'),
        ),
        findsOneWidget,
      );
      expect(_continueButton(tester).onPressed, isNull);
      expect(readCalls, 1);

      readCompleter.complete([stageTaxonomyResultRow(saved: false)]);
      await tester.pumpAndSettle();
      expect(_continueButton(tester).onPressed, isNotNull);
    });

    testWidgets('unavailable persisted IDs block unsafe overwrite', (
      tester,
    ) async {
      var writeCalls = 0;
      final persistence = fakeStagePersistenceService(
        fetcher: (functionName, _) async {
          if (functionName == 'replace_my_stage_taxonomy_v1') writeCalls++;
          return [
            stageTaxonomyResultRow(
              genreIds: [testUuid(999)],
              roleIds: [testUuid(101)],
              primaryRoleId: testUuid(101),
            ),
          ];
        },
      );

      await _pumpLoaded(tester, persistence);

      expect(
        find.byKey(const ValueKey('profile-taxonomy-persistence-error')),
        findsOneWidget,
      );
      expect(_continueButton(tester).onPressed, isNull);
      expect(writeCalls, 0);
    });
  });

  group('STAGE taxonomy persistence save', () {
    testWidgets('save preserves restored server ordering in exact RPC params', (
      tester,
    ) async {
      Map<String, dynamic>? writeParameters;
      final persistence = fakeStagePersistenceService(
        fetcher: (functionName, parameters) async {
          final savedRow = stageTaxonomyResultRow(
            genreIds: [testUuid(2), testUuid(1)],
            roleIds: [testUuid(102), testUuid(101)],
            primaryRoleId: testUuid(102),
          );
          if (functionName == 'replace_my_stage_taxonomy_v1') {
            writeParameters = Map<String, dynamic>.from(parameters);
          }
          return [savedRow];
        },
      );

      await _pumpLoaded(tester, persistence);
      await _openSummary(tester);
      _pressSave(tester);
      await tester.pumpAndSettle();

      expect(writeParameters, {
        'p_performance_domain': 'dance',
        'p_genre_ids': [testUuid(2), testUuid(1)],
        'p_role_ids': [testUuid(102), testUuid(101)],
        'p_primary_role_id': testUuid(102),
      });
      expect(
        find.byKey(const ValueKey('taxonomy-summary-save-success')),
        findsOneWidget,
      );
    });

    testWidgets('persisted write result becomes summary and screen authority', (
      tester,
    ) async {
      final persistence = fakeStagePersistenceService(
        fetcher: (functionName, _) async => [
          functionName == 'get_my_stage_taxonomy_v1'
              ? stageTaxonomyResultRow(saved: false)
              : stageTaxonomyResultRow(
                  genreIds: [testUuid(2)],
                  roleIds: [testUuid(102)],
                  primaryRoleId: testUuid(102),
                ),
        ],
      );

      await _pumpLoaded(tester, persistence);
      _toggleGenre(tester, 1);
      _toggleGenre(tester, 2);
      _toggleRole(tester, 101);
      _toggleRole(tester, 102);
      await tester.pump();
      await _openSummary(tester);

      _pressSave(tester);
      await tester.pumpAndSettle();
      expect(find.text(genreNames[1]), findsOneWidget);
      expect(find.text(genreNames[0]), findsNothing);
      expect(find.text(roleNames[1]), findsNWidgets(2));

      _pressBack(tester);
      await tester.pumpAndSettle();
      expect(_genreChip(tester, 1).selected, isFalse);
      expect(_genreChip(tester, 2).selected, isTrue);
      expect(_roleChip(tester, 101).selected, isFalse);
      expect(_roleChip(tester, 102).selected, isTrue);
      expect(_primaryChip(tester, 102).selected, isTrue);
    });

    testWidgets('in-flight save disables duplicate submissions', (
      tester,
    ) async {
      final saveCompleter = Completer<dynamic>();
      var writeCalls = 0;
      final persistence = fakeStagePersistenceService(
        fetcher: (functionName, _) async {
          if (functionName == 'get_my_stage_taxonomy_v1') {
            return [stageTaxonomyResultRow(saved: false)];
          }
          writeCalls++;
          return saveCompleter.future;
        },
      );

      await _pumpLoaded(tester, persistence);
      _toggleGenre(tester, 1);
      _toggleRole(tester, 101);
      await tester.pump();
      await _openSummary(tester);

      _pressSave(tester);
      await tester.pump();
      expect(_saveButton(tester).onPressed, isNull);
      expect(writeCalls, 1);

      saveCompleter.complete([stageTaxonomyResultRow()]);
      await tester.pumpAndSettle();
      expect(writeCalls, 1);
      expect(_saveButton(tester).onPressed, isNotNull);
    });
  });

  group('STAGE taxonomy persistence safe errors', () {
    testWidgets('authentication failure is safe and does not call RPC', (
      tester,
    ) async {
      var calls = 0;
      final persistence = fakeStagePersistenceService(
        authenticated: false,
        fetcher: (_, _) async {
          calls++;
          return [stageTaxonomyResultRow(saved: false)];
        },
      );

      await _pumpLoaded(tester, persistence);

      expect(calls, 0);
      expect(
        find.byKey(const ValueKey('profile-taxonomy-persistence-error')),
        findsOneWidget,
      );
      expect(find.textContaining('28000'), findsNothing);
      expect(_continueButton(tester).onPressed, isNull);
    });

    testWidgets('RPC and parsing failures show controlled load errors', (
      tester,
    ) async {
      final services = [
        fakeStagePersistenceService(
          fetcher: (_, _) async => throw const PostgrestException(
            message: 'private database detail',
            code: 'PGRST999',
          ),
        ),
        fakeStagePersistenceService(fetcher: (_, _) async => {'bad': true}),
      ];

      for (final persistence in services) {
        await _pumpLoaded(tester, persistence);
        expect(
          find.byKey(const ValueKey('profile-taxonomy-persistence-error')),
          findsOneWidget,
        );
        expect(find.textContaining('private database detail'), findsNothing);
        expect(_continueButton(tester).onPressed, isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('save rejection stays on summary with a safe error', (
      tester,
    ) async {
      final persistence = fakeStagePersistenceService(
        fetcher: (functionName, _) async {
          if (functionName == 'get_my_stage_taxonomy_v1') {
            return [stageTaxonomyResultRow(saved: false)];
          }
          throw const PostgrestException(
            message: 'requested genre is missing, inactive, or not Dance',
            code: '22023',
          );
        },
      );

      await _pumpLoaded(tester, persistence);
      _toggleGenre(tester, 1);
      _toggleRole(tester, 101);
      await tester.pump();
      await _openSummary(tester);
      _pressSave(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('taxonomy-summary-save-error')),
        findsOneWidget,
      );
      expect(find.textContaining('22023'), findsNothing);
      expect(find.textContaining('requested genre'), findsNothing);
      expect(
        find.byKey(const ValueKey('taxonomy-summary-save')),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpLoaded(
  WidgetTester tester,
  StageProfileTaxonomyPersistenceService persistence,
) async {
  await _pump(tester, persistence);
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  StageProfileTaxonomyPersistenceService persistence,
) {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final master = fakeStageService(
    fetcher: (functionName, _) async =>
        functionName == 'get_active_genres_v1' ? genreRows() : roleRows(),
  );
  return tester.pumpWidget(
    MaterialApp(
      theme: StageDesignTokens.theme,
      home: StageProfileTaxonomySelectionScreen(
        service: master,
        persistenceService: persistence,
      ),
    ),
  );
}

Future<void> _openSummary(WidgetTester tester) async {
  _continueButton(tester).onPressed!();
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('taxonomy-summary-save')),
    findsOneWidget,
  );
}

FilterChip _genreChip(WidgetTester tester, int value) {
  return tester.widget<FilterChip>(
    find.byKey(ValueKey('genre-${testUuid(value)}')),
  );
}

FilterChip _roleChip(WidgetTester tester, int value) {
  return tester.widget<FilterChip>(
    find.byKey(ValueKey('role-${testUuid(value)}')),
  );
}

ChoiceChip _primaryChip(WidgetTester tester, int value) {
  return tester.widget<ChoiceChip>(
    find.byKey(ValueKey('primary-role-${testUuid(value)}')),
  );
}

void _toggleGenre(WidgetTester tester, int value) {
  final chip = _genreChip(tester, value);
  chip.onSelected!(!chip.selected);
}

void _toggleRole(WidgetTester tester, int value) {
  final chip = _roleChip(tester, value);
  chip.onSelected!(!chip.selected);
}

FilledButton _continueButton(WidgetTester tester) {
  return tester.widget<FilledButton>(
    find.descendant(
      of: find.byKey(const ValueKey('profile-taxonomy-continue')),
      matching: find.byType(FilledButton),
    ),
  );
}

FilledButton _saveButton(WidgetTester tester) {
  return tester.widget<FilledButton>(
    find.descendant(
      of: find.byKey(const ValueKey('taxonomy-summary-save')),
      matching: find.byType(FilledButton),
    ),
  );
}

void _pressSave(WidgetTester tester) {
  _saveButton(tester).onPressed!();
}

void _pressBack(WidgetTester tester) {
  tester
      .widget<OutlinedButton>(
        find.descendant(
          of: find.byKey(const ValueKey('taxonomy-summary-back')),
          matching: find.byType(OutlinedButton),
        ),
      )
      .onPressed!();
}

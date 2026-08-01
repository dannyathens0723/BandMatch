import 'dart:async';

import 'package:app/screens/stage_profile_taxonomy_selection_screen.dart';
import 'package:app/services/stage_master_data_service.dart';
import 'package:app/stage_preview/theme/stage_design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stage_profile_test_data.dart';

void main() {
  group('loading and remote states', () {
    testWidgets('renders independent loading states', (tester) async {
      final genres = Completer<dynamic>();
      final roles = Completer<dynamic>();
      final service = fakeStageService(
        fetcher: (functionName, _) => functionName == 'get_active_genres_v1'
            ? genres.future
            : roles.future,
      );

      await _pumpScreen(tester, service, physicalSize: const Size(1600, 900));

      expect(find.text('読み込み中…'), findsNWidgets(2));
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      _expectVisibleNonZero(tester, find.text('プロフィール設定'));
      _expectVisibleNonZero(tester, find.text('ダンスジャンル'));
      _expectVisibleNonZero(tester, find.text('役割'));
      _expectVisibleNonZero(tester, _continueButtonFinder());

      genres.complete(genreRows());
      roles.complete(roleRows());
      await tester.pumpAndSettle();
    });

    testWidgets('renders all 11 service genres', (tester) async {
      await _pumpLoadedScreen(tester);

      for (final name in genreNames) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.byType(FilterChip), findsNWidgets(15));
    });

    testWidgets('renders all 4 service roles', (tester) async {
      await _pumpLoadedScreen(tester);

      for (final name in roleNames) {
        expect(find.text(name), findsOneWidget);
      }
    });

    testWidgets('mobile layout keeps body visible and scroll-reachable', (
      tester,
    ) async {
      final service = fakeStageService(
        fetcher: (functionName, _) async =>
            functionName == 'get_active_genres_v1' ? genreRows() : roleRows(),
      );

      await _pumpScreenAndSettle(
        tester,
        service,
        physicalSize: const Size(390, 844),
      );

      _expectVisibleNonZero(tester, find.text('プロフィール設定'));
      _expectVisibleNonZero(tester, find.text('ダンスジャンル'));
      _expectVisibleNonZero(tester, _continueButtonFinder());
      expect(
        tester
            .getSize(find.byKey(const ValueKey('profile-taxonomy-scroll')))
            .height,
        greaterThan(0),
      );

      await tester.scrollUntilVisible(
        find.text('役割'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      _expectVisibleNonZero(tester, find.text('役割'));
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        greaterThan(0),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'desktop body and action bar have bounded visible render boxes',
      (tester) async {
        final service = fakeStageService(
          fetcher: (functionName, _) async =>
              functionName == 'get_active_genres_v1' ? genreRows() : roleRows(),
        );

        await _pumpScreenAndSettle(
          tester,
          service,
          physicalSize: const Size(1600, 900),
        );

        _expectVisibleNonZero(tester, find.text('プロフィール設定'));
        _expectVisibleNonZero(tester, find.text('ダンスジャンル'));
        _expectVisibleNonZero(tester, find.text('役割'));
        _expectVisibleNonZero(tester, _continueButtonFinder());
        _expectVisibleNonZero(tester, find.text(genreNames.first));
        _expectVisibleNonZero(tester, find.text(roleNames.first));

        final bodySize = tester.getSize(
          find.byKey(const ValueKey('profile-taxonomy-scroll')),
        );
        final actionBarSize = tester.getSize(
          find.byKey(const ValueKey('profile-taxonomy-action-bar')),
        );
        expect(bodySize.height, greaterThan(300));
        expect(actionBarSize.height, inInclusiveRange(48, 120));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('shows a distinct empty genre state', (tester) async {
      final service = fakeStageService(
        fetcher: (functionName, _) async =>
            functionName == 'get_active_genres_v1' ? [] : roleRows(),
      );

      await _pumpScreenAndSettle(tester, service);

      expect(find.text('選択できるダンスジャンルがありません'), findsOneWidget);
      expect(find.text(roleNames.first), findsOneWidget);
    });

    testWidgets('shows a distinct empty role state', (tester) async {
      final service = fakeStageService(
        fetcher: (functionName, _) async =>
            functionName == 'get_active_genres_v1' ? genreRows() : [],
      );

      await _pumpScreenAndSettle(tester, service);

      expect(find.text('選択できる役割がありません'), findsOneWidget);
      expect(find.text(genreNames.first), findsOneWidget);
    });

    testWidgets('shows controlled unauthenticated role state with genres', (
      tester,
    ) async {
      final service = fakeStageService(
        authenticated: false,
        fetcher: (_, _) async => genreRows(),
      );

      await _pumpScreenAndSettle(tester, service);

      _expectVisibleNonZero(tester, find.text('プロフィール設定'));
      _expectVisibleNonZero(tester, find.text(genreNames.first));
      await tester.scrollUntilVisible(
        find.text('役割を選択するにはログインが必要です'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      _expectVisibleNonZero(tester, find.text('役割を選択するにはログインが必要です'));
      _expectVisibleNonZero(tester, _continueButtonFinder());
      expect(_continueButton(tester).onPressed, isNull);
    });

    testWidgets('genre RPC failure does not hide roles', (tester) async {
      final service = fakeStageService(
        fetcher: (functionName, _) async {
          if (functionName == 'get_active_genres_v1') {
            throw StateError('genre RPC failed');
          }
          return roleRows();
        },
      );

      await _pumpScreenAndSettle(tester, service);

      expect(find.text(_friendlyLoadError), findsOneWidget);
      expect(find.text(roleNames.first), findsOneWidget);
    });

    testWidgets('role RPC failure does not hide genres', (tester) async {
      final service = fakeStageService(
        fetcher: (functionName, _) async {
          if (functionName == 'get_active_performance_roles_v1') {
            throw StateError('role RPC failed');
          }
          return genreRows();
        },
      );

      await _pumpScreenAndSettle(tester, service);

      expect(find.text(_friendlyLoadError), findsOneWidget);
      expect(find.text(genreNames.first), findsOneWidget);
    });

    testWidgets('schema failure is controlled and does not expose raw data', (
      tester,
    ) async {
      final service = fakeStageService(
        fetcher: (functionName, _) async =>
            functionName == 'get_active_genres_v1'
            ? [
                {'id': 'not-a-uuid'},
              ]
            : roleRows(),
      );

      await _pumpScreenAndSettle(tester, service);

      expect(find.text('データ形式を確認できませんでした。'), findsOneWidget);
      expect(find.textContaining('not-a-uuid'), findsNothing);
      expect(find.text(roleNames.first), findsOneWidget);
    });

    testWidgets('genre retry reloads only the genre section', (tester) async {
      var genreCalls = 0;
      var roleCalls = 0;
      final service = fakeStageService(
        fetcher: (functionName, _) async {
          if (functionName == 'get_active_genres_v1') {
            genreCalls++;
            if (genreCalls == 1) throw StateError('temporary');
            return genreRows();
          }
          roleCalls++;
          return roleRows();
        },
      );

      await _pumpScreenAndSettle(tester, service);
      _pressOutlinedButton(
        tester,
        find.byKey(const ValueKey('profile-genre-retry')),
      );
      await tester.pumpAndSettle();

      expect(genreCalls, 2);
      expect(roleCalls, 1);
      expect(find.text(genreNames.first), findsOneWidget);
    });

    testWidgets('role retry reloads only the role section', (tester) async {
      var genreCalls = 0;
      var roleCalls = 0;
      final service = fakeStageService(
        fetcher: (functionName, _) async {
          if (functionName == 'get_active_performance_roles_v1') {
            roleCalls++;
            if (roleCalls == 1) throw StateError('temporary');
            return roleRows();
          }
          genreCalls++;
          return genreRows();
        },
      );

      await _pumpScreenAndSettle(tester, service);
      final retry = find.byKey(const ValueKey('profile-role-retry'));
      _pressOutlinedButton(tester, retry);
      await tester.pumpAndSettle();

      expect(genreCalls, 1);
      expect(roleCalls, 2);
      expect(find.text(roleNames.first), findsOneWidget);
    });
  });

  group('selection, validation, and summary', () {
    testWidgets('selects, multi-selects, and deselects genres', (tester) async {
      await _pumpLoadedScreen(tester);
      final first = find.byKey(ValueKey('genre-${testUuid(1)}'));
      final second = find.byKey(ValueKey('genre-${testUuid(2)}'));

      _toggleFilterChip(tester, first);
      _toggleFilterChip(tester, second);
      await tester.pump();
      expect(tester.widget<FilterChip>(first).selected, isTrue);
      expect(tester.widget<FilterChip>(second).selected, isTrue);

      _toggleFilterChip(tester, first);
      await tester.pump();
      expect(tester.widget<FilterChip>(first).selected, isFalse);
      expect(tester.widget<FilterChip>(second).selected, isTrue);
    });

    testWidgets('first role is primary and primary can change', (tester) async {
      await _pumpLoadedScreen(tester);
      final firstRole = find.byKey(ValueKey('role-${testUuid(101)}'));
      final secondRole = find.byKey(ValueKey('role-${testUuid(102)}'));

      _toggleFilterChip(tester, firstRole);
      _toggleFilterChip(tester, secondRole);
      await tester.pump();

      final firstPrimary = find.byKey(
        ValueKey('primary-role-${testUuid(101)}'),
      );
      final secondPrimary = find.byKey(
        ValueKey('primary-role-${testUuid(102)}'),
      );
      expect(tester.widget<ChoiceChip>(firstPrimary).selected, isTrue);
      _selectChoiceChip(tester, secondPrimary);
      await tester.pump();
      expect(tester.widget<ChoiceChip>(secondPrimary).selected, isTrue);
    });

    testWidgets('deselecting primary deterministically promotes next role', (
      tester,
    ) async {
      await _pumpLoadedScreen(tester);
      final firstRole = find.byKey(ValueKey('role-${testUuid(101)}'));
      final secondRole = find.byKey(ValueKey('role-${testUuid(102)}'));
      _toggleFilterChip(tester, firstRole);
      _toggleFilterChip(tester, secondRole);
      _toggleFilterChip(tester, firstRole);
      await tester.pump();

      final secondPrimary = find.byKey(
        ValueKey('primary-role-${testUuid(102)}'),
      );
      expect(tester.widget<ChoiceChip>(secondPrimary).selected, isTrue);
      expect(
        find.byKey(ValueKey('primary-role-${testUuid(101)}')),
        findsNothing,
      );
    });

    testWidgets('zero genres blocks Continue with Japanese validation', (
      tester,
    ) async {
      await _pumpLoadedScreen(tester);
      final role = find.byKey(ValueKey('role-${testUuid(101)}'));
      _toggleFilterChip(tester, role);
      _pressContinue(tester);
      await tester.pump();

      expect(find.text('ダンスジャンルを1つ以上選択してください'), findsOneWidget);
      expect(find.text('選択内容の確認'), findsNothing);
    });

    testWidgets('zero roles blocks Continue with Japanese validation', (
      tester,
    ) async {
      await _pumpLoadedScreen(tester);
      _toggleFilterChip(tester, find.byKey(ValueKey('genre-${testUuid(1)}')));
      _pressContinue(tester);
      await tester.pump();

      expect(find.text('役割を1つ以上選択してください'), findsOneWidget);
      expect(find.text('選択内容の確認'), findsNothing);
    });

    testWidgets('valid selections proceed and summary displays all names', (
      tester,
    ) async {
      await _pumpLoadedScreen(tester);
      _toggleFilterChip(tester, find.byKey(ValueKey('genre-${testUuid(1)}')));
      _toggleFilterChip(tester, find.byKey(ValueKey('genre-${testUuid(2)}')));
      final firstRole = find.byKey(ValueKey('role-${testUuid(101)}'));
      final secondRole = find.byKey(ValueKey('role-${testUuid(102)}'));
      _toggleFilterChip(tester, firstRole);
      _toggleFilterChip(tester, secondRole);
      await tester.pump();
      final secondPrimary = find.byKey(
        ValueKey('primary-role-${testUuid(102)}'),
      );
      _selectChoiceChip(tester, secondPrimary);

      _pressContinue(tester);
      await tester.pumpAndSettle();

      expect(find.text('選択内容の確認'), findsOneWidget);
      expect(find.text(genreNames[0]), findsOneWidget);
      expect(find.text(genreNames[1]), findsOneWidget);
      expect(find.text(roleNames[0]), findsOneWidget);
      expect(find.text(roleNames[1]), findsNWidgets(2));
    });

    testWidgets('back from summary preserves all selection state', (
      tester,
    ) async {
      await _pumpLoadedScreen(tester);
      final genre = find.byKey(ValueKey('genre-${testUuid(1)}'));
      final role = find.byKey(ValueKey('role-${testUuid(101)}'));
      _toggleFilterChip(tester, genre);
      _toggleFilterChip(tester, role);
      _pressContinue(tester);
      await tester.pumpAndSettle();

      final back = find.byKey(const ValueKey('taxonomy-summary-back'));
      final backButton = tester.widget<OutlinedButton>(
        find.descendant(of: back, matching: find.byType(OutlinedButton)),
      );
      backButton.onPressed!();
      await tester.pumpAndSettle();

      expect(tester.widget<FilterChip>(genre).selected, isTrue);
      expect(tester.widget<FilterChip>(role).selected, isTrue);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(ValueKey('primary-role-${testUuid(101)}')),
            )
            .selected,
        isTrue,
      );
    });
  });
}

const _friendlyLoadError = 'データを読み込めませんでした。時間をおいて再度お試しください。';

Future<void> _pumpLoadedScreen(WidgetTester tester) {
  return _pumpScreenAndSettle(
    tester,
    fakeStageService(
      fetcher: (functionName, _) async =>
          functionName == 'get_active_genres_v1' ? genreRows() : roleRows(),
    ),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  StageMasterDataService service, {
  Size physicalSize = const Size(900, 1400),
}) {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return tester.pumpWidget(
    MaterialApp(
      theme: StageDesignTokens.theme,
      home: StageProfileTaxonomySelectionScreen(service: service),
    ),
  );
}

Future<void> _pumpScreenAndSettle(
  WidgetTester tester,
  StageMasterDataService service, {
  Size physicalSize = const Size(900, 1400),
}) async {
  await _pumpScreen(tester, service, physicalSize: physicalSize);
  await tester.pumpAndSettle();
}

FilledButton _continueButton(WidgetTester tester) {
  return tester.widget<FilledButton>(_continueButtonFinder());
}

Finder _continueButtonFinder() {
  return find.descendant(
    of: find.byKey(const ValueKey('profile-taxonomy-continue')),
    matching: find.byType(FilledButton),
  );
}

void _expectVisibleNonZero(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  expect(finder.hitTestable(), findsOneWidget);
  final size = tester.getSize(finder);
  expect(size.width, greaterThan(0));
  expect(size.height, greaterThan(0));
  final rect = tester.getRect(finder);
  expect(rect.isFinite, isTrue);
  expect(rect.overlaps(Offset.zero & tester.view.physicalSize), isTrue);
}

void _toggleFilterChip(WidgetTester tester, Finder finder) {
  final chip = tester.widget<FilterChip>(finder);
  chip.onSelected!(!chip.selected);
}

void _selectChoiceChip(WidgetTester tester, Finder finder) {
  tester.widget<ChoiceChip>(finder).onSelected!(true);
}

void _pressContinue(WidgetTester tester) {
  _continueButton(tester).onPressed!();
}

void _pressOutlinedButton(WidgetTester tester, Finder finder) {
  tester.widget<OutlinedButton>(finder).onPressed!();
}

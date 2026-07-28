import 'package:app/stage_preview/navigation/stage_preview_router.dart';
import 'package:app/stage_preview/navigation/stage_tab.dart';
import 'package:app/stage_preview/stage_preview_app.dart';
import 'package:app/stage_preview/stage_preview_config.dart';
import 'package:app/stage_preview/widgets/stage_shell_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normal BandMatch mode remains the compile-time default', () {
    expect(StagePreviewConfig.enabled, isFalse);
  });

  test('semantic tab order and canonical paths are centralized', () {
    expect(StageTab.values, const [
      StageTab.crew,
      StageTab.stage,
      StageTab.home,
      StageTab.studio,
      StageTab.myPage,
    ]);
    expect(StageTab.values.map((tab) => tab.label), [
      'クルー',
      'ステージ',
      'ホーム',
      'スタジオ',
      'マイページ',
    ]);
    expect(StageTab.values.map((tab) => tab.path), [
      '/crew',
      '/stage',
      '/home',
      '/studio',
      '/me',
    ]);
    expect(StageTab.home.branchIndex, 2);
  });

  testWidgets('preview constructs as a routed app without Supabase', (
    tester,
  ) async {
    final previewRouter = await _pumpPreview(tester);

    expect(find.byType(Router<Object>), findsOneWidget);
    expect(find.text('STAGE'), findsOneWidget);
    expect(find.text('あなたへのおすすめ'), findsOneWidget);
    expect(_location(previewRouter), StageRoutes.home);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home is initially selected as the center visual tab', (
    tester,
  ) async {
    await _pumpPreview(tester);

    final navigation = tester.widget<StageBottomNavigation>(
      find.byType(StageBottomNavigation),
    );
    expect(navigation.currentTab, StageTab.home);

    final tabCenters = StageTab.values
        .map(
          (tab) => tester
              .getCenter(find.byKey(ValueKey('stage-tab-${tab.name}')))
              .dx,
        )
        .toList();
    expect(tabCenters, orderedEquals(tabCenters.toList()..sort()));
    expect(tabCenters[StageTab.home.branchIndex], tabCenters[2]);
  });

  for (final tab in StageTab.values) {
    testWidgets('direct ${tab.path} opens the ${tab.name} branch', (
      tester,
    ) async {
      final previewRouter = await _pumpPreview(
        tester,
        initialLocation: tab.path,
      );

      expect(_location(previewRouter), tab.path);
      final navigation = tester.widget<StageBottomNavigation>(
        find.byType(StageBottomNavigation),
      );
      expect(navigation.currentTab, tab);
    });
  }

  testWidgets('all five tabs navigate to their canonical root routes', (
    tester,
  ) async {
    final previewRouter = await _pumpPreview(tester);

    for (final tab in StageTab.values) {
      await _tapTab(tester, tab);
      expect(_location(previewRouter), tab.path);
      final navigation = tester.widget<StageBottomNavigation>(
        find.byType(StageBottomNavigation),
      );
      expect(navigation.currentTab, tab);
    }
  });

  testWidgets('Crew segment state survives routed tab switching', (
    tester,
  ) async {
    await _pumpPreview(tester, initialLocation: StageRoutes.crew);

    await tester.tap(find.text('マイクルー'));
    await tester.pumpAndSettle();
    expect(find.text('運営中のクルー'), findsOneWidget);

    await _tapTab(tester, StageTab.stage);
    await _tapTab(tester, StageTab.crew);

    expect(find.text('運営中のクルー'), findsOneWidget);
    expect(find.text('募集中のクルー'), findsNothing);
  });

  testWidgets('Home crew state survives routed tab switching', (tester) async {
    final previewRouter = await _pumpPreview(tester);

    await tester.tap(find.byKey(const ValueKey('stage-home-state-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('次の練習'), findsOneWidget);

    await _tapTab(tester, StageTab.crew);
    await _tapTab(tester, StageTab.home);

    expect(_location(previewRouter), StageRoutes.home);
    expect(find.text('次の練習'), findsOneWidget);
    expect(find.text('Prism Beat'), findsOneWidget);
  });

  testWidgets('initial Home crew-state constructor remains supported', (
    tester,
  ) async {
    await _pumpPreview(tester, initialHomeHasCrew: true);
    expect(find.text('目標ステージ'), findsOneWidget);
  });

  testWidgets('Crew nested route is restored and active reselect resets it', (
    tester,
  ) async {
    final previewRouter = await _pumpPreview(
      tester,
      initialLocation: StageRoutes.crew,
    );

    await tester.tap(
      find.byKey(const ValueKey('stage-crew-sample-recruitment')),
    );
    await tester.pumpAndSettle();
    expect(_location(previewRouter), StageRoutes.crewSampleRecruitment);
    expect(find.text('募集詳細プレビュー'), findsOneWidget);

    await _tapTab(tester, StageTab.stage);
    await _tapTab(tester, StageTab.crew);
    expect(_location(previewRouter), StageRoutes.crewSampleRecruitment);
    expect(find.text('募集詳細プレビュー'), findsOneWidget);

    await _tapTab(tester, StageTab.crew);
    expect(_location(previewRouter), StageRoutes.crew);
    expect(find.text('募集中のクルー'), findsOneWidget);
  });

  testWidgets('nested back returns to the correct Crew root', (tester) async {
    final previewRouter = await _pumpPreview(
      tester,
      initialLocation: StageRoutes.crewSampleRecruitment,
    );

    expect(find.text('募集詳細プレビュー'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stage-nested-back')));
    await tester.pumpAndSettle();

    expect(_location(previewRouter), StageRoutes.crew);
    expect(find.text('募集中のクルー'), findsOneWidget);
  });

  testWidgets('Stage nested route uses and preserves the Stage branch', (
    tester,
  ) async {
    final previewRouter = await _pumpPreview(
      tester,
      initialLocation: StageRoutes.stage,
    );

    await tester.tap(find.byKey(const ValueKey('stage-stage-sample-event')));
    await tester.pumpAndSettle();
    expect(_location(previewRouter), StageRoutes.stageSampleEvent);
    expect(find.text('イベント詳細プレビュー'), findsOneWidget);

    await _tapTab(tester, StageTab.studio);
    await _tapTab(tester, StageTab.stage);
    expect(_location(previewRouter), StageRoutes.stageSampleEvent);

    await _tapTab(tester, StageTab.stage);
    expect(_location(previewRouter), StageRoutes.stage);
    expect(find.text('イベント・大会'), findsOneWidget);
  });

  testWidgets('notification route opens and back restores branch state', (
    tester,
  ) async {
    final previewRouter = await _pumpPreview(
      tester,
      initialLocation: StageRoutes.crew,
    );
    await tester.tap(find.text('マイクルー'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stage-notification-action')));
    await tester.pumpAndSettle();
    expect(_location(previewRouter), StageRoutes.notifications);
    expect(find.text('通知一覧は次の実装ステップで接続します。'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stage-global-back')));
    await tester.pumpAndSettle();
    expect(_location(previewRouter), StageRoutes.crew);
    expect(find.text('運営中のクルー'), findsOneWidget);
  });

  testWidgets('message route opens and back restores Home state', (
    tester,
  ) async {
    final previewRouter = await _pumpPreview(tester);
    await tester.tap(find.byKey(const ValueKey('stage-home-state-toggle')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stage-message-action')));
    await tester.pumpAndSettle();
    expect(_location(previewRouter), StageRoutes.messages);
    expect(find.text('このプレビューでは実データに接続しません。'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stage-global-back')));
    await tester.pumpAndSettle();
    expect(_location(previewRouter), StageRoutes.home);
    expect(find.text('次の練習'), findsOneWidget);
  });

  testWidgets('unknown route renders the STAGE unavailable screen', (
    tester,
  ) async {
    final previewRouter = await _pumpPreview(
      tester,
      initialLocation: '/unknown-preview-route',
    );

    expect(_location(previewRouter), '/unknown-preview-route');
    expect(find.text('ページを表示できません'), findsOneWidget);
    expect(find.text('/unknown-preview-route'), findsOneWidget);
  });

  for (final size in const [
    Size(320, 700),
    Size(390, 844),
    Size(430, 932),
    Size(768, 900),
    Size(1440, 900),
  ]) {
    testWidgets('routed preview has no overflow at ${size.width.toInt()} px', (
      tester,
    ) async {
      await _setTestSurface(tester, size);
      await _pumpPreview(tester);

      for (final tab in StageTab.values) {
        await _tapTab(tester, tab);
        expect(tester.takeException(), isNull);
      }
    });
  }
}

Future<StagePreviewRouter> _pumpPreview(
  WidgetTester tester, {
  String initialLocation = StageRoutes.home,
  bool initialHomeHasCrew = false,
}) async {
  final previewRouter = StagePreviewRouter.create(
    initialLocation: initialLocation,
    initialHomeHasCrew: initialHomeHasCrew,
  );
  addTearDown(previewRouter.dispose);
  await tester.pumpWidget(
    StagePreviewApp(key: UniqueKey(), previewRouter: previewRouter),
  );
  await tester.pumpAndSettle();
  return previewRouter;
}

Future<void> _tapTab(WidgetTester tester, StageTab tab) async {
  await tester.tap(find.byKey(ValueKey('stage-tab-${tab.name}')));
  await tester.pumpAndSettle();
}

String _location(StagePreviewRouter previewRouter) {
  return previewRouter.router.routeInformationProvider.value.uri.path;
}

Future<void> _setTestSurface(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

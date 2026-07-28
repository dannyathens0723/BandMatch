import 'package:app/stage_preview/stage_preview_app.dart';
import 'package:app/stage_preview/stage_preview_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normal BandMatch mode remains the compile-time default', () {
    expect(StagePreviewConfig.enabled, isFalse);
  });

  testWidgets('preview constructs without Supabase initialization', (
    tester,
  ) async {
    await tester.pumpWidget(const StagePreviewApp());
    await tester.pumpAndSettle();

    expect(find.text('STAGE'), findsOneWidget);
    expect(find.text('あなたへのおすすめ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all five Japanese tabs are shown and select their root', (
    tester,
  ) async {
    await tester.pumpWidget(const StagePreviewApp());

    for (final label in ['ホーム', 'クルー', 'ステージ', 'スタジオ', 'マイページ']) {
      expect(find.text(label), findsOneWidget);
    }

    final cases = <int, String>{
      0: 'あなたへのおすすめ',
      1: '募集中のクルー',
      2: 'イベント・大会',
      3: '新宿周辺のスタジオ',
      4: 'アカウント・設定',
    };
    for (final entry in cases.entries) {
      await tester.tap(find.byKey(ValueKey('stage-tab-${entry.key}')));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
    }
  });

  testWidgets('IndexedStack preserves tab-local segment state', (tester) async {
    await tester.pumpWidget(const StagePreviewApp(initialTabIndex: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('マイクルー'));
    await tester.pumpAndSettle();
    expect(find.text('運営中のクルー'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stage-tab-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stage-tab-1')));
    await tester.pumpAndSettle();

    expect(find.text('運営中のクルー'), findsOneWidget);
    expect(find.text('募集中のクルー'), findsNothing);
  });

  testWidgets('both Home membership states render', (tester) async {
    await tester.pumpWidget(const StagePreviewApp());
    expect(find.text('一緒にステージへ立つ\n仲間を見つけよう'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stage-home-state-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('次の練習'), findsOneWidget);
    expect(find.text('Prism Beat'), findsOneWidget);

    await tester.pumpWidget(const StagePreviewApp(initialHomeHasCrew: true));
    await tester.pumpAndSettle();
    expect(find.text('目標ステージ'), findsOneWidget);
  });

  for (final size in const [
    Size(320, 700),
    Size(390, 844),
    Size(430, 932),
    Size(768, 900),
    Size(1440, 900),
  ]) {
    testWidgets('preview has no layout overflow at ${size.width.toInt()} px', (
      tester,
    ) async {
      await _setTestSurface(tester, size);
      await tester.pumpWidget(const StagePreviewApp());
      await tester.pumpAndSettle();

      for (var index = 0; index < 5; index++) {
        await tester.tap(find.byKey(ValueKey('stage-tab-$index')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('notification and message actions stay preview-only', (
    tester,
  ) async {
    await tester.pumpWidget(const StagePreviewApp());

    await tester.tap(find.byKey(const ValueKey('stage-notification-action')));
    await tester.pumpAndSettle();
    expect(find.text('通知一覧は次の実装ステップで接続します。'), findsOneWidget);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stage-message-action')));
    await tester.pumpAndSettle();
    expect(find.text('このプレビューでは実データに接続しません。'), findsOneWidget);
  });
}

Future<void> _setTestSurface(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

import 'package:app/app.dart';
import 'package:app/screens/auth_screen.dart';
import 'package:app/stage_preview/theme/stage_design_tokens.dart';
import 'package:app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AuthGate defaults to legacy branding and accepts STAGE branding', () {
    expect(const AuthGate().authPresentation, AuthScreenPresentation.bandMatch);
    expect(
      const AuthGate(
        authPresentation: AuthScreenPresentation.stage,
      ).authPresentation,
      AuthScreenPresentation.stage,
    );
  });

  testWidgets('STAGE authentication follows the provider-first wireframe', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StageDesignTokens.theme,
        home: const AuthScreen(presentation: AuthScreenPresentation.stage),
      ),
    );

    expect(find.byKey(const ValueKey('stage-auth-wireframe')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-auth-wordmark')), findsOneWidget);
    expect(find.text('誰もがステージの上で輝けるように。'), findsOneWidget);
    expect(find.text('LINEで続ける'), findsOneWidget);
    expect(find.text('Appleで続ける'), findsOneWidget);
    expect(find.text('メールアドレスで登録'), findsOneWidget);
    expect(find.text('ログイン（登録済みの方）'), findsOneWidget);
    expect(find.text('BandMatchへようこそ'), findsNothing);
    expect(find.byIcon(Icons.music_note_rounded), findsNothing);
    expect(find.widgetWithText(TextField, 'メールアドレス'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('stage-auth-line')));
    await tester.tap(find.byKey(const ValueKey('stage-auth-line')));
    await tester.pump();

    expect(find.text('LINEログインは現在準備中です'), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-auth-wireframe')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('stage-auth-email-register')),
    );
    await tester.tap(find.byKey(const ValueKey('stage-auth-email-register')));
    await tester.pump();

    expect(find.widgetWithText(TextField, 'メールアドレス'), findsOneWidget);
    expect(find.text('メールリンク'), findsOneWidget);
    expect(find.text('パスワード'), findsOneWidget);
    expect(find.text('サインイン用リンクを送る'), findsOneWidget);
    expect(find.text('パスワードを設定 / 再設定'), findsOneWidget);

    await tester.tap(find.text('パスワード'));
    await tester.pump();

    expect(find.widgetWithText(TextField, 'パスワード'), findsOneWidget);
    expect(find.text('パスワードでサインイン'), findsOneWidget);
    expect(find.text('パスワードを設定 / 再設定'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stage-auth-provider-back')));
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('stage-auth-existing-login')),
    );
    await tester.tap(find.byKey(const ValueKey('stage-auth-existing-login')));
    await tester.pump();

    expect(find.widgetWithText(TextField, 'パスワード'), findsOneWidget);
    expect(find.text('パスワードでサインイン'), findsOneWidget);
  });

  testWidgets('STAGE Apple provider remains a controlled placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StageDesignTokens.theme,
        home: const AuthScreen(presentation: AuthScreenPresentation.stage),
      ),
    );

    await tester.ensureVisible(find.byKey(const ValueKey('stage-auth-apple')));
    await tester.tap(find.byKey(const ValueKey('stage-auth-apple')));
    await tester.pump();

    expect(find.text('Appleログインは現在準備中です'), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-auth-wireframe')), findsOneWidget);
    expect(find.widgetWithText(TextField, 'メールアドレス'), findsNothing);
  });

  testWidgets('legacy authentication preserves BandMatch presentation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const AuthScreen()),
    );

    expect(find.text('BandMatchへようこそ'), findsOneWidget);
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-auth-wordmark')), findsNothing);
    expect(find.text('STAGEへようこそ'), findsNothing);
    expect(find.text('メールリンク'), findsOneWidget);
    expect(find.text('パスワード'), findsOneWidget);
    expect(find.text('サインイン用リンクを送る'), findsOneWidget);
    expect(find.text('パスワードを設定 / 再設定'), findsOneWidget);
  });
}

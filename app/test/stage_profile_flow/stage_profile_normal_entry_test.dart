import 'package:app/stage_preview/theme/stage_design_tokens.dart';
import 'package:app/stage_profile_flow/stage_authenticated_my_page_screen.dart';
import 'package:app/stage_profile_flow/stage_authenticated_shell.dart';
import 'package:app/stage_profile_flow/stage_profile_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('authenticated STAGE shell opens My Page and taxonomy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StageDesignTokens.theme,
        home: StageAuthenticatedShell(
          myPageBuilder: (_) => StageAuthenticatedMyPageScreen(
            email: 'stage@example.com',
            profileEditBuilder: (_) => StageProfileEditScreen(
              taxonomyBuilder: (_) => const Scaffold(
                body: Center(
                  child: Text(
                    'STAGE taxonomy destination',
                    key: ValueKey('stage-taxonomy-destination'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('STAGE'), findsOneWidget);
    expect(find.text('BandMatch'), findsNothing);
    expect(find.text('メンバーを探す'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('stage-tab-myPage')));
    await tester.pumpAndSettle();
    expect(find.text('STAGEプロフィール'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('stage-my-page-profile-edit')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('stage-profile-edit-screen')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('stage-profile-edit-taxonomy')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('stage-taxonomy-destination')),
      findsOneWidget,
    );

    Navigator.of(
      tester.element(
        find.byKey(const ValueKey('stage-taxonomy-destination')),
      ),
    ).pop();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('stage-profile-edit-screen')),
      findsOneWidget,
    );

    Navigator.of(
      tester.element(find.byKey(const ValueKey('stage-profile-edit-screen'))),
    ).pop();
    await tester.pumpAndSettle();
    expect(find.text('STAGEプロフィール'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('stage-authenticated-shell')),
      findsOneWidget,
    );
  });
}

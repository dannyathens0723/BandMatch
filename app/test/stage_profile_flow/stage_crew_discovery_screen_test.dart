import 'dart:async';

import 'package:app/models/recruitment_application.dart';
import 'package:app/models/stage_crew_recruitment.dart';
import 'package:app/services/stage_crew_discovery_service.dart';
import 'package:app/stage_preview/navigation/stage_tab.dart';
import 'package:app/stage_preview/theme/stage_design_tokens.dart';
import 'package:app/stage_preview/widgets/stage_shell_chrome.dart';
import 'package:app/stage_profile_flow/stage_authenticated_home_screen.dart';
import 'package:app/stage_profile_flow/stage_authenticated_my_page_screen.dart';
import 'package:app/stage_profile_flow/stage_authenticated_shell.dart';
import 'package:app/stage_profile_flow/stage_crew_detail_screen.dart';
import 'package:app/stage_profile_flow/stage_crew_discovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('authenticated STAGE shell maps the centered navigation tabs', (
    tester,
  ) async {
    await _setSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: StageDesignTokens.theme,
        home: StageAuthenticatedShell(
          crewBuilder: (_) => StageCrewDiscoveryScreen(
            repository: _FakeCrewRepository(() async => const []),
          ),
          myPageBuilder: (_) =>
              const StageAuthenticatedMyPageScreen(email: 'stage@example.com'),
        ),
      ),
    );

    final navigation = tester.widget<StageBottomNavigation>(
      find.byType(StageBottomNavigation),
    );
    expect(navigation.tabs, const [
      StageTab.crew,
      StageTab.stage,
      StageTab.home,
      StageTab.studio,
      StageTab.myPage,
    ]);
    expect(navigation.currentTab, StageTab.home);
    expect(navigation.tabs.indexOf(StageTab.home), 2);
    expect(find.byType(StageAuthenticatedHomeScreen), findsOneWidget);

    final labels = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(StageBottomNavigation),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data)
        .toList(growable: false);
    expect(labels, const ['クルー', 'ステージ', 'ホーム', 'スタジオ', 'マイページ']);

    await tester.tap(find.byKey(const ValueKey('stage-tab-crew')));
    await tester.pumpAndSettle();

    expect(find.byType(StageCrewDiscoveryScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-crew-empty')), findsOneWidget);
    expect(find.text('MVPで順次公開'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('stage-tab-home')));
    await tester.pumpAndSettle();
    expect(find.byType(StageAuthenticatedHomeScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stage-tab-myPage')));
    await tester.pumpAndSettle();
    expect(find.byType(StageAuthenticatedMyPageScreen), findsOneWidget);
    expect(find.text('BandMatch'), findsNothing);
  });

  testWidgets('Crew list shows an independent loading state', (tester) async {
    final completer = Completer<List<StageCrewRecruitment>>();
    await _pumpDiscovery(tester, _FakeCrewRepository(() => completer.future));

    expect(find.byKey(const ValueKey('stage-crew-loading')), findsOneWidget);
    completer.complete(const []);
  });

  testWidgets(
    'Crew list renders Supabase projection data without Band fields',
    (tester) async {
      await _pumpDiscovery(
        tester,
        _FakeCrewRepository(() async => [_recruitment]),
      );
      await tester.pumpAndSettle();

      expect(find.text(_recruitment.title), findsOneWidget);
      expect(find.text('Prism Beat'), findsOneWidget);
      expect(find.text('K-POP'), findsWidgets);
      expect(find.text('新宿'), findsOneWidget);
      expect(find.text('ギター'), findsNothing);
      expect(find.text('BandMatch'), findsNothing);
    },
  );

  testWidgets('Crew list shows the empty state', (tester) async {
    await _pumpDiscovery(tester, _FakeCrewRepository(() async => const []));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('stage-crew-empty')), findsOneWidget);
    expect(find.text('募集中のクルーはまだありません'), findsOneWidget);
  });

  testWidgets('Crew backend failure is controlled and retryable', (
    tester,
  ) async {
    final repository = _RetryCrewRepository();
    await _pumpDiscovery(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('stage-crew-error')), findsOneWidget);
    expect(find.text('backend exploded'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('stage-crew-retry')));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text(_recruitment.title), findsOneWidget);
  });

  testWidgets('opening Crew detail and back preserves the discovery list', (
    tester,
  ) async {
    await _pumpDiscovery(
      tester,
      _FakeCrewRepository(() async => [_recruitment]),
      detailBuilder: (_, recruitment) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            recruitment.title,
            key: const ValueKey('crew-detail-destination'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey('stage-crew-card-${_recruitment.postId}')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('crew-detail-destination')),
      findsOneWidget,
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(_recruitment.title), findsOneWidget);
    expect(
      find.byKey(const ValueKey('stage-crew-search-field')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Crew detail submits an application through the injected gateway',
    (tester) async {
      String? submittedPostId;
      String? submittedMessage;
      await _setSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: StageDesignTokens.theme,
          home: StageCrewDetailScreen(
            recruitment: _recruitment,
            loadApplicationState: (_) async =>
                const RecruitmentApplicationState(
                  state: 'none',
                  applicationId: null,
                ),
            submitApplication: ({required postId, required message}) async {
              submittedPostId = postId;
              submittedMessage = message;
              return const RecruitmentApplicationState(
                state: 'pending',
                applicationId: 'application-1',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final applyButton = find.byKey(const ValueKey('stage-crew-apply-button'));
      await tester.ensureVisible(applyButton);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('stage-crew-application-message')),
        '一緒にステージを目指したいです',
      );
      await tester.tap(
        find.byKey(const ValueKey('stage-crew-submit-application')),
      );
      await tester.pumpAndSettle();

      expect(submittedPostId, _recruitment.postId);
      expect(submittedMessage, '一緒にステージを目指したいです');
      expect(find.text('応募済み・確認中です'), findsOneWidget);
      expect(find.text('応募を受け付けました'), findsOneWidget);
    },
  );
}

final _recruitment = StageCrewRecruitment(
  postId: 'post-1',
  crewId: 'crew-1',
  crewName: 'Prism Beat',
  crewAvatarUrl: null,
  title: 'K-POPカバーステージの参加メンバー募集',
  body: '11月のショーケースに向けて一緒に練習するメンバーを募集します。',
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 20),
  danceGenreNames: ['K-POP'],
  areaNames: ['新宿'],
);

class _FakeCrewRepository implements StageCrewDiscoveryRepository {
  const _FakeCrewRepository(this.loader);

  final Future<List<StageCrewRecruitment>> Function() loader;

  @override
  Future<List<StageCrewRecruitment>> fetchOpenRecruitments() => loader();
}

class _RetryCrewRepository implements StageCrewDiscoveryRepository {
  int calls = 0;

  @override
  Future<List<StageCrewRecruitment>> fetchOpenRecruitments() async {
    calls += 1;
    if (calls == 1) throw StateError('backend exploded');
    return [_recruitment];
  }
}

Future<void> _pumpDiscovery(
  WidgetTester tester,
  StageCrewDiscoveryRepository repository, {
  StageCrewDetailBuilder? detailBuilder,
}) async {
  await _setSurface(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: StageDesignTokens.theme,
      home: Scaffold(
        body: StageCrewDiscoveryScreen(
          repository: repository,
          detailBuilder: detailBuilder,
        ),
      ),
    ),
  );
}

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

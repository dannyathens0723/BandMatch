import 'dart:async';

import 'package:app/models/stage_crew_recruitment.dart';
import 'package:app/models/stage_my_crew.dart';
import 'package:app/services/stage_crew_discovery_service.dart';
import 'package:app/services/stage_my_crew_service.dart';
import 'package:app/stage_preview/theme/stage_design_tokens.dart';
import 'package:app/stage_profile_flow/stage_crew_discovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'My Crew renders managed participating and application sections',
    (tester) async {
      await _pump(tester, _FakeMyCrewRepository(_overview));
      await _openMyCrew(tester);

      expect(find.text('管理中のクルー'), findsOneWidget);
      expect(find.text('参加中のクルー'), findsOneWidget);
      expect(find.text('応募中・応募履歴'), findsOneWidget);
      expect(find.text('Prism Beat'), findsOneWidget);
      expect(find.text('Lumière'), findsOneWidget);
      expect(find.text('確認中'), findsOneWidget);
      expect(find.text('マイクルーは次のMVPステップで実装します'), findsNothing);
    },
  );

  testWidgets('My Crew shows independent loading and empty states', (
    tester,
  ) async {
    final completer = Completer<StageMyCrewOverview>();
    await _pump(tester, _LoaderMyCrewRepository(() => completer.future));
    await tester.tap(find.byKey(const ValueKey('stage-crew-mine-segment')));
    await tester.pump();
    expect(find.byKey(const ValueKey('stage-my-crew-loading')), findsOneWidget);

    completer.complete(const StageMyCrewOverview(crews: [], applications: []));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stage-my-crew-empty')), findsOneWidget);
    expect(find.text('募集をさがす'), findsOneWidget);
  });

  testWidgets('My Crew backend error is controlled and retryable', (
    tester,
  ) async {
    final repository = _RetryMyCrewRepository();
    await _pump(tester, repository);
    await _openMyCrew(tester);

    expect(find.byKey(const ValueKey('stage-my-crew-error')), findsOneWidget);
    expect(find.text('backend exploded'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('stage-my-crew-retry')));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.text('Prism Beat'), findsOneWidget);
  });

  testWidgets('Crew detail back preserves selected My Crew tab', (
    tester,
  ) async {
    await _pump(tester, _FakeMyCrewRepository(_overview));
    await _openMyCrew(tester);

    await tester.tap(
      find.byKey(const ValueKey('stage-my-crew-card-managed-crew')),
    );
    await tester.pumpAndSettle();
    expect(find.text('MY CREW DETAIL'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('管理中のクルー'), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-crew-search-field')), findsNothing);
  });

  testWidgets('application card opens its read-only recruitment detail', (
    tester,
  ) async {
    await _pump(tester, _FakeMyCrewRepository(_overview));
    await _openMyCrew(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('stage-my-crew-application-application-1')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('stage-my-crew-application-application-1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('APPLICATION DETAIL'), findsOneWidget);
  });

  testWidgets('switching back to Find preserves existing discovery behavior', (
    tester,
  ) async {
    await _pump(tester, _FakeMyCrewRepository(_overview));
    await _openMyCrew(tester);
    await tester.tap(find.byKey(const ValueKey('stage-crew-find-segment')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('stage-crew-search-field')),
      findsOneWidget,
    );
    expect(find.text(_recruitment.title), findsOneWidget);
  });
}

final _managedCrew = StageMyCrew(
  crewId: 'managed-crew',
  crewName: 'Prism Beat',
  crewAvatarUrl: null,
  crewBio: 'K-POPショーケースを目標に活動中です。',
  membershipRole: 'admin',
  isCreator: true,
  joinedAt: DateTime(2026, 4, 1),
  activeMemberCount: 6,
  openRecruitmentCount: 1,
  danceGenreNames: const ['K-POP'],
  areaNames: const ['新宿'],
);

final _participatingCrew = StageMyCrew(
  crewId: 'member-crew',
  crewName: 'Lumière',
  crewAvatarUrl: null,
  crewBio: null,
  membershipRole: 'member',
  isCreator: false,
  joinedAt: DateTime(2026, 5, 1),
  activeMemberCount: 4,
  openRecruitmentCount: 0,
  danceGenreNames: const ['JAZZ'],
  areaNames: const ['渋谷'],
);

final _application = StageMyCrewApplication(
  applicationId: 'application-1',
  postId: 'post-1',
  crewId: 'app-crew',
  crewName: 'BLAZE UNIT',
  crewAvatarUrl: null,
  title: 'STREET JAM 出場メンバー募集',
  body: '一緒にステージを目指すメンバーを募集します。',
  applicationStatus: 'pending',
  appliedAt: DateTime(2026, 7, 25),
  respondedAt: null,
  postStatus: 'open',
  danceGenreNames: const ['HIPHOP'],
  areaNames: const ['新宿'],
);

final _overview = StageMyCrewOverview(
  crews: [_managedCrew, _participatingCrew],
  applications: [_application],
);

final _recruitment = StageCrewRecruitment(
  postId: 'discovery-post',
  crewId: 'discovery-crew',
  crewName: 'Discovery Crew',
  crewAvatarUrl: null,
  title: '公開中の募集',
  body: '募集本文',
  createdAt: DateTime(2026, 7, 1),
  updatedAt: DateTime(2026, 7, 2),
  danceGenreNames: const ['K-POP'],
  areaNames: const ['新宿'],
);

class _FakeDiscoveryRepository implements StageCrewDiscoveryRepository {
  @override
  Future<List<StageCrewRecruitment>> fetchOpenRecruitments() async => [
    _recruitment,
  ];
}

class _FakeMyCrewRepository implements StageMyCrewRepository {
  const _FakeMyCrewRepository(this.overview);
  final StageMyCrewOverview overview;

  @override
  Future<StageMyCrewOverview> fetchMyCrewOverview() async => overview;
}

class _LoaderMyCrewRepository implements StageMyCrewRepository {
  const _LoaderMyCrewRepository(this.loader);
  final Future<StageMyCrewOverview> Function() loader;

  @override
  Future<StageMyCrewOverview> fetchMyCrewOverview() => loader();
}

class _RetryMyCrewRepository implements StageMyCrewRepository {
  int calls = 0;

  @override
  Future<StageMyCrewOverview> fetchMyCrewOverview() async {
    calls += 1;
    if (calls == 1) throw StateError('backend exploded');
    return _overview;
  }
}

Future<void> _pump(
  WidgetTester tester,
  StageMyCrewRepository myCrewRepository,
) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: StageDesignTokens.theme,
      home: Scaffold(
        body: StageCrewDiscoveryScreen(
          repository: _FakeDiscoveryRepository(),
          myCrewRepository: myCrewRepository,
          myCrewDetailBuilder: (_, _) =>
              Scaffold(appBar: AppBar(), body: const Text('MY CREW DETAIL')),
          applicationDetailBuilder: (_, _) => Scaffold(
            appBar: AppBar(),
            body: const Text('APPLICATION DETAIL'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openMyCrew(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('stage-crew-mine-segment')));
  await tester.pumpAndSettle();
}

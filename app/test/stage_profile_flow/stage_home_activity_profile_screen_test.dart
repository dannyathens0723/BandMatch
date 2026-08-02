import 'dart:async';

import 'package:app/models/stage_activity.dart';
import 'package:app/models/stage_crew_activity.dart';
import 'package:app/models/stage_home_dashboard.dart';
import 'package:app/models/stage_my_crew.dart';
import 'package:app/models/stage_user_profile.dart';
import 'package:app/services/stage_activity_service.dart';
import 'package:app/services/stage_crew_activity_service.dart';
import 'package:app/services/stage_home_dashboard_service.dart';
import 'package:app/services/stage_profile_service.dart';
import 'package:app/stage_preview/navigation/stage_tab.dart';
import 'package:app/stage_preview/theme/stage_design_tokens.dart';
import 'package:app/stage_profile_flow/stage_activity_center_screen.dart';
import 'package:app/stage_profile_flow/stage_authenticated_home_screen.dart';
import 'package:app/stage_profile_flow/stage_authenticated_my_page_screen.dart';
import 'package:app/stage_profile_flow/stage_authenticated_shell.dart';
import 'package:app/stage_profile_flow/stage_crew_announcement_detail_screen.dart';
import 'package:app/stage_profile_flow/stage_profile_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('STAGE Home', () {
    testWidgets('loads real profile and empty dashboard sections', (
      tester,
    ) async {
      final selectedTabs = <StageTab>[];
      await _pumpHome(
        tester,
        repository: _DashboardRepository([_dashboard()]),
        onSelectTab: selectedTabs.add,
      );

      expect(find.text('Mioさん、次のステージへ'), findsOneWidget);
      expect(find.text('プロフィール完成度 85% ・ Dancer'), findsOneWidget);
      expect(find.text('現在公開中のクルー募集はありません。'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('現在公開中のイベントはありません。'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('現在公開中のイベントはありません。'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('現在公開中のスタジオはありません。'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('現在公開中のスタジオはありません。'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('stage-home-profile-cta')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('stage-home-profile-cta')));
      expect(selectedTabs, [StageTab.myPage]);
    });

    testWidgets('keeps usable sections when one section fails', (tester) async {
      await _pumpHome(
        tester,
        repository: _DashboardRepository([
          _dashboard(
            activity: const StageDashboardSection<List<StageActivity>>.error(
              'private backend detail',
            ),
          ),
        ]),
      );

      expect(find.text('Mioさん、次のステージへ'), findsOneWidget);
      expect(find.text('活動の一部を読み込めませんでした。'), findsOneWidget);
      expect(find.text('private backend detail'), findsNothing);
    });

    testWidgets('initial total failure is controlled and retryable', (
      tester,
    ) async {
      final repository = _DashboardRepository([_failedDashboard, _dashboard()]);
      await _pumpHome(tester, repository: repository);

      expect(find.byKey(const ValueKey('stage-home-error')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('stage-home-retry')));
      await tester.pumpAndSettle();

      expect(repository.calls, 2);
      expect(find.text('Mioさん、次のステージへ'), findsOneWidget);
    });

    testWidgets('activity summary opens the authoritative My Crew area', (
      tester,
    ) async {
      var openedMyCrew = false;
      await _pumpHome(
        tester,
        repository: _DashboardRepository([_dashboard()]),
        onOpenMyCrew: () => openedMyCrew = true,
      );

      await tester.tap(
        find.byKey(const ValueKey('stage-home-activity-summary')),
      );
      expect(openedMyCrew, isTrue);
    });

    testWidgets('Crew activity opens its authoritative Crew context', (
      tester,
    ) async {
      String? openedCrewId;
      await _pumpHome(
        tester,
        repository: _DashboardRepository([
          _dashboard(
            activity: StageDashboardSection.data([_crewPracticeActivity]),
          ),
        ]),
        onOpenCrew: (crewId) => openedCrewId = crewId,
      );

      await tester.scrollUntilVisible(
        find.byKey(
          const ValueKey('stage-home-crew-activity-crew_practice:practice-1'),
        ),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.byKey(
          const ValueKey('stage-home-crew-activity-crew_practice:practice-1'),
        ),
      );

      expect(openedCrewId, 'crew-1');
    });

    testWidgets(
      'announcement activity opens exact authorized detail and back',
      (tester) async {
        final announcementRepository = _CrewActivityRepository(
          snapshot: _announcementSnapshot,
        );
        await _pumpHome(
          tester,
          repository: _DashboardRepository([
            _dashboard(
              activity: StageDashboardSection.data([_announcementActivity]),
            ),
          ]),
          announcementRepository: announcementRepository,
        );

        final card = find.byKey(
          const ValueKey(
            'stage-home-crew-activity-crew_announcement:announcement-1',
          ),
        );
        await tester.scrollUntilVisible(
          card,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(card);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('stage-crew-announcement-detail')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('stage-crew-announcement-announcement-1')),
          findsOneWidget,
        );
        expect(find.text('Authoritative announcement body'), findsOneWidget);
        expect(announcementRepository.crewIds, ['crew-1']);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(card, findsOneWidget);
      },
    );
  });

  group('STAGE activity center', () {
    testWidgets('shell bell opens activity and message action is intentional', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: StageDesignTokens.theme,
          home: StageAuthenticatedShell(
            homeBuilder: (_) => const Text('HOME BODY'),
            myPageBuilder: (_) => const Text('MY PAGE BODY'),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('stage-notification-action')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('stage-activity-center')),
        findsOneWidget,
      );

      Navigator.of(
        tester.element(find.byKey(const ValueKey('stage-activity-center'))),
      ).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('stage-message-action')));
      await tester.pump();
      expect(find.text('メッセージ機能は現在準備中です。'), findsOneWidget);
    });

    testWidgets(
      'renders caller and manager activity without private messages',
      (tester) async {
        final repository = _ActivityRepository([
          () async => [_ownActivity, _managerActivity],
        ]);
        await _pumpActivity(tester, repository);

        expect(find.text('応募が承認されました'), findsOneWidget);
        expect(find.text('新しい応募があります'), findsOneWidget);
        expect(find.textContaining('Ayaさん'), findsOneWidget);
        expect(find.textContaining('private note'), findsNothing);
      },
    );

    testWidgets('shows empty state and controlled error retry', (tester) async {
      final repository = _ActivityRepository([
        () async => throw StateError('secret backend error'),
        () async => const [],
      ]);
      await _pumpActivity(tester, repository);

      expect(
        find.byKey(const ValueKey('stage-activity-error')),
        findsOneWidget,
      );
      expect(find.text('secret backend error'), findsNothing);
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(
        find.byKey(const ValueKey('stage-activity-empty')),
        findsOneWidget,
      );
    });

    testWidgets('activity card returns to the Crew callback', (tester) async {
      var openedCrew = false;
      final repository = _ActivityRepository([
        () async => [_ownActivity],
      ]);
      await tester.pumpWidget(
        MaterialApp(
          theme: StageDesignTokens.theme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => StageActivityCenterScreen(
                        repository: repository,
                        onOpenCrewArea: () => openedCrew = true,
                      ),
                    ),
                  ),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('stage-activity-own:1')));
      await tester.pumpAndSettle();

      expect(openedCrew, isTrue);
      expect(find.text('OPEN'), findsOneWidget);
    });

    testWidgets(
      'announcement opens exact detail and back returns to Activity Center',
      (tester) async {
        final announcementRepository = _CrewActivityRepository(
          snapshot: _announcementSnapshot,
        );
        await _pumpActivity(
          tester,
          _ActivityRepository([
            () async => [_announcementActivity],
          ]),
          announcementRepository: announcementRepository,
        );

        await tester.tap(
          find.byKey(
            const ValueKey('stage-activity-crew_announcement:announcement-1'),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('stage-crew-announcement-detail')),
          findsOneWidget,
        );
        expect(announcementRepository.crewIds, ['crew-1']);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('stage-activity-center')),
          findsOneWidget,
        );
      },
    );

    testWidgets('unavailable announcement detail fails without backend text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: StageDesignTokens.theme,
          home: StageCrewAnnouncementDetailScreen(
            crewId: 'crew-1',
            crewName: 'Prism',
            announcementId: 'missing-announcement',
            repository: _CrewActivityRepository(
              snapshot: const StageCrewActivitySnapshot(
                isAdmin: false,
                practices: [],
                polls: [],
                announcements: [],
                resources: [],
                targets: [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('stage-crew-announcement-unavailable')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Announcement is not available'),
        findsNothing,
      );
    });

    testWidgets('wide activity route keeps the shared mobile canvas', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpActivity(tester, _ActivityRepository([() async => const []]));
      final canvas = tester.getSize(
        find.byKey(const ValueKey('stage-mobile-page-canvas')),
      );
      expect(canvas.width, StageDesignTokens.maxContentWidth);
      expect(tester.takeException(), isNull);
    });
  });

  group('STAGE My Page and profile edit', () {
    testWidgets('reloads authoritative profile after edit returns true', (
      tester,
    ) async {
      final repository = _ProfileRepository(
        profiles: [_profile, _updatedProfile],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: StageDesignTokens.theme,
          home: Scaffold(
            body: StageAuthenticatedMyPageScreen(
              email: 'mio@example.com',
              profileRepository: repository,
              profileEditBuilder: (_) => const _SuccessfulProfileEdit(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mio'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('stage-my-page-profile-edit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE AND RETURN'));
      await tester.pumpAndSettle();

      expect(repository.fetchCalls, 2);
      expect(find.text('Mio Updated'), findsOneWidget);
    });

    testWidgets('prevents duplicate profile submission', (tester) async {
      final update = Completer<StageUserProfile>();
      final repository = _ProfileRepository(
        profiles: [_profile],
        updateFuture: update.future,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: StageDesignTokens.theme,
          home: StageProfileEditScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      final save = find.byKey(const ValueKey('stage-profile-save'));
      await tester.scrollUntilVisible(
        save,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(save);
      await tester.tap(save);
      await tester.pump();
      expect(repository.updateCalls, 1);

      update.complete(_updatedProfile);
      await tester.pumpAndSettle();
      expect(repository.updateCalls, 1);
    });
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required StageHomeDashboardRepository repository,
  ValueChanged<StageTab>? onSelectTab,
  VoidCallback? onOpenMyCrew,
  ValueChanged<String>? onOpenCrew,
  StageCrewActivityRepository? announcementRepository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: StageDesignTokens.theme,
      home: Scaffold(
        body: StageAuthenticatedHomeScreen(
          repository: repository,
          onSelectTab: onSelectTab ?? (_) {},
          onOpenMyCrew: onOpenMyCrew,
          onOpenCrew: onOpenCrew,
          announcementRepository: announcementRepository,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpActivity(
  WidgetTester tester,
  StageActivityRepository repository, {
  StageCrewActivityRepository? announcementRepository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: StageDesignTokens.theme,
      home: StageActivityCenterScreen(
        repository: repository,
        announcementRepository: announcementRepository,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

StageHomeDashboard _dashboard({
  StageDashboardSection<List<StageActivity>> activity =
      const StageDashboardSection.data(<StageActivity>[]),
}) => StageHomeDashboard(
  profile: const StageDashboardSection.data(_profile),
  myCrew: const StageDashboardSection.data(
    StageMyCrewOverview(crews: [], applications: []),
  ),
  activity: activity,
  recruitments: const StageDashboardSection.data([]),
  events: const StageDashboardSection.data([]),
  studios: const StageDashboardSection.data([]),
);

const _failedSection = StageDashboardSection<Never>.error('failed');

final _failedDashboard = StageHomeDashboard(
  profile: StageDashboardSection.error(_failedSection),
  myCrew: StageDashboardSection.error(_failedSection),
  activity: StageDashboardSection.error(_failedSection),
  recruitments: StageDashboardSection.error(_failedSection),
  events: StageDashboardSection.error(_failedSection),
  studios: StageDashboardSection.error(_failedSection),
);

const _profile = StageUserProfile(
  userId: 'user-1',
  displayName: 'Mio',
  avatarUrl: null,
  bio: 'Dance is my stage.',
  experienceLevel: 'experienced',
  activityFrequency: 'weekly_1_2',
  areaId: 'area-1',
  areaName: '渋谷区',
  danceGenreNames: ['HIPHOP'],
  performanceRoleNames: ['Dancer'],
  primaryPerformanceRoleName: 'Dancer',
  hasSavedTaxonomy: true,
  profileCompleteness: 85,
);

const _updatedProfile = StageUserProfile(
  userId: 'user-1',
  displayName: 'Mio Updated',
  avatarUrl: null,
  bio: 'Updated profile.',
  experienceLevel: 'experienced',
  activityFrequency: 'weekly_1_2',
  areaId: 'area-1',
  areaName: '渋谷区',
  danceGenreNames: ['HIPHOP'],
  performanceRoleNames: ['Dancer'],
  primaryPerformanceRoleName: 'Dancer',
  hasSavedTaxonomy: true,
  profileCompleteness: 100,
);

final _ownActivity = StageActivity(
  activityKey: 'own:1',
  activityType: 'own_application',
  activityStatus: 'accepted',
  occurredAt: DateTime(2026, 8, 1, 12),
  crewId: 'crew-1',
  crewName: 'Prism',
  postId: 'post-1',
  postTitle: 'Dancer募集',
  applicationId: 'application-1',
  actorDisplayName: null,
);

final _managerActivity = StageActivity(
  activityKey: 'manager:1',
  activityType: 'managed_application',
  activityStatus: 'pending',
  occurredAt: DateTime(2026, 8, 2, 12),
  crewId: 'crew-2',
  crewName: 'Lumière',
  postId: 'post-2',
  postTitle: 'Member募集',
  applicationId: 'application-2',
  actorDisplayName: 'Aya',
);

final _crewPracticeActivity = StageActivity(
  activityKey: 'crew_practice:practice-1',
  activityType: 'crew_practice',
  activityStatus: 'scheduled',
  occurredAt: DateTime(2026, 8, 3, 12),
  crewId: 'crew-1',
  crewName: 'Prism',
  postId: null,
  postTitle: '8月10日 リハーサル',
  applicationId: null,
  actorDisplayName: null,
);

final _announcementActivity = StageActivity(
  activityKey: 'crew_announcement:announcement-1',
  activityType: 'crew_announcement',
  activityStatus: 'published',
  occurredAt: DateTime(2026, 8, 3, 13),
  crewId: 'crew-1',
  crewName: 'Prism',
  postId: null,
  postTitle: 'Important announcement',
  applicationId: null,
  actorDisplayName: null,
);

const _announcement = StageCrewAnnouncement(
  announcementId: 'announcement-1',
  title: 'Important announcement',
  status: 'published',
  body: 'Authoritative announcement body',
  authorDisplayName: 'Mio',
);

const _announcementSnapshot = StageCrewActivitySnapshot(
  isAdmin: false,
  practices: [],
  polls: [],
  announcements: [_announcement],
  resources: [],
  targets: [],
);

class _DashboardRepository implements StageHomeDashboardRepository {
  _DashboardRepository(this.responses);

  final List<StageHomeDashboard> responses;
  int calls = 0;

  @override
  Future<StageHomeDashboard> fetchDashboard() async {
    final index = calls < responses.length ? calls : responses.length - 1;
    calls++;
    return responses[index];
  }
}

class _ActivityRepository implements StageActivityRepository {
  _ActivityRepository(this.responses);

  final List<Future<List<StageActivity>> Function()> responses;
  int calls = 0;

  @override
  Future<List<StageActivity>> fetchMyActivity() {
    final index = calls < responses.length ? calls : responses.length - 1;
    calls++;
    return responses[index]();
  }
}

class _CrewActivityRepository implements StageCrewActivityRepository {
  _CrewActivityRepository({required this.snapshot});

  final StageCrewActivitySnapshot snapshot;
  final List<String> crewIds = [];

  @override
  Future<StageCrewActivitySnapshot> fetchCrewActivity(String crewId) async {
    crewIds.add(crewId);
    return snapshot;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileRepository implements StageProfileRepository {
  _ProfileRepository({required this.profiles, this.updateFuture});

  final List<StageUserProfile> profiles;
  final Future<StageUserProfile>? updateFuture;
  int fetchCalls = 0;
  int updateCalls = 0;

  @override
  Future<List<StageActivityArea>> fetchActivePublicAreas() async => const [
    StageActivityArea(id: 'area-1', name: '渋谷区'),
  ];

  @override
  Future<StageUserProfile> fetchMyProfile() async {
    final index = fetchCalls < profiles.length
        ? fetchCalls
        : profiles.length - 1;
    fetchCalls++;
    return profiles[index];
  }

  @override
  Future<StageUserProfile> updateMyProfile({
    required String displayName,
    required String? bio,
    required String? experienceLevel,
    required String? activityFrequency,
    required String? areaId,
  }) {
    updateCalls++;
    return updateFuture ?? Future.value(_updatedProfile);
  }
}

class _SuccessfulProfileEdit extends StatelessWidget {
  const _SuccessfulProfileEdit();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('SAVE AND RETURN'),
        ),
      ),
    );
  }
}

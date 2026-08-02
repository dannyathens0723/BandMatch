import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/models/stage_crew_activity.dart';
import 'package:app/models/stage_my_crew.dart';
import 'package:app/services/stage_crew_activity_service.dart';
import 'package:app/stage_profile_flow/stage_crew_home_screen.dart';

void main() {
  testWidgets('active admin opens server-backed Crew Home', (tester) async {
    final repository = _FakeActivityRepository();
    await _pumpHome(tester, repository, _adminCrew, [_adminCrew]);

    expect(
      find.byKey(const ValueKey('stage-crew-home-screen')),
      findsOneWidget,
    );
    expect(find.text('Crew A'), findsOneWidget);
    expect(find.text('クルー・募集を管理'), findsOneWidget);
    expect(find.text('次の練習'), findsOneWidget);
    expect(repository.homeCrewIds, ['crew-a']);
  });

  testWidgets('active member sees Crew Home without admin actions', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      _FakeActivityRepository(memberCrewIds: const {'crew-b'}),
      _memberCrew,
      [_memberCrew],
    );

    expect(find.text('Crew B'), findsOneWidget);
    expect(find.text('参加中'), findsOneWidget);
    expect(find.text('クルー・募集を管理'), findsNothing);
  });

  testWidgets('switching Crew replaces all authoritative context', (
    tester,
  ) async {
    final repository = _FakeActivityRepository(memberCrewIds: const {'crew-b'});
    await _pumpHome(tester, repository, _adminCrew, [_adminCrew, _memberCrew]);

    await tester.tap(find.byKey(const ValueKey('stage-crew-context-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crew B').last);
    await tester.pumpAndSettle();

    expect(repository.homeCrewIds, ['crew-a', 'crew-b']);
    expect(find.text('Crew B'), findsWidgets);
    expect(find.text('Crew A の次回練習'), findsNothing);
    expect(find.text('Crew B の次回練習'), findsOneWidget);
  });

  testWidgets('member updates only their own attendance and refreshes counts', (
    tester,
  ) async {
    final repository = _FakeActivityRepository(memberCrewIds: const {'crew-b'});
    await _pumpHome(tester, repository, _memberCrew, [_memberCrew]);

    await tester.tap(find.text('次の練習'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('参加'));
    await tester.pumpAndSettle();

    expect(repository.attendanceResponses, ['attending']);
    expect(find.text('出欠を更新しました'), findsOneWidget);
  });

  testWidgets('practice and poll routes preserve the selected Crew', (
    tester,
  ) async {
    final repository = _FakeActivityRepository();
    await _pumpHome(tester, repository, _adminCrew, [_adminCrew]);
    await tester.tap(find.text('日程調整'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('stage-crew-polls-screen')),
      findsOneWidget,
    );
    expect(repository.activityCrewIds.every((id) => id == 'crew-a'), isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Crew A'), findsOneWidget);
  });

  testWidgets('Crew announcement card opens exact detail and returns to Crew', (
    tester,
  ) async {
    final repository = _FakeActivityRepository(
      announcements: const [_announcement],
    );
    await _pumpHome(tester, repository, _adminCrew, [_adminCrew]);

    await tester.tap(
      find.byKey(const ValueKey('stage-crew-announcements-entry')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('stage-crew-announcement-card-announcement-1')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('stage-crew-announcement-announcement-1')),
      findsOneWidget,
    );
    expect(find.text('Crew announcement body'), findsOneWidget);
    expect(repository.activityCrewIds.every((id) => id == 'crew-a'), isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('stage-crew-announcements-screen')),
      findsOneWidget,
    );
  });

  testWidgets(
    'resource form explains invalid URL and preserves entered values',
    (tester) async {
      final repository = _FakeActivityRepository();
      await _pumpHome(tester, repository, _adminCrew, [_adminCrew]);
      final resourcesEntry = find.byKey(
        const ValueKey('stage-crew-resources-entry'),
      );
      await tester.scrollUntilVisible(
        resourcesEntry,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(resourcesEntry);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('stage-crew-resources-add')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('stage-crew-resource-title')),
        'Practice reference',
      );
      await tester.enterText(
        find.byKey(const ValueKey('stage-crew-resource-url')),
        'xxx.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('stage-crew-resource-description')),
        'Keep this description',
      );
      await tester.tap(find.byKey(const ValueKey('stage-crew-resource-save')));
      await tester.pump();

      expect(find.text(stageCrewResourceUrlErrorMessage), findsOneWidget);
      expect(
        find.byKey(const ValueKey('stage-crew-resource-dialog')),
        findsOneWidget,
      );
      expect(find.text('Practice reference'), findsOneWidget);
      expect(find.text('xxx.com'), findsOneWidget);
      expect(find.text('Keep this description'), findsOneWidget);
      expect(repository.resourceSaveUrls, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('stage-crew-resource-url')),
        'https://example.com/path',
      );
      await tester.tap(find.byKey(const ValueKey('stage-crew-resource-save')));
      await tester.pumpAndSettle();
      expect(repository.resourceSaveUrls, ['https://example.com/path']);
      expect(
        find.byKey(const ValueKey('stage-crew-resource-dialog')),
        findsNothing,
      );
    },
  );

  testWidgets('backend resource URL failure uses controlled Japanese text', (
    tester,
  ) async {
    final repository = _FakeActivityRepository(
      resourceSaveError: const StageCrewResourceUrlException(),
    );
    await _pumpHome(tester, repository, _adminCrew, [_adminCrew]);
    final resourcesEntry = find.byKey(
      const ValueKey('stage-crew-resources-entry'),
    );
    await tester.scrollUntilVisible(
      resourcesEntry,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(resourcesEntry);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stage-crew-resources-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('stage-crew-resource-title')),
      'Practice reference',
    );
    await tester.enterText(
      find.byKey(const ValueKey('stage-crew-resource-url')),
      'https://example.com/path',
    );
    await tester.tap(find.byKey(const ValueKey('stage-crew-resource-save')));
    await tester.pumpAndSettle();

    expect(find.text(stageCrewResourceUrlErrorMessage), findsOneWidget);
  });

  test('resource URL validation accepts HTTPS and rejects unsafe inputs', () {
    final safe = StageCrewResource.fromJson({
      'resource_id': 'safe',
      'title': 'Reference',
      'resource_type': 'practice_video',
      'external_url': 'https://example.com/video',
      'status': 'active',
    });
    final unsafe = StageCrewResource.fromJson({
      'resource_id': 'unsafe',
      'title': 'Unsafe',
      'resource_type': 'other',
      'external_url': 'javascript:alert(1)',
      'status': 'active',
    });
    expect(safe.safeExternalUri?.host, 'example.com');
    expect(unsafe.safeExternalUri, isNull);
    expect(
      parseStageCrewResourceHttpsUri('https://example.com/path'),
      isNotNull,
    );
    for (final invalid in [
      'xxx.com',
      'http://example.com',
      'https:///path',
      'https://example.com/with space',
      'javascript:alert(1)',
      'data:text/plain,test',
      'file:///tmp/test',
    ]) {
      expect(parseStageCrewResourceHttpsUri(invalid), isNull, reason: invalid);
    }
  });
}

Future<void> _pumpHome(
  WidgetTester tester,
  StageCrewActivityRepository repository,
  StageMyCrew initial,
  List<StageMyCrew> crews,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: StageCrewHomeScreen(
        initialCrew: initial,
        availableCrews: crews,
        repository: repository,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeActivityRepository implements StageCrewActivityRepository {
  _FakeActivityRepository({
    this.memberCrewIds = const {},
    this.announcements = const [],
    this.resourceSaveError,
  });

  final Set<String> memberCrewIds;
  final List<StageCrewAnnouncement> announcements;
  final Object? resourceSaveError;
  final List<String> homeCrewIds = [];
  final List<String> activityCrewIds = [];
  final List<String> attendanceResponses = [];
  final List<String> resourceSaveUrls = [];

  @override
  Future<StageCrewHome> fetchCrewHome(String crewId) async {
    homeCrewIds.add(crewId);
    return StageCrewHome(
      crewId: crewId,
      crewName: crewId == 'crew-a' ? 'Crew A' : 'Crew B',
      membershipRole: memberCrewIds.contains(crewId) ? 'member' : 'admin',
      nextPractice: _practice(crewId),
      openPoll: _poll,
      latestAnnouncement: announcements.isEmpty ? null : announcements.first,
    );
  }

  @override
  Future<StageCrewActivitySnapshot> fetchCrewActivity(String crewId) async {
    activityCrewIds.add(crewId);
    return StageCrewActivitySnapshot(
      isAdmin: !memberCrewIds.contains(crewId),
      practices: [_practice(crewId)],
      polls: [_poll],
      announcements: announcements,
      resources: const [],
      targets: const [],
    );
  }

  @override
  Future<void> respondAttendance({
    required String crewId,
    required String practiceId,
    required String response,
  }) async {
    attendanceResponses.add(response);
  }

  @override
  Future<void> cancelPoll({
    required String crewId,
    required String pollId,
  }) async {}
  @override
  Future<String> createPoll({
    required String crewId,
    required String title,
    required List<({DateTime startsAt, DateTime endsAt})> options,
  }) async => 'poll';
  @override
  Future<void> finalizePoll({
    required String crewId,
    required String pollId,
    required String optionId,
    bool createPractice = true,
  }) async {}
  @override
  Future<void> respondPoll({
    required String crewId,
    required String pollId,
    required Map<String, String> responses,
  }) async {}
  @override
  Future<String> saveAnnouncement({
    required String crewId,
    String? announcementId,
    required String title,
    required String body,
    required String status,
  }) async => 'announcement';
  @override
  Future<String> savePractice({
    required String crewId,
    String? practiceId,
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    String? areaId,
    String? locationName,
    String? meetingNote,
    String? description,
    DateTime? attendanceDeadline,
  }) async => 'practice';
  @override
  Future<String> saveResource({
    required String crewId,
    String? resourceId,
    required String title,
    required String resourceType,
    required String externalUrl,
    String? description,
    required String status,
  }) async {
    resourceSaveUrls.add(externalUrl);
    if (resourceSaveError != null) throw resourceSaveError!;
    return 'resource';
  }

  @override
  Future<void> setPracticeStatus({
    required String crewId,
    required String practiceId,
    required String status,
  }) async {}
  @override
  Future<String> setTargetEvent({
    required String crewId,
    required String eventId,
  }) async => 'target';
}

StageCrewPractice _practice(String crewId) => StageCrewPractice(
  practiceId: 'practice-$crewId',
  title: '${crewId == 'crew-a' ? 'Crew A' : 'Crew B'} の次回練習',
  startsAt: DateTime.now().add(const Duration(days: 7)),
  endsAt: DateTime.now().add(const Duration(days: 7, hours: 2)),
  status: 'scheduled',
  attendingCount: 1,
  maybeCount: 0,
  notAttendingCount: 0,
);

final _poll = StageCrewPoll(
  pollId: 'poll-1',
  title: '9月の練習日',
  status: 'open',
  options: [
    StageCrewPollOption(
      optionId: 'option-1',
      startsAt: DateTime.now().add(const Duration(days: 10)),
      endsAt: DateTime.now().add(const Duration(days: 10, hours: 2)),
      availableCount: 1,
      maybeCount: 0,
      unavailableCount: 0,
    ),
  ],
);

const _announcement = StageCrewAnnouncement(
  announcementId: 'announcement-1',
  title: 'Crew announcement',
  status: 'published',
  body: 'Crew announcement body',
  authorDisplayName: 'Mio',
);

final _adminCrew = StageMyCrew(
  crewId: 'crew-a',
  crewName: 'Crew A',
  crewAvatarUrl: null,
  crewBio: 'Admin Crew',
  membershipRole: 'admin',
  isCreator: true,
  joinedAt: DateTime(2026),
  activeMemberCount: 2,
  openRecruitmentCount: 1,
  danceGenreNames: const ['HIPHOP'],
  areaNames: const ['東京'],
);

final _memberCrew = StageMyCrew(
  crewId: 'crew-b',
  crewName: 'Crew B',
  crewAvatarUrl: null,
  crewBio: 'Member Crew',
  membershipRole: 'member',
  isCreator: false,
  joinedAt: DateTime(2026),
  activeMemberCount: 3,
  openRecruitmentCount: 0,
  danceGenreNames: const ['JAZZ'],
  areaNames: const ['神奈川'],
);

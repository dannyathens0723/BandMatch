import 'dart:async';

import 'package:app/models/stage_crew_management.dart';
import 'package:app/models/stage_my_crew.dart';
import 'package:app/services/stage_crew_management_service.dart';
import 'package:app/stage_preview/theme/stage_design_tokens.dart';
import 'package:app/stage_profile_flow/stage_crew_management_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Crew creation validates, confirms, and submits only once', (
    tester,
  ) async {
    final repository = _FakeManagementRepository();
    await _pumpLauncher(tester, repository);

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('入力内容を確認'));
    await tester.pump();
    expect(find.text('クルー名を入力してください'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('stage-crew-name')),
      'STAGE TEST CREW',
    );
    await tester.tap(find.byKey(const ValueKey('stage-option-genre-1')));
    await tester.tap(find.text('入力内容を確認'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('stage-confirmation-dialog')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('stage-confirm-submit')));
    await tester.pumpAndSettle();

    expect(repository.createCrewCalls, 1);
    expect(find.text('OPEN'), findsOneWidget);
  });

  testWidgets('managed recruitment opens applicants and accepts atomically', (
    tester,
  ) async {
    final repository = _FakeManagementRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: StageDesignTokens.theme,
        home: StageManagedCrewScreen(crew: _myCrew, repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('stage-managed-recruitment-post-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stage-open-applicants')));
    await tester.pumpAndSettle();
    expect(find.text('Applicant'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('stage-applicant-application-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stage-accept-application')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確定する'));
    await tester.pumpAndSettle();

    expect(repository.decisions, ['accepted']);
    expect(find.text('この応募は承認済みです。'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('stage-accept-application')),
      findsNothing,
    );
  });

  testWidgets('managed Crew refresh replaces data and exposes retry', (
    tester,
  ) async {
    final repository = _FakeManagementRepository();
    await _pumpManagedCrew(tester, repository);
    expect(repository.fetchRecruitmentCalls, 1);

    final refresh = Completer<List<StageManagedRecruitment>>();
    repository.nextRecruitments = refresh;
    await tester.tap(find.text('更新'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('stage-managed-crew-loading')),
      findsOneWidget,
    );
    refresh.complete([_postWith(title: 'Authoritative title')]);
    await tester.pumpAndSettle();
    expect(repository.fetchRecruitmentCalls, 2);
    expect(find.text('Authoritative title'), findsOneWidget);

    repository.failNextRecruitments = true;
    await tester.tap(find.text('更新'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('stage-managed-crew-error')),
      findsOneWidget,
    );
    expect(find.text('backend refresh failed'), findsNothing);

    await tester.tap(find.text('再試行'));
    await tester.pumpAndSettle();
    expect(find.text('Authoritative title'), findsOneWidget);
  });

  testWidgets('managed Crew reloads after Crew and recruitment mutations', (
    tester,
  ) async {
    final repository = _FakeManagementRepository();
    await _pumpManagedCrew(tester, repository);

    await tester.tap(find.text('クルーを編集'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('stage-crew-name')),
      'Updated Crew',
    );
    await _confirmEditor(tester);
    expect(find.text('Updated Crew'), findsOneWidget);

    await tester.tap(find.text('募集を作成'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('stage-recruitment-title')),
      'New recruitment',
    );
    await tester.enterText(
      find.byKey(const ValueKey('stage-recruitment-body')),
      'New recruitment body',
    );
    await _confirmEditor(tester);
    expect(find.text('New recruitment'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('stage-managed-recruitment-post-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('募集内容を編集'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('stage-recruitment-title')),
      'Edited recruitment',
    );
    await _confirmEditor(tester);
    expect(find.text('Edited recruitment'), findsOneWidget);
    await tester.tap(find.text('募集を終了'));
    await tester.pumpAndSettle();
    expect(find.text('募集終了'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Edited recruitment'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('stage-managed-recruitment-post-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('募集を再開'));
    await tester.pumpAndSettle();
    expect(find.text('募集中'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(repository.statusChanges, ['closed', 'open']);
    expect(repository.fetchRecruitmentCalls, greaterThanOrEqualTo(8));
  });

  testWidgets(
    'Crew management uses one mobile canvas on narrow and wide views',
    (tester) async {
      final repository = _FakeManagementRepository();
      await _setSurface(tester, const Size(1200, 900));
      await tester.pumpWidget(
        MaterialApp(
          theme: StageDesignTokens.theme,
          home: StageManagedCrewScreen(crew: _myCrew, repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      final wideCanvas = tester.getRect(
        find.byKey(const ValueKey('stage-mobile-page-canvas')),
      );
      expect(wideCanvas.width, StageDesignTokens.maxContentWidth);
      expect(wideCanvas.center.dx, 600);

      await _setSurface(tester, const Size(390, 844));
      await tester.pump();
      final narrowCanvas = tester.getRect(
        find.byKey(const ValueKey('stage-mobile-page-canvas')),
      );
      expect(narrowCanvas.width, 390);
      expect(tester.takeException(), isNull);
    },
  );
}

class _FakeManagementRepository implements StageCrewManagementRepository {
  int createCrewCalls = 0;
  int fetchCrewCalls = 0;
  int fetchRecruitmentCalls = 0;
  final List<String> decisions = [];
  final List<String> statusChanges = [];
  StageManagedCrew crew = _crew;
  List<StageManagedRecruitment> recruitments = [_post];
  Completer<List<StageManagedRecruitment>>? nextRecruitments;
  bool failNextRecruitments = false;

  @override
  Future<StageCrewFormOptions> fetchFormOptions() async => _options;

  @override
  Future<StageManagedCrew> fetchManagedCrew(String crewId) async {
    fetchCrewCalls += 1;
    return crew;
  }

  @override
  Future<List<StageManagedRecruitment>> fetchRecruitments(String crewId) async {
    fetchRecruitmentCalls += 1;
    if (failNextRecruitments) {
      failNextRecruitments = false;
      throw StateError('backend refresh failed');
    }
    final pending = nextRecruitments;
    if (pending != null) {
      nextRecruitments = null;
      recruitments = await pending.future;
    }
    return List.unmodifiable(recruitments);
  }

  @override
  Future<String> createCrew({
    required String name,
    required String bio,
    required String? activityFrequency,
    required List<String> genreIds,
    required String? areaId,
  }) async {
    createCrewCalls += 1;
    return 'crew-1';
  }

  @override
  Future<void> updateCrew({
    required String crewId,
    required String name,
    required String bio,
    required String? activityFrequency,
    required List<String> genreIds,
    required String? areaId,
  }) async {
    crew = StageManagedCrew(
      crewId: crewId,
      name: name,
      bio: bio,
      activityFrequency: activityFrequency,
      danceGenreIds: genreIds,
      danceGenreNames: genreIds.map((_) => 'HIPHOP').toList(),
      areaId: areaId,
      areaName: null,
      activeMemberCount: crew.activeMemberCount,
    );
  }

  @override
  Future<String> createRecruitment({
    required String crewId,
    required String title,
    required String body,
    required List<String> genreIds,
    required String? areaId,
  }) async {
    final post = StageManagedRecruitment(
      postId: 'post-${recruitments.length + 1}',
      crewId: crewId,
      title: title,
      body: body,
      status: 'open',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      danceGenreIds: genreIds,
      danceGenreNames: genreIds.map((_) => 'HIPHOP').toList(),
      areaId: areaId,
      areaName: null,
      pendingApplicationCount: 0,
    );
    recruitments = [...recruitments, post];
    return post.postId;
  }

  @override
  Future<void> updateRecruitment({
    required String postId,
    required String title,
    required String body,
    required List<String> genreIds,
    required String? areaId,
  }) async {
    recruitments = recruitments
        .map(
          (post) => post.postId == postId
              ? _postWith(
                  source: post,
                  title: title,
                  body: body,
                  genreIds: genreIds,
                )
              : post,
        )
        .toList(growable: false);
  }

  @override
  Future<void> setRecruitmentStatus(String postId, String status) async {
    statusChanges.add(status);
    recruitments = recruitments
        .map(
          (post) => post.postId == postId
              ? _postWith(source: post, status: status)
              : post,
        )
        .toList(growable: false);
  }

  @override
  Future<List<StageRecruitmentApplicant>> fetchApplicants(
    String postId,
  ) async => [_applicant];

  @override
  Future<StageApplicationDecision> decideApplication(
    String applicationId,
    String decision,
  ) async {
    decisions.add(decision);
    return StageApplicationDecision(
      applicationId: applicationId,
      applicationStatus: decision,
      membershipStatus: decision == 'accepted' ? 'active' : null,
    );
  }
}

Future<void> _pumpLauncher(
  WidgetTester tester,
  StageCrewManagementRepository repository,
) async {
  tester.view.physicalSize = const Size(430, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: StageDesignTokens.theme,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => StageCrewEditorScreen(repository: repository),
              ),
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpManagedCrew(
  WidgetTester tester,
  StageCrewManagementRepository repository,
) async {
  await _setSurface(tester, const Size(430, 1000));
  await tester.pumpWidget(
    MaterialApp(
      theme: StageDesignTokens.theme,
      home: StageManagedCrewScreen(crew: _myCrew, repository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _confirmEditor(WidgetTester tester) async {
  await tester.tap(find.text('入力内容を確認'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('stage-confirm-submit')));
  await tester.pumpAndSettle();
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _options = StageCrewFormOptions(
  genres: [StageCrewOption(id: 'genre-1', name: 'HIPHOP')],
  areas: [],
);

const _crew = StageManagedCrew(
  crewId: 'crew-1',
  name: 'Crew One',
  bio: 'Dance Crew',
  activityFrequency: 'weekly_1_2',
  danceGenreIds: ['genre-1'],
  danceGenreNames: ['HIPHOP'],
  areaId: null,
  areaName: null,
  activeMemberCount: 1,
);

final _post = StageManagedRecruitment(
  postId: 'post-1',
  crewId: 'crew-1',
  title: 'Member wanted',
  body: 'Join us',
  status: 'open',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  danceGenreIds: const ['genre-1'],
  danceGenreNames: const ['HIPHOP'],
  areaId: null,
  areaName: null,
  pendingApplicationCount: 1,
);

StageManagedRecruitment _postWith({
  StageManagedRecruitment? source,
  String? title,
  String? body,
  String? status,
  List<String>? genreIds,
}) {
  final post = source ?? _post;
  return StageManagedRecruitment(
    postId: post.postId,
    crewId: post.crewId,
    title: title ?? post.title,
    body: body ?? post.body,
    status: status ?? post.status,
    createdAt: post.createdAt,
    updatedAt: DateTime(2026, 2),
    danceGenreIds: genreIds ?? post.danceGenreIds,
    danceGenreNames: genreIds == null
        ? post.danceGenreNames
        : genreIds.map((_) => 'HIPHOP').toList(),
    areaId: post.areaId,
    areaName: post.areaName,
    pendingApplicationCount: post.pendingApplicationCount,
  );
}

final _applicant = StageRecruitmentApplicant(
  applicationId: 'application-1',
  postId: 'post-1',
  crewId: 'crew-1',
  applicantUserId: 'user-2',
  displayName: 'Applicant',
  avatarUrl: null,
  experienceLevel: 'intermediate',
  danceGenreNames: const ['HIPHOP'],
  performanceRoleNames: const ['ダンサー'],
  primaryPerformanceRoleName: 'ダンサー',
  applicationNote: '参加したいです',
  applicationStatus: 'pending',
  appliedAt: DateTime(2026),
  respondedAt: null,
);

final _myCrew = StageMyCrew(
  crewId: 'crew-1',
  crewName: 'Crew One',
  crewAvatarUrl: null,
  crewBio: 'Dance Crew',
  membershipRole: 'admin',
  isCreator: true,
  joinedAt: DateTime(2026),
  activeMemberCount: 1,
  openRecruitmentCount: 1,
  danceGenreNames: const ['HIPHOP'],
  areaNames: const [],
);

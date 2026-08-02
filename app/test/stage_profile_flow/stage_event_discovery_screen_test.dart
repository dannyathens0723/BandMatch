import 'dart:async';

import 'package:app/models/stage_event.dart';
import 'package:app/services/stage_event_discovery_service.dart';
import 'package:app/stage_preview/theme/stage_design_tokens.dart';
import 'package:app/stage_profile_flow/stage_authenticated_home_screen.dart';
import 'package:app/stage_profile_flow/stage_authenticated_my_page_screen.dart';
import 'package:app/stage_profile_flow/stage_authenticated_shell.dart';
import 'package:app/stage_profile_flow/stage_event_detail_screen.dart';
import 'package:app/stage_profile_flow/stage_event_discovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Stage tab opens real discovery while Home stays initial center',
    (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: StageDesignTokens.theme,
          home: StageAuthenticatedShell(
            stageBuilder: (_) => StageEventDiscoveryScreen(
              repository: _FakeStageRepository(events: const []),
            ),
            myPageBuilder: (_) => const StageAuthenticatedMyPageScreen(
              email: 'stage@example.com',
            ),
          ),
        ),
      );

      expect(find.byType(StageAuthenticatedHomeScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('stage-tab-home')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('stage-tab-stage')));
      await tester.pumpAndSettle();

      expect(find.byType(StageEventDiscoveryScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('stage-event-empty')), findsOneWidget);
      expect(find.text('MVPで順次公開'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('stage-tab-home')));
      await tester.pumpAndSettle();
      expect(find.byType(StageAuthenticatedHomeScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('stage-tab-myPage')));
      await tester.pumpAndSettle();
      expect(find.byType(StageAuthenticatedMyPageScreen), findsOneWidget);
    },
  );

  testWidgets('Stage discovery shows an independent loading state', (
    tester,
  ) async {
    final completer = Completer<List<StageEvent>>();
    await _pumpDiscovery(
      tester,
      _FakeStageRepository(eventsLoader: () => completer.future),
    );

    expect(find.byKey(const ValueKey('stage-event-loading')), findsOneWidget);
    completer.complete(const []);
  });

  testWidgets('Stage discovery renders Supabase event projection data', (
    tester,
  ) async {
    await _pumpDiscovery(tester, _FakeStageRepository(events: [_event]));
    await tester.pumpAndSettle();

    expect(find.text(_event.title), findsOneWidget);
    expect(find.text('大会'), findsWidgets);
    expect(find.text('HIPHOP'), findsOneWidget);
    expect(find.text('渋谷'), findsOneWidget);
    expect(find.text('BandMatch'), findsNothing);
  });

  testWidgets('Stage discovery shows the empty and deferred lesson states', (
    tester,
  ) async {
    await _pumpDiscovery(tester, _FakeStageRepository(events: const []));
    await tester.pumpAndSettle();

    expect(find.text('公開中のイベントはまだありません'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('stage-lessons-deferred')),
      findsOneWidget,
    );
  });

  testWidgets('Stage backend failure is controlled and retryable', (
    tester,
  ) async {
    final repository = _RetryStageRepository();
    await _pumpDiscovery(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('stage-event-error')), findsOneWidget);
    expect(find.text('backend exploded'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('stage-event-retry')));
    await tester.pumpAndSettle();

    expect(repository.listCalls, 2);
    expect(find.text(_event.title), findsOneWidget);
  });

  testWidgets('opening event detail and back preserves the discovery list', (
    tester,
  ) async {
    await _pumpDiscovery(
      tester,
      _FakeStageRepository(events: [_event]),
      detailBuilder: (_, event, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            event.title,
            key: const ValueKey('stage-event-detail-destination'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey('stage-event-card-${_event.eventId}')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('stage-event-detail-destination')),
      findsOneWidget,
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(_event.title), findsOneWidget);
  });

  testWidgets('event detail confirms and opens the official external link', (
    tester,
  ) async {
    Uri? openedUri;
    await _setSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: StageDesignTokens.theme,
        home: StageEventDetailScreen(
          eventId: _event.eventId,
          repository: _FakeStageRepository(events: [_event]),
          externalLinkOpener: (uri) async {
            openedUri = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final action = find.text('公式情報・申込ページを開く');
    await tester.scrollUntilVisible(
      action,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.text('外部サイトを開きますか？'), findsOneWidget);
    expect(openedUri, isNull);

    await tester.tap(
      find.byKey(const ValueKey('stage-event-confirm-external-link')),
    );
    await tester.pumpAndSettle();

    expect(openedUri, Uri.parse('https://example.com/event/apply'));
  });
}

final _event = StageEvent(
  eventId: 'event-1',
  organizerId: 'organizer-1',
  organizerName: 'STAGE公式イベント局',
  organizerOfficialUrl: 'https://example.com/organizer',
  title: 'TOKYO DANCE CHALLENGE 2026',
  category: 'competition',
  summary: 'Danceジャンルを横断したオープン大会です。',
  eligibilitySummary: '18歳以上のソロ・チーム',
  venueName: '渋谷 STAGE HALL',
  startsAt: DateTime(2026, 11, 15, 13),
  endsAt: DateTime(2026, 11, 15, 19),
  applicationDeadline: DateTime(2026, 10, 31, 23, 59),
  feeSummary: '1名 3,000円',
  officialUrl: 'https://example.com/event/apply',
  sourceUrl: 'https://example.com/event',
  sourceType: 'official_site',
  lastVerifiedAt: DateTime(2026, 8, 1),
  eventStatus: 'applications_open',
  danceGenreNames: const ['HIPHOP'],
  areaNames: const ['渋谷'],
);

class _FakeStageRepository implements StageEventDiscoveryRepository {
  _FakeStageRepository({this.events, this.eventsLoader});

  final List<StageEvent>? events;
  final Future<List<StageEvent>> Function()? eventsLoader;

  @override
  Future<List<StageEvent>> fetchPublishedEvents() {
    return eventsLoader?.call() ?? Future.value(events ?? const []);
  }

  @override
  Future<StageEvent?> fetchPublishedEvent(String eventId) async {
    for (final event in events ?? const <StageEvent>[]) {
      if (event.eventId == eventId) return event;
    }
    return null;
  }
}

class _RetryStageRepository implements StageEventDiscoveryRepository {
  int listCalls = 0;

  @override
  Future<List<StageEvent>> fetchPublishedEvents() async {
    listCalls += 1;
    if (listCalls == 1) throw StateError('backend exploded');
    return [_event];
  }

  @override
  Future<StageEvent?> fetchPublishedEvent(String eventId) async => _event;
}

Future<void> _pumpDiscovery(
  WidgetTester tester,
  StageEventDiscoveryRepository repository, {
  StageEventDetailBuilder? detailBuilder,
}) async {
  await _setSurface(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: StageDesignTokens.theme,
      home: Scaffold(
        body: StageEventDiscoveryScreen(
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

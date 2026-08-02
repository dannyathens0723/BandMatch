import 'dart:async';

import 'package:app/models/stage_studio.dart';
import 'package:app/services/stage_studio_discovery_service.dart';
import 'package:app/stage_preview/theme/stage_design_tokens.dart';
import 'package:app/stage_profile_flow/stage_authenticated_home_screen.dart';
import 'package:app/stage_profile_flow/stage_authenticated_my_page_screen.dart';
import 'package:app/stage_profile_flow/stage_authenticated_shell.dart';
import 'package:app/stage_profile_flow/stage_studio_detail_screen.dart';
import 'package:app/stage_profile_flow/stage_studio_discovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Studio tab opens real discovery while Home stays initial center',
    (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: StageDesignTokens.theme,
          home: StageAuthenticatedShell(
            studioBuilder: (_) => StageStudioDiscoveryScreen(
              repository: _FakeStudioRepository(studios: const []),
            ),
            myPageBuilder: (_) => const StageAuthenticatedMyPageScreen(
              email: 'stage@example.com',
            ),
          ),
        ),
      );

      expect(find.byType(StageAuthenticatedHomeScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('stage-tab-home')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('stage-tab-studio')));
      await tester.pumpAndSettle();

      expect(find.byType(StageStudioDiscoveryScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('stage-studio-empty')), findsOneWidget);
      expect(find.text('MVPで順次公開'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('stage-tab-home')));
      await tester.pumpAndSettle();
      expect(find.byType(StageAuthenticatedHomeScreen), findsOneWidget);
    },
  );

  testWidgets('Studio discovery shows an independent loading state', (
    tester,
  ) async {
    final completer = Completer<List<StageStudio>>();
    await _pumpDiscovery(
      tester,
      _FakeStudioRepository(studiosLoader: () => completer.future),
    );

    expect(find.byKey(const ValueKey('stage-studio-loading')), findsOneWidget);
    completer.complete(const []);
  });

  testWidgets('Studio discovery renders Supabase projection data', (
    tester,
  ) async {
    await _pumpDiscovery(
      tester,
      _FakeStudioRepository(studios: [_shinjukuStudio]),
    );
    await tester.pumpAndSettle();

    expect(find.text('STUDIO LUZ 新宿'), findsOneWidget);
    expect(find.text('西新宿駅 徒歩3分'), findsOneWidget);
    expect(find.text('¥2,400/h〜'), findsOneWidget);
    expect(find.text('鏡'), findsWidgets);
    expect(find.text('BandMatch'), findsNothing);
  });

  testWidgets(
    'Studio discovery supports keyword area facility and price filters',
    (tester) async {
      await _pumpDiscovery(
        tester,
        _FakeStudioRepository(studios: [_shinjukuStudio, _shibuyaStudio]),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('stage-studio-search')),
        '西新宿駅',
      );
      await tester.pump();
      expect(find.text('STUDIO LUZ 新宿'), findsOneWidget);
      expect(find.text('DANCE BASE 渋谷'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('stage-studio-search')),
        '',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, '渋谷'));
      await tester.pump();
      expect(find.text('DANCE BASE 渋谷'), findsOneWidget);
      expect(find.text('STUDIO LUZ 新宿'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'すべて').first);
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, '更衣室'));
      await tester.pump();
      expect(find.text('STUDIO LUZ 新宿'), findsOneWidget);
      expect(find.text('DANCE BASE 渋谷'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'すべて').at(1));
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, '¥2,000/h以下'));
      await tester.pump();
      expect(find.text('DANCE BASE 渋谷'), findsOneWidget);
      expect(find.text('STUDIO LUZ 新宿'), findsNothing);
    },
  );

  testWidgets('Studio backend failure is controlled and retryable', (
    tester,
  ) async {
    final repository = _RetryStudioRepository();
    await _pumpDiscovery(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('stage-studio-error')), findsOneWidget);
    expect(find.text('backend exploded'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('stage-studio-retry')));
    await tester.pumpAndSettle();

    expect(repository.listCalls, 2);
    expect(find.text('STUDIO LUZ 新宿'), findsOneWidget);
  });

  testWidgets('opening Studio detail and back preserves the discovery list', (
    tester,
  ) async {
    await _pumpDiscovery(
      tester,
      _FakeStudioRepository(studios: [_shinjukuStudio]),
      detailBuilder: (_, studio, _) => Scaffold(
        appBar: AppBar(),
        body: Text(
          studio.name,
          key: const ValueKey('stage-studio-detail-destination'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey('stage-studio-card-${_shinjukuStudio.studioId}')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('stage-studio-detail-destination')),
      findsOneWidget,
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('STUDIO LUZ 新宿'), findsOneWidget);
  });

  testWidgets('Studio detail confirms and opens a valid HTTPS booking link', (
    tester,
  ) async {
    Uri? openedUri;
    await _pumpDetail(
      tester,
      _shinjukuStudio,
      externalLinkOpener: (uri) async {
        openedUri = uri;
        return true;
      },
    );

    final action = find.text('外部予約ページを開く');
    await tester.scrollUntilVisible(
      action,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.text('外部予約ページを開きますか？'), findsOneWidget);
    expect(openedUri, isNull);

    await tester.tap(
      find.byKey(const ValueKey('stage-studio-confirm-external-link')),
    );
    await tester.pumpAndSettle();
    expect(openedUri, Uri.parse('https://example.com/studio/book'));
  });

  testWidgets('Studio detail disables an invalid external URL safely', (
    tester,
  ) async {
    await _pumpDetail(tester, _invalidLinkStudio);

    final action = find.text('予約ページを確認できません');
    await tester.scrollUntilVisible(
      action,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(action, findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(of: action, matching: find.byType(FilledButton)),
    );
    expect(button.onPressed, isNull);
  });
}

final _shinjukuStudio = _studio(
  id: 'studio-1',
  name: 'STUDIO LUZ 新宿',
  areaName: '新宿',
  station: '西新宿駅',
  price: 2400,
  facilities: const ['鏡', '音響', '更衣室'],
  bookingUrl: 'https://example.com/studio/book',
);

final _shibuyaStudio = _studio(
  id: 'studio-2',
  name: 'DANCE BASE 渋谷',
  areaName: '渋谷',
  station: '渋谷駅',
  price: 1800,
  facilities: const ['鏡', '音響'],
  bookingUrl: 'https://example.com/shibuya/book',
);

final _invalidLinkStudio = _studio(
  id: 'studio-3',
  name: 'URL確認待ちスタジオ',
  areaName: '新宿',
  station: '新宿駅',
  price: 2000,
  facilities: const ['鏡'],
  bookingUrl: 'http://unsafe.example.com/book',
);

StageStudio _studio({
  required String id,
  required String name,
  required String areaName,
  required String station,
  required int price,
  required List<String> facilities,
  required String bookingUrl,
}) {
  return StageStudio(
    studioId: id,
    name: name,
    areaId: 'area-$areaName',
    areaName: areaName,
    addressDisplay: '東京都$areaName区1-2-3',
    latitude: 35.69,
    longitude: 139.70,
    nearestStationName: station,
    walkingMinutes: 3,
    accessNote: '$stationから徒歩3分',
    openingHoursSummary: '9:00〜23:00',
    minimumHourlyPriceYen: price,
    websiteUrl: null,
    bookingUrl: bookingUrl,
    reviewSummary: 'ダンス練習に必要な設備を確認済みです。',
    rating: 4.5,
    ratingCount: 12,
    sourceLabel: '公式サイト',
    sourceUrl: 'https://example.com/studio',
    lastVerifiedAt: DateTime(2026, 8, 1),
    roomCount: 1,
    maxCapacity: 12,
    largestRoomSizeSqm: 42,
    facilityNames: facilities,
    rooms: [
      StageStudioRoom(
        roomId: 'room-$id',
        name: 'Aスタジオ',
        capacity: 12,
        sizeSqm: 42,
        hourlyPriceYen: price,
        facilityNames: facilities,
      ),
    ],
  );
}

class _FakeStudioRepository implements StageStudioDiscoveryRepository {
  _FakeStudioRepository({this.studios, this.studiosLoader});

  final List<StageStudio>? studios;
  final Future<List<StageStudio>> Function()? studiosLoader;

  @override
  Future<List<StageStudio>> fetchPublishedStudios() {
    return studiosLoader?.call() ?? Future.value(studios ?? const []);
  }

  @override
  Future<StageStudio?> fetchPublishedStudio(String studioId) async {
    for (final studio in studios ?? const <StageStudio>[]) {
      if (studio.studioId == studioId) return studio;
    }
    return null;
  }
}

class _RetryStudioRepository implements StageStudioDiscoveryRepository {
  int listCalls = 0;

  @override
  Future<List<StageStudio>> fetchPublishedStudios() async {
    listCalls += 1;
    if (listCalls == 1) throw StateError('backend exploded');
    return [_shinjukuStudio];
  }

  @override
  Future<StageStudio?> fetchPublishedStudio(String studioId) async =>
      _shinjukuStudio;
}

Future<void> _pumpDiscovery(
  WidgetTester tester,
  StageStudioDiscoveryRepository repository, {
  StageStudioDetailBuilder? detailBuilder,
}) async {
  await _setSurface(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: StageDesignTokens.theme,
      home: Scaffold(
        body: StageStudioDiscoveryScreen(
          repository: repository,
          detailBuilder: detailBuilder,
        ),
      ),
    ),
  );
}

Future<void> _pumpDetail(
  WidgetTester tester,
  StageStudio studio, {
  StageStudioExternalLinkOpener? externalLinkOpener,
}) async {
  await _setSurface(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: StageDesignTokens.theme,
      home: StageStudioDetailScreen(
        studioId: studio.studioId,
        repository: _FakeStudioRepository(studios: [studio]),
        externalLinkOpener: externalLinkOpener,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

import 'dart:async';

import 'package:app/screens/stage_taxonomy_read_only_screen.dart';
import 'package:app/services/stage_master_data_service.dart';
import 'package:app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('displays independent initial loading states', (tester) async {
    final genreResponse = Completer<dynamic>();
    final roleResponse = Completer<dynamic>();
    final service = _service(
      fetcher: (functionName, _) {
        return functionName == 'get_active_genres_v1'
            ? genreResponse.future
            : roleResponse.future;
      },
    );

    await _pumpScreen(tester, service);

    expect(find.text('読み込み中…'), findsNWidgets(2));
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));

    genreResponse.complete(_genreRows());
    roleResponse.complete(_roleRows());
    await tester.pumpAndSettle();
  });

  testWidgets('displays 11 real-response genres in stable order', (
    tester,
  ) async {
    final service = _service(
      fetcher: (functionName, _) async => functionName == 'get_active_genres_v1'
          ? _genreRows().reversed.toList()
          : _roleRows(),
    );

    await _pumpScreenAndSettle(tester, service);

    expect(find.text('11件'), findsOneWidget);
    for (final name in _genreNames) {
      expect(find.text(name), findsOneWidget);
    }
    _expectVerticalOrder(tester, _genreNames);
    expect(find.text('想定件数（11件）と異なります。'), findsNothing);
  });

  testWidgets('displays 4 real-response roles in stable order', (tester) async {
    final service = _service(
      fetcher: (functionName, _) async => functionName == 'get_active_genres_v1'
          ? _genreRows()
          : _roleRows().reversed.toList(),
    );

    await _pumpScreenAndSettle(tester, service);

    expect(find.text('4件'), findsOneWidget);
    for (final name in _roleNames) {
      expect(find.text(name), findsOneWidget);
    }
    _expectVerticalOrder(tester, _roleNames);
    expect(find.text('想定件数（4件）と異なります。'), findsNothing);
  });

  testWidgets('shows genres and a controlled login-required role state', (
    tester,
  ) async {
    final service = _service(
      authenticated: false,
      fetcher: (_, _) async => _genreRows(),
    );

    await _pumpScreenAndSettle(tester, service);

    expect(find.text('11件'), findsOneWidget);
    expect(find.text(_genreNames.first), findsOneWidget);
    expect(find.text('役割を確認するにはログインが必要です'), findsOneWidget);
    expect(find.text(_roleNames.first), findsNothing);
  });

  testWidgets('genre failure does not hide successful roles', (tester) async {
    final service = _service(
      fetcher: (functionName, _) async {
        if (functionName == 'get_active_genres_v1') {
          throw StateError('genre network failure');
        }
        return _roleRows();
      },
    );

    await _pumpScreenAndSettle(tester, service);

    expect(find.text('データを読み込めませんでした。通信状況を確認して再試行してください。'), findsOneWidget);
    expect(find.text('4件'), findsOneWidget);
    expect(find.text(_roleNames.first), findsOneWidget);
  });

  testWidgets('role failure does not hide successful genres', (tester) async {
    final service = _service(
      fetcher: (functionName, _) async {
        if (functionName == 'get_active_performance_roles_v1') {
          throw StateError('role network failure');
        }
        return _genreRows();
      },
    );

    await _pumpScreenAndSettle(tester, service);

    expect(find.text('データを読み込めませんでした。通信状況を確認して再試行してください。'), findsOneWidget);
    expect(find.text('11件'), findsOneWidget);
    expect(find.text(_genreNames.first), findsOneWidget);
  });

  testWidgets('parsing failure uses a controlled schema message', (
    tester,
  ) async {
    final service = _service(
      fetcher: (functionName, _) async => functionName == 'get_active_genres_v1'
          ? [
              {'id': 'not-a-uuid'},
            ]
          : _roleRows(),
    );

    await _pumpScreenAndSettle(tester, service);

    expect(find.text('データ形式を確認できませんでした。'), findsOneWidget);
    expect(find.text('4件'), findsOneWidget);
    expect(find.text(_roleNames.first), findsOneWidget);
  });

  testWidgets('genre retry reloads only the failed genre section', (
    tester,
  ) async {
    var genreCalls = 0;
    var roleCalls = 0;
    final service = _service(
      fetcher: (functionName, _) async {
        if (functionName == 'get_active_genres_v1') {
          genreCalls++;
          if (genreCalls == 1) {
            throw StateError('temporary genre failure');
          }
          return _genreRows();
        }
        roleCalls++;
        return _roleRows();
      },
    );

    await _pumpScreenAndSettle(tester, service);
    expect(genreCalls, 1);
    expect(roleCalls, 1);

    final retryButton = find.byKey(const ValueKey('genre-retry'));
    await tester.ensureVisible(retryButton);
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(genreCalls, 2);
    expect(roleCalls, 1);
    expect(find.text('11件'), findsOneWidget);
    expect(find.text('4件'), findsOneWidget);
  });

  testWidgets('empty responses are distinct from failures', (tester) async {
    final service = _service(fetcher: (_, _) async => <dynamic>[]);

    await _pumpScreenAndSettle(tester, service);

    expect(find.text('ダンスジャンルはありません'), findsOneWidget);
    expect(find.text('パフォーマンス役割はありません'), findsOneWidget);
    expect(find.text('0件'), findsNWidgets(2));
    expect(find.text('データを読み込めませんでした。通信状況を確認して再試行してください。'), findsNothing);
  });

  testWidgets('unexpected counts warn without hiding returned rows', (
    tester,
  ) async {
    final service = _service(
      fetcher: (functionName, _) async => functionName == 'get_active_genres_v1'
          ? [_genreRows().first]
          : [_roleRows().first],
    );

    await _pumpScreenAndSettle(tester, service);

    expect(find.text('1件'), findsNWidgets(2));
    expect(find.text('想定件数（11件）と異なります。'), findsOneWidget);
    expect(find.text('想定件数（4件）と異なります。'), findsOneWidget);
    expect(find.text(_genreNames.first), findsOneWidget);
    expect(find.text(_roleNames.first), findsOneWidget);
  });

  testWidgets('contains no selection or profile mutation controls', (
    tester,
  ) async {
    final service = _service(
      fetcher: (functionName, _) async =>
          functionName == 'get_active_genres_v1' ? _genreRows() : _roleRows(),
    );

    await _pumpScreenAndSettle(tester, service);

    expect(find.byType(Checkbox), findsNothing);
    expect(
      find.byWidgetPredicate((widget) => widget is Radio<Object?>),
      findsNothing,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('保存'), findsNothing);
    expect(find.textContaining('メイン役割'), findsNothing);
  });
}

typedef _FakeRpcFetcher =
    Future<dynamic> Function(
      String functionName,
      Map<String, dynamic> parameters,
    );

StageMasterDataService _service({
  required _FakeRpcFetcher fetcher,
  bool authenticated = true,
}) {
  return StageMasterDataService(
    rpcFetcher: fetcher,
    authenticationChecker: () => authenticated,
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  StageMasterDataService service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: StageTaxonomyReadOnlyScreen(service: service),
    ),
  );
}

Future<void> _pumpScreenAndSettle(
  WidgetTester tester,
  StageMasterDataService service,
) async {
  await _pumpScreen(tester, service);
  await tester.pumpAndSettle();
}

void _expectVerticalOrder(WidgetTester tester, List<String> names) {
  final positions = [
    for (final name in names) tester.getTopLeft(find.text(name)).dy,
  ];
  for (var index = 1; index < positions.length; index++) {
    expect(positions[index], greaterThan(positions[index - 1]));
  }
}

const _genreNames = [
  'K-POP',
  'HIPHOP',
  'JAZZ',
  'JAZZ HIPHOP',
  'GIRLS HIPHOP',
  'WAACK',
  'LOCKING',
  'POPPING',
  'BREAKING',
  'HOUSE',
  'その他（ダンス）',
];

const _genreCodes = [
  'dance_kpop',
  'dance_hiphop',
  'dance_jazz',
  'dance_jazz_hiphop',
  'dance_girls_hiphop',
  'dance_waack',
  'dance_locking',
  'dance_popping',
  'dance_breaking',
  'dance_house',
  'dance_other',
];

const _roleNames = ['ダンサー', '振付師', 'インストラクター', 'その他'];

const _roleCodes = [
  'dance_dancer',
  'dance_choreographer',
  'dance_instructor',
  'dance_other',
];

List<Map<String, dynamic>> _genreRows() {
  return [
    for (var index = 0; index < _genreNames.length; index++)
      {
        'id': _uuid(index + 1),
        'code': _genreCodes[index],
        'name': _genreNames[index],
        'domain': 'dance',
        'category': index == 0 ? 'commercial' : 'street',
        'sort_order': 101 + index,
      },
  ];
}

List<Map<String, dynamic>> _roleRows() {
  return [
    for (var index = 0; index < _roleNames.length; index++)
      {
        'id': _uuid(index + 101),
        'code': _roleCodes[index],
        'name': _roleNames[index],
        'domain': 'dance',
        'sort_order': index == _roleNames.length - 1 ? 199 : 101 + index,
      },
  ];
}

String _uuid(int value) {
  return '00000000-0000-0000-0000-${value.toString().padLeft(12, '0')}';
}

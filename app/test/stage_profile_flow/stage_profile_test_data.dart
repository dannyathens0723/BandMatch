import 'package:app/services/stage_master_data_service.dart';

typedef FakeStageRpcFetcher =
    Future<dynamic> Function(
      String functionName,
      Map<String, dynamic> parameters,
    );

StageMasterDataService fakeStageService({
  required FakeStageRpcFetcher fetcher,
  bool authenticated = true,
}) {
  return StageMasterDataService(
    rpcFetcher: fetcher,
    authenticationChecker: () => authenticated,
  );
}

const genreNames = [
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

const roleNames = ['ダンサー', '振付師', 'インストラクター', 'その他'];

List<Map<String, dynamic>> genreRows() {
  return [
    for (var index = 0; index < genreNames.length; index++)
      {
        'id': testUuid(index + 1),
        'code': 'dance_genre_$index',
        'name': genreNames[index],
        'domain': 'dance',
        'category': index == 0 ? 'commercial' : 'street',
        'sort_order': 101 + index,
      },
  ];
}

List<Map<String, dynamic>> roleRows() {
  return [
    for (var index = 0; index < roleNames.length; index++)
      {
        'id': testUuid(index + 101),
        'code': 'dance_role_$index',
        'name': roleNames[index],
        'domain': 'dance',
        'sort_order': 101 + index,
      },
  ];
}

String testUuid(int value) {
  return '00000000-0000-0000-0000-${value.toString().padLeft(12, '0')}';
}

import 'package:app/services/stage_master_data_service.dart';
import 'package:app/services/stage_profile_taxonomy_persistence_service.dart';

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

StageProfileTaxonomyPersistenceService fakeStagePersistenceService({
  StageProfileTaxonomyRpcFetcher? fetcher,
  bool authenticated = true,
}) {
  return StageProfileTaxonomyPersistenceService(
    rpcFetcher:
        fetcher ??
        (_, _) async => [stageTaxonomyResultRow(saved: false)],
    authenticationChecker: () => authenticated,
  );
}

Map<String, dynamic> stageTaxonomyResultRow({
  bool saved = true,
  List<String>? genreIds,
  List<String>? roleIds,
  String? primaryRoleId,
}) {
  return {
    'domain': 'dance',
    'has_saved_taxonomy': saved,
    'genre_ids': genreIds ?? (saved ? [testUuid(1)] : <String>[]),
    'role_ids': roleIds ?? (saved ? [testUuid(101)] : <String>[]),
    'primary_role_id': primaryRoleId ?? (saved ? testUuid(101) : null),
  };
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

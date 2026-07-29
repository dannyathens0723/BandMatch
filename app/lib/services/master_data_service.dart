import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/master_data_item.dart';

typedef MasterDataRowsFetcher =
    Future<List<dynamic>> Function(MasterDataQuerySpec query);

class MasterDataQuerySpec {
  const MasterDataQuerySpec({
    required this.table,
    required this.columns,
    required this.filters,
    this.orderColumn = 'sort_order',
  });

  final String table;
  final String columns;
  final Map<String, Object> filters;
  final String orderColumn;
}

const activePartsMasterQuery = MasterDataQuerySpec(
  table: 'parts',
  columns: 'id, code, name, sort_order',
  filters: {'is_active': true},
);

const legacyBandGenresMasterQuery = MasterDataQuerySpec(
  table: 'genres',
  columns: 'id, code, name, sort_order',
  filters: {'is_active': true, 'domain': 'band'},
);

const activeAreasMasterQuery = MasterDataQuerySpec(
  table: 'areas',
  columns: 'id, code, name, level, sort_order',
  filters: {'is_active': true},
);

class MasterDataService {
  factory MasterDataService({
    SupabaseClient? client,
    MasterDataRowsFetcher? rowsFetcher,
  }) => MasterDataService._(client, rowsFetcher);

  MasterDataService._(this._client, this._rowsFetcher);

  final SupabaseClient? _client;
  final MasterDataRowsFetcher? _rowsFetcher;

  SupabaseClient get _supabaseClient => _client ?? Supabase.instance.client;

  Future<MasterData> fetchActiveMasterData() async {
    final responses = await Future.wait([
      _fetchRows(activePartsMasterQuery),
      _fetchRows(legacyBandGenresMasterQuery),
      _fetchRows(activeAreasMasterQuery),
    ]);

    return MasterData(
      parts: _toItems(responses[0]),
      genres: _toItems(responses[1]),
      areas: _toItems(responses[2]),
    );
  }

  Future<List<dynamic>> _fetchRows(MasterDataQuerySpec querySpec) async {
    final override = _rowsFetcher;
    if (override != null) {
      return override(querySpec);
    }

    var query = _supabaseClient.from(querySpec.table).select(querySpec.columns);
    for (final filter in querySpec.filters.entries) {
      query = query.eq(filter.key, filter.value);
    }
    final response = await query.order(querySpec.orderColumn);
    return response as List<dynamic>;
  }

  List<MasterDataItem> _toItems(dynamic response) {
    return (response as List<dynamic>)
        .map((row) => MasterDataItem.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}

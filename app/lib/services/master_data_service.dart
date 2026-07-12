import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/master_data_item.dart';

class MasterDataService {
  MasterDataService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<MasterData> fetchActiveMasterData() async {
    final responses = await Future.wait([
      _client
          .from('parts')
          .select('id, code, name, sort_order')
          .eq('is_active', true)
          .order('sort_order'),
      _client
          .from('genres')
          .select('id, code, name, sort_order')
          .eq('is_active', true)
          .order('sort_order'),
    ]);

    return MasterData(
      parts: _toItems(responses[0]),
      genres: _toItems(responses[1]),
    );
  }

  List<MasterDataItem> _toItems(dynamic response) {
    return (response as List<dynamic>)
        .map((row) => MasterDataItem.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}

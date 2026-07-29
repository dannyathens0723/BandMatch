import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/performance_domain.dart';
import '../models/stage_master_data.dart';

typedef StageMasterDataRpcFetcher =
    Future<dynamic> Function(
      String functionName,
      Map<String, dynamic> parameters,
    );
typedef StageAuthenticationChecker = bool Function();

final class StageMasterDataAuthenticationException implements Exception {
  const StageMasterDataAuthenticationException();

  @override
  String toString() =>
      'An authenticated session is required for performance roles.';
}

final class StageMasterDataRpcException implements Exception {
  const StageMasterDataRpcException({
    required this.functionName,
    required this.cause,
  });

  final String functionName;
  final Object cause;

  @override
  String toString() => 'STAGE master-data RPC failed: $functionName';
}

class StageMasterDataService {
  factory StageMasterDataService({
    SupabaseClient? client,
    StageMasterDataRpcFetcher? rpcFetcher,
    StageAuthenticationChecker? authenticationChecker,
  }) => StageMasterDataService._(client, rpcFetcher, authenticationChecker);

  StageMasterDataService._(
    this._client,
    this._rpcFetcher,
    this._authenticationChecker,
  );

  final SupabaseClient? _client;
  final StageMasterDataRpcFetcher? _rpcFetcher;
  final StageAuthenticationChecker? _authenticationChecker;

  SupabaseClient get _supabaseClient => _client ?? Supabase.instance.client;

  Future<List<StageGenre>> fetchActiveGenres(PerformanceDomain domain) async {
    final response = await _invokeRpc('get_active_genres_v1', {
      'p_domain': domain.rpcValue,
    });
    return _parseRows(
      response,
      functionName: 'get_active_genres_v1',
      parser: StageGenre.fromJson,
      comparator: _compareGenres,
    );
  }

  Future<List<StagePerformanceRole>> fetchActivePerformanceRoles(
    PerformanceDomain domain,
  ) async {
    if (!_hasAuthenticatedSession) {
      throw const StageMasterDataAuthenticationException();
    }

    final response = await _invokeRpc('get_active_performance_roles_v1', {
      'p_domain': domain.rpcValue,
    });
    return _parseRows(
      response,
      functionName: 'get_active_performance_roles_v1',
      parser: StagePerformanceRole.fromJson,
      comparator: _comparePerformanceRoles,
    );
  }

  bool get _hasAuthenticatedSession {
    final checker = _authenticationChecker;
    return checker?.call() ?? _supabaseClient.auth.currentSession != null;
  }

  Future<dynamic> _invokeRpc(
    String functionName,
    Map<String, dynamic> parameters,
  ) async {
    try {
      final fetcher = _rpcFetcher;
      if (fetcher != null) {
        return await fetcher(functionName, parameters);
      }
      return await _supabaseClient.rpc(functionName, params: parameters);
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'STAGE master-data RPC failed: function=$functionName, '
        'message=${error.message}, code=${error.code}, '
        'details=${error.details}, hint=${error.hint}\n$stackTrace',
      );
      throw StageMasterDataRpcException(
        functionName: functionName,
        cause: error,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'STAGE master-data RPC failed: function=$functionName, '
        'error=$error\n$stackTrace',
      );
      throw StageMasterDataRpcException(
        functionName: functionName,
        cause: error,
      );
    }
  }

  List<T> _parseRows<T>(
    dynamic response, {
    required String functionName,
    required T Function(Map<String, dynamic> row) parser,
    required int Function(T left, T right) comparator,
  }) {
    if (response is! List) {
      throw StageMasterDataParseException('$functionName must return a list');
    }

    final results = <T>[];
    for (var index = 0; index < response.length; index++) {
      final rawRow = response[index];
      if (rawRow is! Map) {
        throw StageMasterDataParseException(
          '$functionName row $index must be an object',
        );
      }

      try {
        results.add(parser(Map<String, dynamic>.from(rawRow)));
      } on UnsupportedPerformanceDomainException {
        rethrow;
      } on StageMasterDataParseException catch (error) {
        throw StageMasterDataParseException(
          '$functionName row $index is malformed: ${error.message}',
          cause: error,
        );
      } catch (error) {
        throw StageMasterDataParseException(
          '$functionName row $index is malformed',
          cause: error,
        );
      }
    }

    results.sort(comparator);
    return List<T>.unmodifiable(results);
  }
}

int _compareGenres(StageGenre left, StageGenre right) {
  final sortOrderComparison = left.sortOrder.compareTo(right.sortOrder);
  return sortOrderComparison != 0
      ? sortOrderComparison
      : left.code.compareTo(right.code);
}

int _comparePerformanceRoles(
  StagePerformanceRole left,
  StagePerformanceRole right,
) {
  final sortOrderComparison = left.sortOrder.compareTo(right.sortOrder);
  return sortOrderComparison != 0
      ? sortOrderComparison
      : left.code.compareTo(right.code);
}

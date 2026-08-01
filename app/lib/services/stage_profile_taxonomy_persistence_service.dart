import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/performance_domain.dart';
import '../models/stage_profile_taxonomy_draft.dart';
import '../models/stage_profile_taxonomy_persistence_result.dart';
import '../models/stage_uuid.dart';

typedef StageProfileTaxonomyRpcFetcher =
    Future<dynamic> Function(
      String functionName,
      Map<String, dynamic> parameters,
    );
typedef StageProfileTaxonomyAuthenticationChecker = bool Function();

enum StageProfileTaxonomyPersistenceFailureKind {
  authenticationRequired,
  invalidLocalRequest,
  serverInputContract,
  rejectedTaxonomyInput,
  invalidTaxonomyIdentifier,
  profileState,
  storedTaxonomyInconsistency,
  primaryRoleConflict,
  postWriteStateConflict,
  rpc,
}

final class StageProfileTaxonomyPersistenceException implements Exception {
  const StageProfileTaxonomyPersistenceException({
    required this.kind,
    this.functionName,
    this.cause,
  });

  final StageProfileTaxonomyPersistenceFailureKind kind;
  final String? functionName;
  final Object? cause;

  String get userMessage => switch (kind) {
    StageProfileTaxonomyPersistenceFailureKind.authenticationRequired =>
      'ログインが必要です。もう一度ログインしてください。',
    StageProfileTaxonomyPersistenceFailureKind.invalidLocalRequest =>
      '選択内容を確認してください。',
    StageProfileTaxonomyPersistenceFailureKind.serverInputContract ||
    StageProfileTaxonomyPersistenceFailureKind.rejectedTaxonomyInput ||
    StageProfileTaxonomyPersistenceFailureKind.invalidTaxonomyIdentifier =>
      '選択内容を保存できませんでした。最新の選択肢を確認してください。',
    StageProfileTaxonomyPersistenceFailureKind.profileState ||
    StageProfileTaxonomyPersistenceFailureKind.storedTaxonomyInconsistency ||
    StageProfileTaxonomyPersistenceFailureKind.primaryRoleConflict ||
    StageProfileTaxonomyPersistenceFailureKind.postWriteStateConflict =>
      'プロフィールの状態を確認できませんでした。',
    StageProfileTaxonomyPersistenceFailureKind.rpc =>
      '通信に失敗しました。時間をおいて再度お試しください。',
  };

  @override
  String toString() => 'StageProfileTaxonomyPersistenceException(${kind.name})';
}

class StageProfileTaxonomyPersistenceService {
  factory StageProfileTaxonomyPersistenceService({
    SupabaseClient? client,
    StageProfileTaxonomyRpcFetcher? rpcFetcher,
    StageProfileTaxonomyAuthenticationChecker? authenticationChecker,
  }) => StageProfileTaxonomyPersistenceService._(
    client,
    rpcFetcher,
    authenticationChecker,
  );

  StageProfileTaxonomyPersistenceService._(
    this._client,
    this._rpcFetcher,
    this._authenticationChecker,
  );

  final SupabaseClient? _client;
  final StageProfileTaxonomyRpcFetcher? _rpcFetcher;
  final StageProfileTaxonomyAuthenticationChecker? _authenticationChecker;

  SupabaseClient get _supabaseClient => _client ?? Supabase.instance.client;

  Future<StageProfileTaxonomyPersistenceResult> fetchMyStageTaxonomy(
    PerformanceDomain domain,
  ) async {
    _requireAuthentication();
    _validateDomain(domain);

    final response = await _invokeRpc('get_my_stage_taxonomy_v1', {
      'p_performance_domain': domain.rpcValue,
    });
    return _parseSingleResult(response, 'get_my_stage_taxonomy_v1');
  }

  Future<StageProfileTaxonomyPersistenceResult> replaceMyStageTaxonomy({
    required PerformanceDomain domain,
    required StageProfileTaxonomyDraft draft,
  }) async {
    _requireAuthentication();
    _validateDomain(domain);
    _validateDraft(draft);

    final response = await _invokeRpc('replace_my_stage_taxonomy_v1', {
      'p_performance_domain': domain.rpcValue,
      'p_genre_ids': List<String>.of(draft.selectedGenreIds),
      'p_role_ids': List<String>.of(draft.selectedRoleIds),
      'p_primary_role_id': draft.primaryRoleId,
    });
    return _parseSingleResult(response, 'replace_my_stage_taxonomy_v1');
  }

  void _requireAuthentication() {
    final checker = _authenticationChecker;
    final hasSession =
        checker?.call() ?? _supabaseClient.auth.currentSession != null;
    if (!hasSession) {
      throw const StageProfileTaxonomyPersistenceException(
        kind: StageProfileTaxonomyPersistenceFailureKind.authenticationRequired,
      );
    }
  }

  void _validateDomain(PerformanceDomain domain) {
    if (domain != PerformanceDomain.dance) {
      throw const StageProfileTaxonomyPersistenceException(
        kind: StageProfileTaxonomyPersistenceFailureKind.invalidLocalRequest,
      );
    }
  }

  void _validateDraft(StageProfileTaxonomyDraft draft) {
    final genreIds = draft.selectedGenreIds;
    final roleIds = draft.selectedRoleIds;
    final primaryRoleId = draft.primaryRoleId;

    if (genreIds.isEmpty ||
        roleIds.isEmpty ||
        !isValidStageUuid(primaryRoleId) ||
        genreIds.any((id) => !isValidStageUuid(id)) ||
        roleIds.any((id) => !isValidStageUuid(id)) ||
        genreIds.toSet().length != genreIds.length ||
        roleIds.toSet().length != roleIds.length ||
        !roleIds.contains(primaryRoleId)) {
      throw const StageProfileTaxonomyPersistenceException(
        kind: StageProfileTaxonomyPersistenceFailureKind.invalidLocalRequest,
      );
    }
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
      _logPostgrestFailure(functionName, error, stackTrace);
      throw _mapPostgrestException(functionName, error);
    } on StageProfileTaxonomyPersistenceException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint(
        'STAGE taxonomy persistence RPC failed: function=$functionName, '
        'error=$error\n$stackTrace',
      );
      throw StageProfileTaxonomyPersistenceException(
        kind: StageProfileTaxonomyPersistenceFailureKind.rpc,
        functionName: functionName,
        cause: error,
      );
    }
  }

  StageProfileTaxonomyPersistenceResult _parseSingleResult(
    dynamic response,
    String functionName,
  ) {
    if (response is! List) {
      throw StageProfileTaxonomyPersistenceParseException(
        '$functionName must return a list',
      );
    }
    if (response.length != 1) {
      throw StageProfileTaxonomyPersistenceParseException(
        '$functionName must return exactly one row',
      );
    }

    final rawRow = response.single;
    if (rawRow is! Map) {
      throw StageProfileTaxonomyPersistenceParseException(
        '$functionName row must be an object',
      );
    }

    try {
      return StageProfileTaxonomyPersistenceResult.fromRpcRow(
        Map<String, dynamic>.from(rawRow),
      );
    } on StageProfileTaxonomyPersistenceParseException {
      rethrow;
    } catch (error) {
      throw StageProfileTaxonomyPersistenceParseException(
        '$functionName row is malformed',
        cause: error,
      );
    }
  }

  StageProfileTaxonomyPersistenceException _mapPostgrestException(
    String functionName,
    PostgrestException error,
  ) {
    final message = error.message.toLowerCase();
    final kind = switch (error.code) {
      '28000' =>
        StageProfileTaxonomyPersistenceFailureKind.authenticationRequired,
      '22004' => StageProfileTaxonomyPersistenceFailureKind.serverInputContract,
      '22023' when message.contains('missing, inactive, or not dance') =>
        StageProfileTaxonomyPersistenceFailureKind.invalidTaxonomyIdentifier,
      '22023' =>
        StageProfileTaxonomyPersistenceFailureKind.rejectedTaxonomyInput,
      '55000'
          when message.contains('profile mapping') ||
              message.contains('active profile') =>
        StageProfileTaxonomyPersistenceFailureKind.profileState,
      '55000' when message.contains('stored stage taxonomy state') =>
        StageProfileTaxonomyPersistenceFailureKind.storedTaxonomyInconsistency,
      '55000' when message.contains('non-dance primary role') =>
        StageProfileTaxonomyPersistenceFailureKind.primaryRoleConflict,
      '55000'
          when message.contains('does not match the request') ||
              message.contains('stored performance domain') =>
        StageProfileTaxonomyPersistenceFailureKind.postWriteStateConflict,
      '55000' => StageProfileTaxonomyPersistenceFailureKind.profileState,
      _ => StageProfileTaxonomyPersistenceFailureKind.rpc,
    };

    return StageProfileTaxonomyPersistenceException(
      kind: kind,
      functionName: functionName,
      cause: error,
    );
  }

  void _logPostgrestFailure(
    String functionName,
    PostgrestException error,
    StackTrace stackTrace,
  ) {
    debugPrint(
      'STAGE taxonomy persistence RPC failed: function=$functionName, '
      'message=${error.message}, code=${error.code}, '
      'details=${error.details}, hint=${error.hint}\n$stackTrace',
    );
  }
}

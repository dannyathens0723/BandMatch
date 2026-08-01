import 'package:flutter/material.dart';

import '../models/performance_domain.dart';
import '../models/stage_master_data.dart';
import '../services/stage_master_data_service.dart';

class StageTaxonomyReadOnlyScreen extends StatefulWidget {
  const StageTaxonomyReadOnlyScreen({super.key, this.service});

  final StageMasterDataService? service;

  @override
  State<StageTaxonomyReadOnlyScreen> createState() =>
      _StageTaxonomyReadOnlyScreenState();
}

class _StageTaxonomyReadOnlyScreenState
    extends State<StageTaxonomyReadOnlyScreen> {
  static const _expectedGenreCount = 11;
  static const _expectedRoleCount = 4;

  late final StageMasterDataService _service;

  _SectionStatus _genreStatus = _SectionStatus.loading;
  _SectionStatus _roleStatus = _SectionStatus.loading;
  List<StageGenre> _genres = const [];
  List<StagePerformanceRole> _roles = const [];
  int _genreRequestId = 0;
  int _roleRequestId = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? StageMasterDataService();
    _loadGenres(showLoading: false);
    _loadRoles(showLoading: false);
  }

  Future<void> _loadGenres({bool showLoading = true}) async {
    final requestId = ++_genreRequestId;
    if (showLoading && mounted) {
      setState(() {
        _genreStatus = _SectionStatus.loading;
      });
    }

    try {
      final genres = await _service.fetchActiveGenres(PerformanceDomain.dance);
      if (!mounted || requestId != _genreRequestId) return;
      setState(() {
        _genres = genres;
        _genreStatus = genres.isEmpty
            ? _SectionStatus.empty
            : _SectionStatus.loaded;
      });
    } on StageMasterDataParseException catch (error, stackTrace) {
      _logLoadFailure('genres', error, stackTrace);
      _setGenreFailure(requestId, _SectionStatus.parsingFailure);
    } on UnsupportedPerformanceDomainException catch (error, stackTrace) {
      _logLoadFailure('genres', error, stackTrace);
      _setGenreFailure(requestId, _SectionStatus.parsingFailure);
    } on StageMasterDataRpcException catch (error, stackTrace) {
      _logLoadFailure('genres', error, stackTrace);
      _setGenreFailure(requestId, _SectionStatus.rpcFailure);
    } catch (error, stackTrace) {
      _logLoadFailure('genres', error, stackTrace);
      _setGenreFailure(requestId, _SectionStatus.rpcFailure);
    }
  }

  Future<void> _loadRoles({bool showLoading = true}) async {
    final requestId = ++_roleRequestId;
    if (showLoading && mounted) {
      setState(() {
        _roleStatus = _SectionStatus.loading;
      });
    }

    try {
      final roles = await _service.fetchActivePerformanceRoles(
        PerformanceDomain.dance,
      );
      if (!mounted || requestId != _roleRequestId) return;
      setState(() {
        _roles = roles;
        _roleStatus = roles.isEmpty
            ? _SectionStatus.empty
            : _SectionStatus.loaded;
      });
    } on StageMasterDataAuthenticationException {
      _setRoleFailure(requestId, _SectionStatus.authenticationRequired);
    } on StageMasterDataParseException catch (error, stackTrace) {
      _logLoadFailure('performance roles', error, stackTrace);
      _setRoleFailure(requestId, _SectionStatus.parsingFailure);
    } on UnsupportedPerformanceDomainException catch (error, stackTrace) {
      _logLoadFailure('performance roles', error, stackTrace);
      _setRoleFailure(requestId, _SectionStatus.parsingFailure);
    } on StageMasterDataRpcException catch (error, stackTrace) {
      _logLoadFailure('performance roles', error, stackTrace);
      _setRoleFailure(requestId, _SectionStatus.rpcFailure);
    } catch (error, stackTrace) {
      _logLoadFailure('performance roles', error, stackTrace);
      _setRoleFailure(requestId, _SectionStatus.rpcFailure);
    }
  }

  void _setGenreFailure(int requestId, _SectionStatus status) {
    if (!mounted || requestId != _genreRequestId) return;
    setState(() {
      _genres = const [];
      _genreStatus = status;
    });
  }

  void _setRoleFailure(int requestId, _SectionStatus status) {
    if (!mounted || requestId != _roleRequestId) return;
    setState(() {
      _roles = const [];
      _roleStatus = status;
    });
  }

  void _logLoadFailure(String section, Object error, StackTrace stackTrace) {
    debugPrint(
      'STAGE taxonomy screen failed to load $section: '
      '$error\n$stackTrace',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('STAGE データ接続確認')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _IntroductionCard(),
                    const SizedBox(height: 16),
                    _TaxonomySectionCard(
                      title: 'ダンスジャンル',
                      status: _genreStatus,
                      count: _genres.length,
                      expectedCount: _expectedGenreCount,
                      emptyMessage: 'ダンスジャンルはありません',
                      authenticationMessage: null,
                      retryKey: const ValueKey('genre-retry'),
                      onRetry: _loadGenres,
                      children: [
                        for (final genre in _genres)
                          _TaxonomyRow(
                            name: genre.name,
                            supportingText: 'カテゴリ: ${genre.category}',
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _TaxonomySectionCard(
                      title: 'パフォーマンス役割',
                      status: _roleStatus,
                      count: _roles.length,
                      expectedCount: _expectedRoleCount,
                      emptyMessage: 'パフォーマンス役割はありません',
                      authenticationMessage: '役割を確認するにはログインが必要です',
                      retryKey: const ValueKey('role-retry'),
                      onRetry: _loadRoles,
                      children: [
                        for (final role in _roles)
                          _TaxonomyRow(name: role.name),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SectionStatus {
  loading,
  loaded,
  empty,
  authenticationRequired,
  rpcFailure,
  parsingFailure,
}

class _IntroductionCard extends StatelessWidget {
  const _IntroductionCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_done_outlined, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Supabase の読み取り専用 RPC から、'
                '承認済みのダンス分類を確認します。',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaxonomySectionCard extends StatelessWidget {
  const _TaxonomySectionCard({
    required this.title,
    required this.status,
    required this.count,
    required this.expectedCount,
    required this.emptyMessage,
    required this.authenticationMessage,
    required this.retryKey,
    required this.onRetry,
    required this.children,
  });

  final String title;
  final _SectionStatus status;
  final int count;
  final int expectedCount;
  final String emptyMessage;
  final String? authenticationMessage;
  final Key retryKey;
  final Future<void> Function({bool showLoading}) onRetry;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (status == _SectionStatus.loaded ||
                    status == _SectionStatus.empty)
                  Text(
                    '$count件',
                    key: ValueKey('$title-count'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ..._buildContent(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context) {
    return switch (status) {
      _SectionStatus.loading => [
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('読み込み中…'),
              ],
            ),
          ),
        ),
      ],
      _SectionStatus.loaded => [
        if (count != expectedCount) _CountWarning(expectedCount: expectedCount),
        ...children,
      ],
      _SectionStatus.empty => [
        Text(emptyMessage),
        const SizedBox(height: 8),
        _CountWarning(expectedCount: expectedCount),
      ],
      _SectionStatus.authenticationRequired => [
        Text(authenticationMessage ?? 'ログインが必要です'),
        const SizedBox(height: 12),
        _RetryButton(buttonKey: retryKey, onRetry: onRetry),
      ],
      _SectionStatus.rpcFailure => [
        const Text('データを読み込めませんでした。通信状況を確認して再試行してください。'),
        const SizedBox(height: 12),
        _RetryButton(buttonKey: retryKey, onRetry: onRetry),
      ],
      _SectionStatus.parsingFailure => [
        const Text('データ形式を確認できませんでした。'),
        const SizedBox(height: 12),
        _RetryButton(buttonKey: retryKey, onRetry: onRetry),
      ],
    };
  }
}

class _TaxonomyRow extends StatelessWidget {
  const _TaxonomyRow({required this.name, this.supportingText});

  final String name;
  final String? supportingText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name),
                if (supportingText != null)
                  Text(
                    supportingText!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountWarning extends StatelessWidget {
  const _CountWarning({required this.expectedCount});

  final int expectedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('想定件数（$expectedCount件）と異なります。'),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.buttonKey, required this.onRetry});

  final Key buttonKey;
  final Future<void> Function({bool showLoading}) onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        key: buttonKey,
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('再試行'),
      ),
    );
  }
}

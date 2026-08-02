import 'package:flutter/material.dart';

import '../models/performance_domain.dart';
import '../models/stage_master_data.dart';
import '../models/stage_profile_taxonomy_draft.dart';
import '../models/stage_profile_taxonomy_persistence_result.dart';
import '../services/stage_master_data_service.dart';
import '../services/stage_profile_taxonomy_persistence_service.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';
import 'stage_profile_taxonomy_summary_screen.dart';

class StageProfileTaxonomySelectionScreen extends StatefulWidget {
  StageProfileTaxonomySelectionScreen({
    super.key,
    this.service,
    this.persistenceService,
    StageProfileTaxonomySelection? initialSelection,
  }) : initialSelection = initialSelection ?? StageProfileTaxonomySelection();

  final StageMasterDataService? service;
  final StageProfileTaxonomyPersistenceService? persistenceService;
  final StageProfileTaxonomySelection initialSelection;

  @override
  State<StageProfileTaxonomySelectionScreen> createState() =>
      _StageProfileTaxonomySelectionScreenState();
}

class _StageProfileTaxonomySelectionScreenState
    extends State<StageProfileTaxonomySelectionScreen> {
  late final StageMasterDataService _service;
  late final StageProfileTaxonomyPersistenceService _persistenceService;
  late StageProfileTaxonomySelection _selection;

  _TaxonomyLoadStatus _genreStatus = _TaxonomyLoadStatus.loading;
  _TaxonomyLoadStatus _roleStatus = _TaxonomyLoadStatus.loading;
  StageProfileTaxonomyValidation _validation =
      const StageProfileTaxonomyValidation();
  List<StageGenre> _genres = const [];
  List<StagePerformanceRole> _roles = const [];
  List<String> _preferredGenreOrder = const [];
  List<String> _preferredRoleOrder = const [];
  StageProfileTaxonomyPersistenceResult? _persistedTaxonomy;
  _PersistenceLoadStatus _persistenceStatus = _PersistenceLoadStatus.loading;
  int _genreRequestId = 0;
  int _roleRequestId = 0;
  int _persistenceRequestId = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? StageMasterDataService();
    _persistenceService =
        widget.persistenceService ?? StageProfileTaxonomyPersistenceService();
    _selection = widget.initialSelection;
    _loadGenres(showLoading: false);
    _loadRoles(showLoading: false);
    _loadPersistedTaxonomy(showLoading: false);
  }

  Future<void> _loadGenres({bool showLoading = true}) async {
    final requestId = ++_genreRequestId;
    if (showLoading && mounted) {
      setState(() => _genreStatus = _TaxonomyLoadStatus.loading);
    }

    try {
      final genres = await _service.fetchActiveGenres(PerformanceDomain.dance);
      if (!mounted || requestId != _genreRequestId) return;
      setState(() {
        _genres = genres;
        _genreStatus = genres.isEmpty
            ? _TaxonomyLoadStatus.empty
            : _TaxonomyLoadStatus.loaded;
        _synchronizePersistedSelectionIfReady();
      });
    } on StageMasterDataParseException catch (error, stackTrace) {
      _logLoadFailure('genres', error, stackTrace);
      _setGenreFailure(requestId, _TaxonomyLoadStatus.parsingFailure);
    } on UnsupportedPerformanceDomainException catch (error, stackTrace) {
      _logLoadFailure('genres', error, stackTrace);
      _setGenreFailure(requestId, _TaxonomyLoadStatus.parsingFailure);
    } on StageMasterDataRpcException catch (error, stackTrace) {
      _logLoadFailure('genres', error, stackTrace);
      _setGenreFailure(requestId, _TaxonomyLoadStatus.rpcFailure);
    } catch (error, stackTrace) {
      _logLoadFailure('genres', error, stackTrace);
      _setGenreFailure(requestId, _TaxonomyLoadStatus.rpcFailure);
    }
  }

  Future<void> _loadRoles({bool showLoading = true}) async {
    final requestId = ++_roleRequestId;
    if (showLoading && mounted) {
      setState(() => _roleStatus = _TaxonomyLoadStatus.loading);
    }

    try {
      final roles = await _service.fetchActivePerformanceRoles(
        PerformanceDomain.dance,
      );
      if (!mounted || requestId != _roleRequestId) return;
      setState(() {
        _roles = roles;
        _roleStatus = roles.isEmpty
            ? _TaxonomyLoadStatus.empty
            : _TaxonomyLoadStatus.loaded;
        _synchronizePersistedSelectionIfReady();
      });
    } on StageMasterDataAuthenticationException {
      _setRoleFailure(requestId, _TaxonomyLoadStatus.authenticationRequired);
    } on StageMasterDataParseException catch (error, stackTrace) {
      _logLoadFailure('performance roles', error, stackTrace);
      _setRoleFailure(requestId, _TaxonomyLoadStatus.parsingFailure);
    } on UnsupportedPerformanceDomainException catch (error, stackTrace) {
      _logLoadFailure('performance roles', error, stackTrace);
      _setRoleFailure(requestId, _TaxonomyLoadStatus.parsingFailure);
    } on StageMasterDataRpcException catch (error, stackTrace) {
      _logLoadFailure('performance roles', error, stackTrace);
      _setRoleFailure(requestId, _TaxonomyLoadStatus.rpcFailure);
    } catch (error, stackTrace) {
      _logLoadFailure('performance roles', error, stackTrace);
      _setRoleFailure(requestId, _TaxonomyLoadStatus.rpcFailure);
    }
  }

  void _setGenreFailure(int requestId, _TaxonomyLoadStatus status) {
    if (!mounted || requestId != _genreRequestId) return;
    setState(() {
      _genres = const [];
      _genreStatus = status;
    });
  }

  void _setRoleFailure(int requestId, _TaxonomyLoadStatus status) {
    if (!mounted || requestId != _roleRequestId) return;
    setState(() {
      _roles = const [];
      _roleStatus = status;
    });
  }

  void _logLoadFailure(String section, Object error, StackTrace stackTrace) {
    debugPrint(
      'STAGE profile taxonomy failed to load $section: $error\n$stackTrace',
    );
  }

  Future<void> _loadPersistedTaxonomy({bool showLoading = true}) async {
    final requestId = ++_persistenceRequestId;
    if (showLoading && mounted) {
      setState(() => _persistenceStatus = _PersistenceLoadStatus.loading);
    }

    try {
      final result = await _persistenceService.fetchMyStageTaxonomy(
        PerformanceDomain.dance,
      );
      if (!mounted || requestId != _persistenceRequestId) return;
      setState(() {
        _persistedTaxonomy = result;
        _persistenceStatus = _PersistenceLoadStatus.loaded;
        _synchronizePersistedSelectionIfReady();
      });
    } on StageProfileTaxonomyPersistenceException catch (error, stackTrace) {
      _logLoadFailure('saved taxonomy', error, stackTrace);
      _setPersistenceFailure(
        requestId,
        error.kind ==
                StageProfileTaxonomyPersistenceFailureKind
                    .authenticationRequired
            ? _PersistenceLoadStatus.authenticationRequired
            : _PersistenceLoadStatus.rpcFailure,
      );
    } on StageProfileTaxonomyPersistenceParseException catch (
      error,
      stackTrace
    ) {
      _logLoadFailure('saved taxonomy', error, stackTrace);
      _setPersistenceFailure(requestId, _PersistenceLoadStatus.parsingFailure);
    } catch (error, stackTrace) {
      _logLoadFailure('saved taxonomy', error, stackTrace);
      _setPersistenceFailure(requestId, _PersistenceLoadStatus.rpcFailure);
    }
  }

  void _setPersistenceFailure(int requestId, _PersistenceLoadStatus status) {
    if (!mounted || requestId != _persistenceRequestId) return;
    setState(() {
      _persistedTaxonomy = null;
      _persistenceStatus = status;
    });
  }

  void _synchronizePersistedSelectionIfReady() {
    final persisted = _persistedTaxonomy;
    if (_persistenceStatus != _PersistenceLoadStatus.loaded ||
        _genreStatus != _TaxonomyLoadStatus.loaded ||
        _roleStatus != _TaxonomyLoadStatus.loaded ||
        persisted == null) {
      return;
    }

    if (!_containsAllPersistedIds(persisted)) {
      _persistenceStatus = _PersistenceLoadStatus.incompatibleMasterData;
      return;
    }

    _applyAuthoritativeResult(persisted);
    _persistenceStatus = _PersistenceLoadStatus.ready;
  }

  bool _containsAllPersistedIds(StageProfileTaxonomyPersistenceResult result) {
    final activeGenreIds = _genres.map((genre) => genre.id).toSet();
    final activeRoleIds = _roles.map((role) => role.id).toSet();
    return result.genreIds.every(activeGenreIds.contains) &&
        result.roleIds.every(activeRoleIds.contains) &&
        (result.primaryRoleId == null ||
            activeRoleIds.contains(result.primaryRoleId));
  }

  void _applyAuthoritativeResult(StageProfileTaxonomyPersistenceResult result) {
    _preferredGenreOrder = List.unmodifiable(result.genreIds);
    _preferredRoleOrder = List.unmodifiable(result.roleIds);
    _selection = result.hasSavedTaxonomy
        ? StageProfileTaxonomySelection(
            selectedGenreIds: result.genreIds.toSet(),
            selectedRoleIds: result.roleIds.toSet(),
            primaryRoleId: result.primaryRoleId,
          )
        : StageProfileTaxonomySelection();
    _validation = const StageProfileTaxonomyValidation();
  }

  void _toggleGenre(String genreId) {
    setState(() {
      _selection = _selection.toggleGenre(genreId);
      _validation = const StageProfileTaxonomyValidation();
    });
  }

  void _toggleRole(String roleId) {
    final orderedIds = _roles.map((role) => role.id).toList(growable: false);
    setState(() {
      _selection = _selection.toggleRole(roleId, orderedIds);
      _validation = const StageProfileTaxonomyValidation();
    });
  }

  void _choosePrimaryRole(String roleId) {
    setState(() {
      _selection = _selection.choosePrimaryRole(roleId);
      _validation = const StageProfileTaxonomyValidation();
    });
  }

  Future<void> _continue() async {
    final validation = _selection.validate();
    setState(() => _validation = validation);
    if (!validation.isValid) return;

    final draft = _selection.toDraft(
      orderedGenreIds: _orderedSelectedGenreIds,
      orderedRoleIds: _orderedSelectedRoleIds,
    );
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StageProfileTaxonomySummaryScreen(
          draft: draft,
          genres: _genres,
          roles: _roles,
          onSave: _saveTaxonomy,
        ),
      ),
    );
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  Future<StageProfileTaxonomyDraft> _saveTaxonomy(
    StageProfileTaxonomyDraft draft,
  ) async {
    final persisted = await _persistenceService.replaceMyStageTaxonomy(
      domain: PerformanceDomain.dance,
      draft: draft,
    );
    if (!_containsAllPersistedIds(persisted)) {
      if (mounted) {
        setState(
          () => _persistenceStatus =
              _PersistenceLoadStatus.incompatibleMasterData,
        );
      }
      throw const StageProfileTaxonomyPersistenceParseException(
        'Persisted taxonomy contains unavailable master IDs',
      );
    }
    if (!persisted.hasSavedTaxonomy || persisted.primaryRoleId == null) {
      throw const StageProfileTaxonomyPersistenceParseException(
        'A successful save must return saved taxonomy',
      );
    }

    if (mounted) {
      setState(() {
        _persistedTaxonomy = persisted;
        _applyAuthoritativeResult(persisted);
        _persistenceStatus = _PersistenceLoadStatus.ready;
      });
    }

    return StageProfileTaxonomyDraft(
      selectedGenreIds: persisted.genreIds,
      selectedRoleIds: persisted.roleIds,
      primaryRoleId: persisted.primaryRoleId!,
    );
  }

  List<String> get _orderedSelectedGenreIds => _orderedSelection(
    preferred: _preferredGenreOrder,
    available: _genres.map((genre) => genre.id),
    selected: _selection.selectedGenreIds,
  );

  List<String> get _orderedSelectedRoleIds => _orderedSelection(
    preferred: _preferredRoleOrder,
    available: _roles.map((role) => role.id),
    selected: _selection.selectedRoleIds,
  );

  List<String> _orderedSelection({
    required List<String> preferred,
    required Iterable<String> available,
    required Set<String> selected,
  }) {
    final ordered = <String>[];
    final included = <String>{};
    for (final id in [...preferred, ...available]) {
      if (selected.contains(id) && included.add(id)) ordered.add(id);
    }
    return List.unmodifiable(ordered);
  }

  bool get _requiredDataAvailable =>
      _genreStatus == _TaxonomyLoadStatus.loaded &&
      _roleStatus == _TaxonomyLoadStatus.loaded &&
      _persistenceStatus == _PersistenceLoadStatus.ready;

  @override
  Widget build(BuildContext context) {
    return StageMobilePageFrame(
      child: Scaffold(
        appBar: AppBar(title: const Text('プロフィール設定')),
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = StageDesignTokens.horizontalPadding(
                constraints.maxWidth,
              );
              return SingleChildScrollView(
                key: const ValueKey('profile-taxonomy-scroll'),
                padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: StageDesignTokens.maxContentWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_persistenceNotice != null) ...[
                          _persistenceNotice!,
                          const SizedBox(height: StageDesignTokens.space16),
                        ],
                        Text(
                          '活動したいジャンルと役割を選んでください',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: StageDesignTokens.space8),
                        Text(
                          '複数選択できます。内容はまだ保存されません。',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: StageDesignTokens.textSecondary,
                              ),
                        ),
                        const SizedBox(height: StageDesignTokens.space24),
                        _SelectionSection(
                          title: 'ダンスジャンル',
                          description: '活動したいジャンルを1つ以上選択してください',
                          status: _genreStatus,
                          emptyMessage: '選択できるダンスジャンルがありません',
                          authenticationMessage: null,
                          retryKey: const ValueKey('profile-genre-retry'),
                          onRetry: _loadGenres,
                          validationMessage: _validation.genreMessage,
                          content: Wrap(
                            spacing: StageDesignTokens.space8,
                            runSpacing: StageDesignTokens.space8,
                            children: [
                              for (final genre in _genres)
                                FilterChip(
                                  key: ValueKey('genre-${genre.id}'),
                                  label: Text(genre.name),
                                  selected: _selection.selectedGenreIds
                                      .contains(genre.id),
                                  onSelected: _requiredDataAvailable
                                      ? (_) => _toggleGenre(genre.id)
                                      : null,
                                  showCheckmark: true,
                                  selectedColor: StageDesignTokens.surfaceMuted,
                                  checkmarkColor: StageDesignTokens.purple,
                                  side: BorderSide(
                                    color:
                                        _selection.selectedGenreIds.contains(
                                          genre.id,
                                        )
                                        ? StageDesignTokens.purple
                                        : StageDesignTokens.border,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: StageDesignTokens.space16),
                        _SelectionSection(
                          title: '役割',
                          description: '担当したい役割を1つ以上選択してください',
                          status: _roleStatus,
                          emptyMessage: '選択できる役割がありません',
                          authenticationMessage: '役割を選択するにはログインが必要です',
                          retryKey: const ValueKey('profile-role-retry'),
                          onRetry: _loadRoles,
                          validationMessage: _validation.roleMessage,
                          content: Wrap(
                            spacing: StageDesignTokens.space8,
                            runSpacing: StageDesignTokens.space8,
                            children: [
                              for (final role in _roles)
                                FilterChip(
                                  key: ValueKey('role-${role.id}'),
                                  label: Text(role.name),
                                  selected: _selection.selectedRoleIds.contains(
                                    role.id,
                                  ),
                                  onSelected: _requiredDataAvailable
                                      ? (_) => _toggleRole(role.id)
                                      : null,
                                  showCheckmark: true,
                                  selectedColor: StageDesignTokens.surfaceMuted,
                                  checkmarkColor: StageDesignTokens.purple,
                                  side: BorderSide(
                                    color:
                                        _selection.selectedRoleIds.contains(
                                          role.id,
                                        )
                                        ? StageDesignTokens.purple
                                        : StageDesignTokens.border,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_selection.selectedRoleIds.isNotEmpty) ...[
                          const SizedBox(height: StageDesignTokens.space16),
                          _PrimaryRoleSection(
                            roles: _roles
                                .where(
                                  (role) => _selection.selectedRoleIds.contains(
                                    role.id,
                                  ),
                                )
                                .toList(growable: false),
                            primaryRoleId: _selection.primaryRoleId,
                            validationMessage: _validation.primaryRoleMessage,
                            onSelected: _requiredDataAvailable
                                ? _choosePrimaryRole
                                : (_) {},
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        bottomNavigationBar: SafeArea(
          key: const ValueKey('profile-taxonomy-action-bar'),
          top: false,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: StageDesignTokens.surface,
              border: Border(top: BorderSide(color: StageDesignTokens.border)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: StageDesignTokens.maxContentWidth,
                  ),
                  child: StagePrimaryButton(
                    key: const ValueKey('profile-taxonomy-continue'),
                    label: '次へ',
                    icon: Icons.arrow_forward,
                    onPressed: _requiredDataAvailable ? _continue : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? get _persistenceNotice {
    return switch (_persistenceStatus) {
      _PersistenceLoadStatus.loading => const StageCard(
        key: ValueKey('profile-taxonomy-persistence-loading'),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: StageDesignTokens.space12),
            Expanded(child: Text('保存済みの選択内容を読み込んでいます…')),
          ],
        ),
      ),
      _PersistenceLoadStatus.loaded || _PersistenceLoadStatus.ready => null,
      _PersistenceLoadStatus.authenticationRequired => _PersistenceErrorCard(
        message: 'プロフィールを読み込むにはログインが必要です。',
        onRetry: _loadPersistedTaxonomy,
      ),
      _PersistenceLoadStatus.rpcFailure => _PersistenceErrorCard(
        message: '保存済みのプロフィールを読み込めませんでした。時間をおいて再度お試しください。',
        onRetry: _loadPersistedTaxonomy,
      ),
      _PersistenceLoadStatus.parsingFailure => _PersistenceErrorCard(
        message: '保存済みのプロフィール情報を確認できませんでした。',
        onRetry: _loadPersistedTaxonomy,
      ),
      _PersistenceLoadStatus.incompatibleMasterData => const StageCard(
        key: ValueKey('profile-taxonomy-persistence-error'),
        child: _SectionNotice(
          icon: Icons.warning_amber_rounded,
          message: '保存済みの選択肢に現在利用できない項目があります。内容を上書きせず、サポートへお問い合わせください。',
        ),
      ),
    };
  }
}

enum _TaxonomyLoadStatus {
  loading,
  loaded,
  empty,
  authenticationRequired,
  rpcFailure,
  parsingFailure,
}

enum _PersistenceLoadStatus {
  loading,
  loaded,
  ready,
  authenticationRequired,
  rpcFailure,
  parsingFailure,
  incompatibleMasterData,
}

class _PersistenceErrorCard extends StatelessWidget {
  const _PersistenceErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function({bool showLoading}) onRetry;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      key: const ValueKey('profile-taxonomy-persistence-error'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionNotice(icon: Icons.error_outline, message: message),
          const SizedBox(height: StageDesignTokens.space12),
          OutlinedButton.icon(
            key: const ValueKey('profile-taxonomy-persistence-retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('再試行'),
          ),
        ],
      ),
    );
  }
}

class _SelectionSection extends StatelessWidget {
  const _SelectionSection({
    required this.title,
    required this.description,
    required this.status,
    required this.emptyMessage,
    required this.authenticationMessage,
    required this.retryKey,
    required this.onRetry,
    required this.validationMessage,
    required this.content,
  });

  final String title;
  final String description;
  final _TaxonomyLoadStatus status;
  final String emptyMessage;
  final String? authenticationMessage;
  final Key retryKey;
  final Future<void> Function({bool showLoading}) onRetry;
  final String? validationMessage;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: StageDesignTokens.space16),
          ..._contentForStatus(context),
          if (validationMessage != null) ...[
            const SizedBox(height: StageDesignTokens.space12),
            Text(
              validationMessage!,
              key: ValueKey('$title-validation'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: StageDesignTokens.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _contentForStatus(BuildContext context) {
    return switch (status) {
      _TaxonomyLoadStatus.loading => [
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text('読み込み中…'),
              ],
            ),
          ),
        ),
      ],
      _TaxonomyLoadStatus.loaded => [content],
      _TaxonomyLoadStatus.empty => [
        _SectionNotice(icon: Icons.inbox_outlined, message: emptyMessage),
      ],
      _TaxonomyLoadStatus.authenticationRequired => [
        _SectionNotice(
          icon: Icons.lock_outline,
          message: authenticationMessage ?? 'ログインが必要です',
        ),
        const SizedBox(height: StageDesignTokens.space12),
        _RetryButton(buttonKey: retryKey, onRetry: onRetry),
      ],
      _TaxonomyLoadStatus.rpcFailure => [
        const _SectionNotice(
          icon: Icons.cloud_off_outlined,
          message: 'データを読み込めませんでした。時間をおいて再度お試しください。',
        ),
        const SizedBox(height: StageDesignTokens.space12),
        _RetryButton(buttonKey: retryKey, onRetry: onRetry),
      ],
      _TaxonomyLoadStatus.parsingFailure => [
        const _SectionNotice(
          icon: Icons.error_outline,
          message: 'データ形式を確認できませんでした。',
        ),
        const SizedBox(height: StageDesignTokens.space12),
        _RetryButton(buttonKey: retryKey, onRetry: onRetry),
      ],
    };
  }
}

class _PrimaryRoleSection extends StatelessWidget {
  const _PrimaryRoleSection({
    required this.roles,
    required this.primaryRoleId,
    required this.validationMessage,
    required this.onSelected,
  });

  final List<StagePerformanceRole> roles;
  final String? primaryRoleId;
  final String? validationMessage;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      color: StageDesignTokens.surfaceMuted,
      borderColor: StageDesignTokens.surfaceMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('メインの役割', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '選択した役割から1つ選んでください',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: StageDesignTokens.space12),
          Wrap(
            spacing: StageDesignTokens.space8,
            runSpacing: StageDesignTokens.space8,
            children: [
              for (final role in roles)
                ChoiceChip(
                  key: ValueKey('primary-role-${role.id}'),
                  label: Text(role.name),
                  selected: primaryRoleId == role.id,
                  onSelected: (_) => onSelected(role.id),
                  avatar: primaryRoleId == role.id
                      ? const Icon(Icons.star, size: 17)
                      : null,
                  selectedColor: StageDesignTokens.surface,
                  side: BorderSide(
                    color: primaryRoleId == role.id
                        ? StageDesignTokens.purple
                        : StageDesignTokens.border,
                  ),
                ),
            ],
          ),
          if (validationMessage != null) ...[
            const SizedBox(height: StageDesignTokens.space12),
            Text(
              validationMessage!,
              key: const ValueKey('primary-role-validation'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: StageDesignTokens.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionNotice extends StatelessWidget {
  const _SectionNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: StageDesignTokens.textSecondary),
        const SizedBox(width: StageDesignTokens.space8),
        Expanded(child: Text(message)),
      ],
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

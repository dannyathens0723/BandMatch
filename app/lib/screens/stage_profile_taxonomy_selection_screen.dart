import 'package:flutter/material.dart';

import '../models/performance_domain.dart';
import '../models/stage_master_data.dart';
import '../models/stage_profile_taxonomy_draft.dart';
import '../services/stage_master_data_service.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';
import 'stage_profile_taxonomy_summary_screen.dart';

class StageProfileTaxonomySelectionScreen extends StatefulWidget {
  StageProfileTaxonomySelectionScreen({
    super.key,
    this.service,
    StageProfileTaxonomySelection? initialSelection,
  }) : initialSelection = initialSelection ?? StageProfileTaxonomySelection();

  final StageMasterDataService? service;
  final StageProfileTaxonomySelection initialSelection;

  @override
  State<StageProfileTaxonomySelectionScreen> createState() =>
      _StageProfileTaxonomySelectionScreenState();
}

class _StageProfileTaxonomySelectionScreenState
    extends State<StageProfileTaxonomySelectionScreen> {
  late final StageMasterDataService _service;
  late StageProfileTaxonomySelection _selection;

  _TaxonomyLoadStatus _genreStatus = _TaxonomyLoadStatus.loading;
  _TaxonomyLoadStatus _roleStatus = _TaxonomyLoadStatus.loading;
  StageProfileTaxonomyValidation _validation =
      const StageProfileTaxonomyValidation();
  List<StageGenre> _genres = const [];
  List<StagePerformanceRole> _roles = const [];
  int _genreRequestId = 0;
  int _roleRequestId = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? StageMasterDataService();
    _selection = widget.initialSelection;
    _loadGenres(showLoading: false);
    _loadRoles(showLoading: false);
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
        _selection = _selection.retainAvailableGenres(
          genres.map((genre) => genre.id),
        );
        _genreStatus = genres.isEmpty
            ? _TaxonomyLoadStatus.empty
            : _TaxonomyLoadStatus.loaded;
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
      final orderedIds = roles.map((role) => role.id).toList(growable: false);
      setState(() {
        _roles = roles;
        _selection = _selection.retainAvailableRoles(orderedIds);
        _roleStatus = roles.isEmpty
            ? _TaxonomyLoadStatus.empty
            : _TaxonomyLoadStatus.loaded;
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

  void _continue() {
    final validation = _selection.validate();
    setState(() => _validation = validation);
    if (!validation.isValid) return;

    final draft = _selection.toDraft(
      orderedGenreIds: _genres.map((genre) => genre.id).toList(growable: false),
      orderedRoleIds: _roles.map((role) => role.id).toList(growable: false),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StageProfileTaxonomySummaryScreen(
          draft: draft,
          genres: _genres,
          roles: _roles,
        ),
      ),
    );
  }

  bool get _requiredDataAvailable =>
      _genreStatus == _TaxonomyLoadStatus.loaded &&
      _roleStatus == _TaxonomyLoadStatus.loaded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '活動したいジャンルと役割を選んでください',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: StageDesignTokens.space8),
                      Text(
                        '複数選択できます。内容はまだ保存されません。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                                selected: _selection.selectedGenreIds.contains(
                                  genre.id,
                                ),
                                onSelected: (_) => _toggleGenre(genre.id),
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
                                onSelected: (_) => _toggleRole(role.id),
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
                          onSelected: _choosePrimaryRole,
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
                constraints: const BoxConstraints(maxWidth: 680),
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
    );
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

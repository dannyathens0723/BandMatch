import 'package:flutter/material.dart';

import '../models/stage_master_data.dart';
import '../models/stage_profile_taxonomy_draft.dart';
import '../models/stage_profile_taxonomy_persistence_result.dart';
import '../services/stage_profile_taxonomy_persistence_service.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';

typedef StageProfileTaxonomySaveCallback =
    Future<StageProfileTaxonomyDraft> Function(StageProfileTaxonomyDraft draft);

class StageProfileTaxonomySummaryScreen extends StatefulWidget {
  const StageProfileTaxonomySummaryScreen({
    required this.draft,
    required this.genres,
    required this.roles,
    required this.onSave,
    super.key,
  });

  final StageProfileTaxonomyDraft draft;
  final List<StageGenre> genres;
  final List<StagePerformanceRole> roles;
  final StageProfileTaxonomySaveCallback onSave;

  @override
  State<StageProfileTaxonomySummaryScreen> createState() =>
      _StageProfileTaxonomySummaryScreenState();
}

class _StageProfileTaxonomySummaryScreenState
    extends State<StageProfileTaxonomySummaryScreen> {
  late StageProfileTaxonomyDraft _draft;
  bool _isSaving = false;
  String? _errorMessage;
  bool _hasSaved = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _hasSaved = false;
    });

    try {
      final persistedDraft = await widget.onSave(_draft);
      if (!mounted) return;
      setState(() {
        _draft = persistedDraft;
        _hasSaved = true;
      });
    } on StageProfileTaxonomyPersistenceException catch (error, stackTrace) {
      _showSafeError(error.userMessage, error, stackTrace);
    } on StageProfileTaxonomyPersistenceParseException catch (
      error,
      stackTrace
    ) {
      _showSafeError(error.userMessage, error, stackTrace);
    } catch (error, stackTrace) {
      _showSafeError('プロフィールを保存できませんでした。時間をおいて再度お試しください。', error, stackTrace);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSafeError(String message, Object error, StackTrace stackTrace) {
    debugPrint('STAGE profile taxonomy save failed: $error\n$stackTrace');
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  @override
  Widget build(BuildContext context) {
    final genresById = {for (final genre in widget.genres) genre.id: genre};
    final rolesById = {for (final role in widget.roles) role.id: role};
    final selectedGenres = _draft.selectedGenreIds
        .map((id) => genresById[id])
        .whereType<StageGenre>()
        .toList(growable: false);
    final selectedRoles = _draft.selectedRoleIds
        .map((id) => rolesById[id])
        .whereType<StagePerformanceRole>()
        .toList(growable: false);
    final primaryRole = rolesById[_draft.primaryRoleId];

    return StageMobilePageFrame(
      child: Scaffold(
        appBar: AppBar(title: const Text('選択内容の確認')),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = StageDesignTokens.horizontalPadding(
                constraints.maxWidth,
              );
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: StageDesignTokens.maxContentWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StageCard(
                          gradient: StageDesignTokens.heroGradient,
                          borderColor: Colors.transparent,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '選択内容を確認してください',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _hasSaved
                                    ? 'プロフィールを保存しました。'
                                    : '内容を確認して保存してください。',
                                key: _hasSaved
                                    ? const ValueKey(
                                        'taxonomy-summary-save-success',
                                      )
                                    : null,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: StageDesignTokens.space16),
                        _SummarySection(
                          title: 'ダンスジャンル',
                          names: selectedGenres
                              .map((genre) => genre.name)
                              .toList(growable: false),
                        ),
                        const SizedBox(height: StageDesignTokens.space16),
                        _SummarySection(
                          title: '役割',
                          names: selectedRoles
                              .map((role) => role.name)
                              .toList(growable: false),
                        ),
                        const SizedBox(height: StageDesignTokens.space16),
                        StageCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'メインの役割',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 10),
                              StageTag(
                                primaryRole?.name ?? '未選択',
                                selected: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: StageDesignTokens.space24),
                        if (_errorMessage != null) ...[
                          StageCard(
                            key: const ValueKey('taxonomy-summary-save-error'),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: StageDesignTokens.error,
                                ),
                                const SizedBox(width: StageDesignTokens.space8),
                                Expanded(child: Text(_errorMessage!)),
                              ],
                            ),
                          ),
                          const SizedBox(height: StageDesignTokens.space16),
                        ],
                        StagePrimaryButton(
                          key: const ValueKey('taxonomy-summary-save'),
                          label: _hasSaved
                              ? 'プロフィール編集へ戻る'
                              : _isSaving
                              ? '保存しています…'
                              : '保存する',
                          icon: _hasSaved
                              ? Icons.check_rounded
                              : Icons.save_outlined,
                          onPressed: _isSaving
                              ? null
                              : _hasSaved
                              ? () => Navigator.of(context).pop(true)
                              : _save,
                        ),
                        const SizedBox(height: StageDesignTokens.space12),
                        StageOutlinedButton(
                          key: const ValueKey('taxonomy-summary-back'),
                          label: '選び直す',
                          icon: Icons.arrow_back,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.title, required this.names});

  final String title;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: StageDesignTokens.space8,
            runSpacing: StageDesignTokens.space8,
            children: names.map((name) => StageTag(name)).toList(),
          ),
        ],
      ),
    );
  }
}

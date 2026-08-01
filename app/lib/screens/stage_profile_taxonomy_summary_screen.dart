import 'package:flutter/material.dart';

import '../models/stage_master_data.dart';
import '../models/stage_profile_taxonomy_draft.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';

class StageProfileTaxonomySummaryScreen extends StatelessWidget {
  const StageProfileTaxonomySummaryScreen({
    required this.draft,
    required this.genres,
    required this.roles,
    super.key,
  });

  final StageProfileTaxonomyDraft draft;
  final List<StageGenre> genres;
  final List<StagePerformanceRole> roles;

  @override
  Widget build(BuildContext context) {
    final genresById = {for (final genre in genres) genre.id: genre};
    final rolesById = {for (final role in roles) role.id: role};
    final selectedGenres = draft.selectedGenreIds
        .map((id) => genresById[id])
        .whereType<StageGenre>()
        .toList(growable: false);
    final selectedRoles = draft.selectedRoleIds
        .map((id) => rolesById[id])
        .whereType<StagePerformanceRole>()
        .toList(growable: false);
    final primaryRole = rolesById[draft.primaryRoleId];

    return Scaffold(
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
                  constraints: const BoxConstraints(maxWidth: 680),
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
                              'この内容はまだ保存されていません。',
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

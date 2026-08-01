import 'package:flutter/material.dart';

import '../screens/stage_profile_taxonomy_selection_screen.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';

class StageProfileEditScreen extends StatelessWidget {
  const StageProfileEditScreen({super.key, this.taxonomyBuilder});

  final WidgetBuilder? taxonomyBuilder;

  Future<void> _openTaxonomy(BuildContext context) async {
    final builder = taxonomyBuilder;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: builder ?? (_) => StageProfileTaxonomySelectionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('stage-profile-edit-screen'),
      appBar: AppBar(title: const Text('プロフィール編集')),
      body: StagePageContent(
        children: [
          StageCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: StageDesignTokens.surfaceMuted,
                        borderRadius: BorderRadius.circular(
                          StageDesignTokens.radius12,
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_outlined,
                        color: StageDesignTokens.purple,
                      ),
                    ),
                    const SizedBox(width: StageDesignTokens.space12),
                    Expanded(
                      child: Text(
                        'STAGE設定',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: StageDesignTokens.space12),
                Text(
                  '活動したいダンスジャンル、パフォーマンスの役割、メインの役割を設定します。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: StageDesignTokens.textSecondary,
                  ),
                ),
                const SizedBox(height: StageDesignTokens.space16),
                StagePrimaryButton(
                  key: const ValueKey('stage-profile-edit-taxonomy'),
                  label: 'STAGE設定を編集',
                  icon: Icons.tune,
                  onPressed: () => _openTaxonomy(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: StageDesignTokens.space12),
          const StageCard(
            color: StageDesignTokens.surfaceMuted,
            borderColor: StageDesignTokens.surfaceMuted,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: StageDesignTokens.purple),
                SizedBox(width: StageDesignTokens.space12),
                Expanded(
                  child: Text(
                    '写真や自己紹介などの公開プロフィール項目は、STAGE MVPの次のステップで追加します。',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

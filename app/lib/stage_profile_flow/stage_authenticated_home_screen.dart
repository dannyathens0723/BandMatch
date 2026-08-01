import 'package:flutter/material.dart';

import '../stage_preview/navigation/stage_tab.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';

class StageAuthenticatedHomeScreen extends StatelessWidget {
  const StageAuthenticatedHomeScreen({required this.onSelectTab, super.key});

  final ValueChanged<StageTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return StagePageContent(
      key: const PageStorageKey('stage-auth-home'),
      children: [
        StageCard(
          gradient: StageDesignTokens.heroGradient,
          borderColor: Colors.transparent,
          padding: const EdgeInsets.all(StageDesignTokens.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'あなたの次のステージへ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: StageDesignTokens.space8),
              const Text(
                'ジャンルと役割を登録して、活動の準備を始めましょう。',
                style: TextStyle(color: Colors.white, height: 1.5),
              ),
              const SizedBox(height: StageDesignTokens.space16),
              StagePrimaryButton(
                key: const ValueKey('stage-home-profile-cta'),
                label: 'プロフィールを整える',
                icon: Icons.person_outline,
                light: true,
                onPressed: () => onSelectTab(StageTab.myPage),
              ),
            ],
          ),
        ),
        const StageSectionHeader(title: 'STAGEをはじめる'),
        _HomeDestinationCard(
          icon: Icons.groups_outlined,
          title: 'クルー',
          detail: '一緒にステージを目指す仲間を探す',
          onTap: () => onSelectTab(StageTab.crew),
        ),
        const SizedBox(height: StageDesignTokens.space12),
        _HomeDestinationCard(
          icon: Icons.mic_none_outlined,
          title: 'ステージ',
          detail: 'イベントやレッスンの機会を見つける',
          onTap: () => onSelectTab(StageTab.stage),
        ),
        const SizedBox(height: StageDesignTokens.space12),
        _HomeDestinationCard(
          icon: Icons.location_on_outlined,
          title: 'スタジオ',
          detail: '練習場所を探して活動につなげる',
          onTap: () => onSelectTab(StageTab.studio),
        ),
      ],
    );
  }
}

class _HomeDestinationCard extends StatelessWidget {
  const _HomeDestinationCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: StageDesignTokens.surfaceMuted,
              borderRadius: BorderRadius.circular(StageDesignTokens.radius12),
            ),
            child: Icon(icon, color: StageDesignTokens.purple),
          ),
          const SizedBox(width: StageDesignTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: StageDesignTokens.space4),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: StageDesignTokens.textMuted,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/stage_design_tokens.dart';
import '../widgets/stage_common.dart';

class StageMyPageScreen extends StatelessWidget {
  const StageMyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StagePageContent(
      key: const PageStorageKey('stage-my-page-scroll'),
      children: [
        StageCard(
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: const BoxDecoration(
                      gradient: StageDesignTokens.brandGradient,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'M',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'みお',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'K-POP ・ HIPHOP / 東京',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        const Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [StageTag('ダンス歴2年'), StageTag('初心者歓迎')],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: StageDesignTokens.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              StageOutlinedButton(
                label: 'プロフィールを編集',
                icon: Icons.edit_outlined,
                onPressed: () {},
              ),
            ],
          ),
        ),
        const StageSectionHeader(title: '活動'),
        const StageCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _MyPageRow(
                icon: Icons.groups_outlined,
                label: '運営・参加中のクルー',
                value: '2',
              ),
              _MyPageDivider(),
              _MyPageRow(icon: Icons.send_outlined, label: '応募中', value: '1'),
              _MyPageDivider(),
              _MyPageRow(icon: Icons.history, label: '過去の活動'),
            ],
          ),
        ),
        const StageSectionHeader(title: 'アカウント・設定'),
        const StageCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _MyPageRow(icon: Icons.notifications_none, label: '通知設定'),
              _MyPageDivider(),
              _MyPageRow(
                icon: Icons.workspace_premium_outlined,
                label: 'プロ・講師ステータス',
                trailingLabel: '未申請',
              ),
              _MyPageDivider(),
              _MyPageRow(icon: Icons.block_outlined, label: 'ブロックしたユーザー'),
            ],
          ),
        ),
        const StageSectionHeader(title: 'サポート'),
        const StageCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _MyPageRow(icon: Icons.help_outline, label: 'ヘルプ・お問い合わせ'),
              _MyPageDivider(),
              _MyPageRow(
                icon: Icons.description_outlined,
                label: '利用規約・プライバシー',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('ログアウト'),
          style: TextButton.styleFrom(
            foregroundColor: StageDesignTokens.error,
            minimumSize: const Size(double.infinity, 46),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'STAGE preview 0.1',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _MyPageRow extends StatelessWidget {
  const _MyPageRow({
    required this.icon,
    required this.label,
    this.value,
    this.trailingLabel,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 21, color: StageDesignTokens.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (value != null)
            Container(
              constraints: const BoxConstraints(minWidth: 24),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: const BoxDecoration(
                color: StageDesignTokens.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Text(
                value!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: StageDesignTokens.purple,
                ),
              ),
            ),
          if (trailingLabel != null)
            Text(trailingLabel!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 5),
          const Icon(
            Icons.chevron_right,
            size: 19,
            color: StageDesignTokens.textMuted,
          ),
        ],
      ),
    );
  }
}

class _MyPageDivider extends StatelessWidget {
  const _MyPageDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 47);
  }
}

import 'package:flutter/material.dart';

import '../models/stage_preview_data.dart';
import '../theme/stage_design_tokens.dart';
import '../widgets/stage_common.dart';

class StageCrewScreen extends StatefulWidget {
  const StageCrewScreen({super.key, this.onSampleRecruitmentTap});

  final VoidCallback? onSampleRecruitmentTap;

  @override
  State<StageCrewScreen> createState() => _StageCrewScreenState();
}

class _StageCrewScreenState extends State<StageCrewScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    return StagePageContent(
      key: const PageStorageKey('stage-crew-scroll'),
      children: [
        StageSegmentedControl(
          labels: const ['さがす', 'マイクルー'],
          selectedIndex: _segment,
          onSelected: (index) => setState(() => _segment = index),
        ),
        const SizedBox(height: 12),
        if (_segment == 0)
          ..._buildDiscover(context)
        else
          ..._buildMyCrews(context),
      ],
    );
  }

  List<Widget> _buildDiscover(BuildContext context) {
    return [
      const StageSearchField(hint: 'ジャンル・エリア・キーワード'),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: const [
            StageTag('おすすめ', selected: true),
            SizedBox(width: 8),
            StageTag('K-POP'),
            SizedBox(width: 8),
            StageTag('初心者歓迎'),
            SizedBox(width: 8),
            StageTag('新宿'),
          ],
        ),
      ),
      const StageSectionHeader(title: '募集中のクルー', actionLabel: '絞り込み'),
      ...StagePreviewData.recruitments.indexed.expand(
        (entry) => [
          StageRecruitmentCard(
            key: entry.$1 == 0
                ? const ValueKey('stage-crew-sample-recruitment')
                : null,
            data: entry.$2,
            onTap: entry.$1 == 0 ? widget.onSampleRecruitmentTap : null,
          ),
          const SizedBox(height: 12),
        ],
      ),
      StageOutlinedButton(label: 'クルー募集を作成', icon: Icons.add, onPressed: () {}),
    ];
  }

  List<Widget> _buildMyCrews(BuildContext context) {
    return [
      const StageSectionHeader(title: '運営中のクルー'),
      const _MyCrewCard(
        name: 'Prism Beat',
        role: 'リーダー',
        detail: '8人 ・ K-POPカバー',
        icon: Icons.auto_awesome,
      ),
      const SizedBox(height: 12),
      const StageSectionHeader(title: '参加中のクルー'),
      const _MyCrewCard(
        name: 'TOKYO GROOVE',
        role: 'メンバー',
        detail: '12人 ・ HIPHOP',
        icon: Icons.graphic_eq,
      ),
      const SizedBox(height: 16),
      StagePrimaryButton(label: '新しいクルーを作る', icon: Icons.add, onPressed: () {}),
    ];
  }
}

class _MyCrewCard extends StatelessWidget {
  const _MyCrewCard({
    required this.name,
    required this.role,
    required this.detail,
    required this.icon,
  });

  final String name;
  final String role;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: StageDesignTokens.brandGradient,
              borderRadius: BorderRadius.circular(StageDesignTokens.radius16),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StageStatusBadge(
                  label: role,
                  color: role == 'リーダー'
                      ? StageDesignTokens.purple
                      : StageDesignTokens.success,
                ),
                const SizedBox(height: 7),
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: StageDesignTokens.textMuted),
        ],
      ),
    );
  }
}

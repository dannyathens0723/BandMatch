import 'package:flutter/material.dart';

import '../models/stage_preview_data.dart';
import '../theme/stage_design_tokens.dart';
import '../widgets/stage_common.dart';

class StageHomeScreen extends StatelessWidget {
  const StageHomeScreen({required this.hasCrew, super.key});

  final bool hasCrew;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: hasCrew
          ? const _CrewJoinedHome(key: ValueKey('home-crew-joined'))
          : const _CrewNotJoinedHome(key: ValueKey('home-no-crew')),
    );
  }
}

class _CrewNotJoinedHome extends StatelessWidget {
  const _CrewNotJoinedHome({super.key});

  @override
  Widget build(BuildContext context) {
    return StagePageContent(
      key: const PageStorageKey('stage-home-no-crew-scroll'),
      children: [
        StageCard(
          gradient: StageDesignTokens.heroGradient,
          borderColor: Colors.transparent,
          radius: StageDesignTokens.radius20,
          showShadow: true,
          padding: const EdgeInsets.all(StageDesignTokens.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StageStatusBadge(label: 'はじめてのSTAGE'),
              const SizedBox(height: 14),
              Text(
                '一緒にステージへ立つ\n仲間を見つけよう',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                '好きなジャンル、エリア、経験から\nあなたに合うクルーを探せます。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFF5F0FF),
                ),
              ),
              const SizedBox(height: 18),
              StagePrimaryButton(
                label: 'クルーをさがす',
                icon: Icons.search,
                light: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
              StageTag('東京都'),
              SizedBox(width: 8),
              StageTag('締切間近'),
            ],
          ),
        ),
        const StageSectionHeader(title: 'あなたへのおすすめ', actionLabel: 'すべて見る'),
        ...StagePreviewData.recruitments
            .take(2)
            .expand(
              (item) => [
                StageRecruitmentCard(data: item),
                const SizedBox(height: 12),
              ],
            ),
        const StageCard(
          color: StageDesignTokens.charcoal,
          borderColor: StageDesignTokens.charcoal,
          child: Row(
            children: [
              Icon(Icons.local_activity_outlined, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '出演したいイベントから探す',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '大会・ショーケース情報をチェック',
                      style: TextStyle(color: Color(0xFFCFC8DD), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ],
          ),
        ),
        const StageSectionHeader(title: 'K-POPの新着募集'),
        StageRecruitmentCard(data: StagePreviewData.recruitments[2]),
      ],
    );
  }
}

class _CrewJoinedHome extends StatelessWidget {
  const _CrewJoinedHome({super.key});

  @override
  Widget build(BuildContext context) {
    return StagePageContent(
      key: const PageStorageKey('stage-home-joined-scroll'),
      children: [
        StageCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: StageDesignTokens.surfaceMuted,
                child: Icon(
                  Icons.auto_awesome,
                  color: StageDesignTokens.purple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prism Beat',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '8人 ・ K-POPカバー',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Text(
                '切り替え',
                style: TextStyle(
                  color: StageDesignTokens.purple,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.expand_more, color: StageDesignTokens.purple),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StageCard(
          color: StageDesignTokens.charcoal,
          borderColor: StageDesignTokens.charcoal,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: StageDesignTokens.brandGradient,
                  borderRadius: BorderRadius.circular(
                    StageDesignTokens.radius16,
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'D-118',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '本番まで',
                      style: TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '目標ステージ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFCFC8DD),
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'K-POP COVER DANCE\nFES TOKYO vol.5',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1.35,
                      ),
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
        ),
        const StageSectionHeader(title: '次の練習'),
        StageCard(
          borderColor: StageDesignTokens.purple,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: StageDesignTokens.purple,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '8/2(日) 18:00〜20:00',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('STUDIO LUZ 新宿 Bスタジオ'),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(
                    child: _AttendanceChoice(label: '参加', selected: true),
                  ),
                  SizedBox(width: 6),
                  Expanded(child: _AttendanceChoice(label: '未定')),
                  SizedBox(width: 6),
                  Expanded(child: _AttendanceChoice(label: '不参加')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StageCard(
          color: const Color(0xFFFFEDF3),
          borderColor: const Color(0xFFFFB4CC),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(
                Icons.schedule_outlined,
                color: StageDesignTokens.pink,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '日程調整が未回答です',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '8月後半の追加練習 ・ 明日まで',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: StageDesignTokens.pink),
            ],
          ),
        ),
        const StageSectionHeader(title: 'クルーの最新情報'),
        const _CrewUpdateCard(
          icon: Icons.campaign_outlined,
          eyebrow: 'お知らせ',
          title: '衣装イメージを共有しました',
          detail: 'リーダーより ・ 2時間前',
        ),
        const SizedBox(height: 10),
        const _CrewUpdateCard(
          icon: Icons.play_circle_outline,
          eyebrow: '練習曲・参考動画',
          title: 'Super Shy / NewJeans',
          detail: 'サビ振り入れ用 ・ きのう',
        ),
        const StageSectionHeader(title: 'ほかのおすすめ募集'),
        StageRecruitmentCard(
          data: StagePreviewData.recruitments[1],
          compact: true,
        ),
      ],
    );
  }
}

class _AttendanceChoice extends StatelessWidget {
  const _AttendanceChoice({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? StageDesignTokens.purple
            : StageDesignTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(StageDesignTokens.radius8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: selected ? Colors.white : StageDesignTokens.textSecondary,
        ),
      ),
    );
  }
}

class _CrewUpdateCard extends StatelessWidget {
  const _CrewUpdateCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: StageDesignTokens.surfaceMuted,
              borderRadius: BorderRadius.circular(StageDesignTokens.radius12),
            ),
            child: Icon(icon, color: StageDesignTokens.purple, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: StageDesignTokens.purple,
                  ),
                ),
                const SizedBox(height: 2),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
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

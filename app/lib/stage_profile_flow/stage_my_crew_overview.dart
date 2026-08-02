import 'package:flutter/material.dart';

import '../models/stage_my_crew.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';

typedef StageMyCrewDetailBuilder =
    Widget Function(BuildContext context, StageMyCrew crew);
typedef StageMyCrewApplicationDetailBuilder =
    Widget Function(BuildContext context, StageMyCrewApplication application);

class StageMyCrewOverviewPanel extends StatelessWidget {
  const StageMyCrewOverviewPanel({
    required this.future,
    required this.onRetry,
    required this.onFindCrews,
    required this.onOpenCrew,
    required this.onOpenApplication,
    super.key,
  });

  final Future<StageMyCrewOverview> future;
  final VoidCallback onRetry;
  final VoidCallback onFindCrews;
  final ValueChanged<StageMyCrew> onOpenCrew;
  final ValueChanged<StageMyCrewApplication> onOpenApplication;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StageMyCrewOverview>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            key: ValueKey('stage-my-crew-loading'),
            padding: EdgeInsets.symmetric(vertical: StageDesignTokens.space32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) return _ErrorState(onRetry: onRetry);
        final overview = snapshot.data!;
        if (overview.isEmpty) {
          return _EmptyState(onFindCrews: onFindCrews);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (overview.managedCrews.isNotEmpty)
              _CrewSection(
                key: const ValueKey('stage-my-crew-managed-section'),
                title: '管理中のクルー',
                crews: overview.managedCrews,
                onOpen: onOpenCrew,
              ),
            if (overview.participatingCrews.isNotEmpty) ...[
              const SizedBox(height: StageDesignTokens.space20),
              _CrewSection(
                key: const ValueKey('stage-my-crew-participating-section'),
                title: '参加中のクルー',
                crews: overview.participatingCrews,
                onOpen: onOpenCrew,
              ),
            ],
            if (overview.applications.isNotEmpty) ...[
              const SizedBox(height: StageDesignTokens.space20),
              Text('応募中・応募履歴', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: StageDesignTokens.space12),
              ...overview.applications.map(
                (application) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: StageDesignTokens.space12,
                  ),
                  child: _ApplicationCard(
                    application: application,
                    onTap: () => onOpenApplication(application),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CrewSection extends StatelessWidget {
  const _CrewSection({
    required this.title,
    required this.crews,
    required this.onOpen,
    super.key,
  });

  final String title;
  final List<StageMyCrew> crews;
  final ValueChanged<StageMyCrew> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: StageDesignTokens.space12),
        ...crews.map(
          (crew) => Padding(
            padding: const EdgeInsets.only(bottom: StageDesignTokens.space12),
            child: StageCard(
              key: ValueKey('stage-my-crew-card-${crew.crewId}'),
              onTap: () => onOpen(crew),
              showShadow: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CrewAvatar(crew: crew),
                      const SizedBox(width: StageDesignTokens.space12),
                      Expanded(
                        child: Text(
                          crew.crewName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      StageStatusBadge(
                        label: _roleLabel(crew),
                        color: crew.isManaged
                            ? StageDesignTokens.purple
                            : StageDesignTokens.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: StageDesignTokens.space12),
                  Text(
                    '${crew.activeMemberCount}名 ・ 募集中${crew.openRecruitmentCount}件',
                  ),
                  if (crew.danceGenreNames.isNotEmpty ||
                      crew.areaNames.isNotEmpty) ...[
                    const SizedBox(height: StageDesignTokens.space8),
                    Wrap(
                      spacing: StageDesignTokens.space8,
                      runSpacing: StageDesignTokens.space8,
                      children: [
                        ...crew.danceGenreNames.map(StageTag.new),
                        ...crew.areaNames.map(
                          (area) => StageTag(
                            area,
                            color: StageDesignTokens.surfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, required this.onTap});

  final StageMyCrewApplication application;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      key: ValueKey('stage-my-crew-application-${application.applicationId}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  application.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StageStatusBadge(
                label: _applicationStatusLabel(application.applicationStatus),
                color: _applicationStatusColor(application.applicationStatus),
              ),
            ],
          ),
          const SizedBox(height: StageDesignTokens.space8),
          Text(application.crewName),
          const SizedBox(height: StageDesignTokens.space8),
          Text(
            '応募 ${_date(application.appliedAt)} ・ 募集${_postStatusLabel(application.postStatus)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CrewAvatar extends StatelessWidget {
  const _CrewAvatar({required this.crew});

  final StageMyCrew crew;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: StageDesignTokens.surfaceMuted,
      backgroundImage: crew.crewAvatarUrl == null
          ? null
          : NetworkImage(crew.crewAvatarUrl!),
      child: crew.crewAvatarUrl == null
          ? const Icon(Icons.groups_rounded)
          : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onFindCrews});

  final VoidCallback onFindCrews;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const StageEmptyState(
          key: ValueKey('stage-my-crew-empty'),
          icon: Icons.groups_outlined,
          title: 'まだクルーがありません',
          message: 'イベントを目標にした期間限定のクルーに応募してみましょう',
        ),
        const SizedBox(height: StageDesignTokens.space12),
        StagePrimaryButton(
          label: '募集をさがす',
          icon: Icons.search_rounded,
          onPressed: onFindCrews,
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      key: const ValueKey('stage-my-crew-error'),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, color: StageDesignTokens.error),
          const SizedBox(height: StageDesignTokens.space8),
          const Text('マイクルーを読み込めませんでした'),
          const SizedBox(height: StageDesignTokens.space12),
          OutlinedButton(
            key: const ValueKey('stage-my-crew-retry'),
            onPressed: onRetry,
            child: const Text('再試行'),
          ),
        ],
      ),
    );
  }
}

class StageMyCrewDetailScreen extends StatelessWidget {
  const StageMyCrewDetailScreen({required this.crew, super.key});

  final StageMyCrew crew;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('stage-my-crew-detail-screen'),
      appBar: AppBar(title: const Text('クルー詳細')),
      body: ListView(
        padding: const EdgeInsets.all(StageDesignTokens.space16),
        children: [
          StageCard(
            gradient: StageDesignTokens.heroGradient,
            borderColor: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StageStatusBadge(label: _roleLabel(crew)),
                const SizedBox(height: StageDesignTokens.space12),
                Text(
                  crew.crewName,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: StageDesignTokens.space16),
          StageCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(crew.crewBio ?? 'クルー紹介はまだ登録されていません。'),
                const SizedBox(height: StageDesignTokens.space12),
                Text('${crew.activeMemberCount}名が参加中'),
                Text('公開中の募集 ${crew.openRecruitmentCount}件'),
              ],
            ),
          ),
          const SizedBox(height: StageDesignTokens.space16),
          const StageCard(
            color: StageDesignTokens.surfaceMuted,
            child: Text('予定・メンバー管理などのクルー機能は現在準備中です'),
          ),
        ],
      ),
    );
  }
}

class StageMyCrewApplicationDetailScreen extends StatelessWidget {
  const StageMyCrewApplicationDetailScreen({
    required this.application,
    super.key,
  });

  final StageMyCrewApplication application;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('stage-my-crew-application-detail-screen'),
      appBar: AppBar(title: const Text('応募詳細')),
      body: ListView(
        padding: const EdgeInsets.all(StageDesignTokens.space16),
        children: [
          StageCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StageStatusBadge(
                  label: _applicationStatusLabel(application.applicationStatus),
                  color: _applicationStatusColor(application.applicationStatus),
                ),
                const SizedBox(height: StageDesignTokens.space12),
                Text(
                  application.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: StageDesignTokens.space8),
                Text(application.crewName),
                const SizedBox(height: StageDesignTokens.space16),
                Text(application.body),
                const SizedBox(height: StageDesignTokens.space16),
                Text('応募日: ${_date(application.appliedAt)}'),
                Text('募集状態: ${_postStatusLabel(application.postStatus)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _roleLabel(StageMyCrew crew) {
  if (crew.isCreator) return '作成者・管理中';
  return crew.isManaged ? '管理中' : '参加中';
}

String _applicationStatusLabel(String status) => switch (status) {
  'pending' => '確認中',
  'accepted' => '承認済み',
  'rejected' => '見送り',
  _ => '状態確認中',
};

Color _applicationStatusColor(String status) => switch (status) {
  'accepted' => StageDesignTokens.success,
  'rejected' => StageDesignTokens.textMuted,
  _ => StageDesignTokens.purple,
};

String _postStatusLabel(String status) => switch (status) {
  'open' => '公開中',
  'closed' => '終了',
  _ => '非公開',
};

String _date(DateTime date) =>
    '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

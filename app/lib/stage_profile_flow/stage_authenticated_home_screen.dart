import 'package:flutter/material.dart';

import '../models/stage_activity.dart';
import '../models/stage_crew_recruitment.dart';
import '../models/stage_event.dart';
import '../models/stage_home_dashboard.dart';
import '../models/stage_studio.dart';
import '../services/stage_crew_activity_service.dart';
import '../services/stage_event_discovery_service.dart';
import '../services/stage_home_dashboard_service.dart';
import '../services/stage_studio_discovery_service.dart';
import '../stage_preview/navigation/stage_tab.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';
import 'stage_crew_announcement_detail_screen.dart';
import 'stage_crew_detail_screen.dart';
import 'stage_event_detail_screen.dart';
import 'stage_studio_detail_screen.dart';

class StageAuthenticatedHomeScreen extends StatefulWidget {
  const StageAuthenticatedHomeScreen({
    required this.onSelectTab,
    super.key,
    this.repository,
    this.refreshToken = 0,
    this.onOpenMyCrew,
    this.onOpenCrew,
    this.announcementRepository,
  });

  final ValueChanged<StageTab> onSelectTab;
  final StageHomeDashboardRepository? repository;
  final int refreshToken;
  final VoidCallback? onOpenMyCrew;
  final ValueChanged<String>? onOpenCrew;
  final StageCrewActivityRepository? announcementRepository;

  @override
  State<StageAuthenticatedHomeScreen> createState() =>
      _StageAuthenticatedHomeScreenState();
}

class _StageAuthenticatedHomeScreenState
    extends State<StageAuthenticatedHomeScreen> {
  late final StageHomeDashboardRepository _repository;
  StageHomeDashboard? _dashboard;
  Object? _loadError;
  bool _loading = true;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? StageHomeDashboardService();
    _load(showLoading: false);
  }

  @override
  void didUpdateWidget(covariant StageAuthenticatedHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load(showLoading: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _dashboard == null) {
      return const Center(
        key: ValueKey('stage-home-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_loadError != null && _dashboard == null) {
      return _HomeFatalError(onRetry: _load);
    }

    final dashboard = _dashboard!;
    final profile = dashboard.profile.data;
    final myCrew = dashboard.myCrew.data;
    final activity = dashboard.activity.data ?? const <StageActivity>[];
    final crewActivity = activity
        .where((item) => item.activityType.startsWith('crew_'))
        .toList(growable: false);
    final recruitments =
        dashboard.recruitments.data ?? const <StageCrewRecruitment>[];
    final events = dashboard.events.data ?? const <StageEvent>[];
    final studios = dashboard.studios.data ?? const <StageStudio>[];
    final attention = activity.where((item) => item.requiresAttention).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: StagePageContent(
        key: const PageStorageKey('stage-auth-home'),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_loadError != null)
            _SectionError(
              message: 'ホームを更新できませんでした。表示中の情報を確認できます。',
              onRetry: _load,
            ),
          StageCard(
            gradient: StageDesignTokens.heroGradient,
            borderColor: Colors.transparent,
            padding: const EdgeInsets.all(StageDesignTokens.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile == null
                      ? 'あなたの次のステージへ'
                      : '${profile.displayName}さん、次のステージへ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: StageDesignTokens.space8),
                Text(
                  profile == null
                      ? 'クルー、イベント、練習場所を見つけましょう。'
                      : 'プロフィール完成度 ${profile.profileCompleteness}% ・ '
                            '${profile.primaryPerformanceRoleName ?? 'メイン役割未設定'}',
                  style: const TextStyle(color: Colors.white, height: 1.5),
                ),
                const SizedBox(height: StageDesignTokens.space16),
                StagePrimaryButton(
                  key: const ValueKey('stage-home-profile-cta'),
                  label: profile != null && profile.profileCompleteness >= 100
                      ? 'プロフィールを確認'
                      : 'プロフィールを整える',
                  icon: Icons.person_outline,
                  light: true,
                  onPressed: () => widget.onSelectTab(StageTab.myPage),
                ),
              ],
            ),
          ),
          if (dashboard.profile.hasError)
            const _SectionError(message: 'プロフィール概要を取得できませんでした。'),
          const StageSectionHeader(title: 'いまの活動'),
          _ActivitySummary(
            managedCount: myCrew?.managedCrews.length,
            participatingCount: myCrew?.participatingCrews.length,
            applicationCount: myCrew?.applications.length,
            attentionCount: attention.length,
            hasError: dashboard.myCrew.hasError || dashboard.activity.hasError,
            onOpenCrew:
                widget.onOpenMyCrew ?? () => widget.onSelectTab(StageTab.crew),
          ),
          if (attention.isNotEmpty) ...[
            const StageSectionHeader(title: '確認が必要です'),
            ...attention
                .take(3)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: StageDesignTokens.space12,
                    ),
                    child: StageCard(
                      key: ValueKey('stage-home-attention-${item.activityKey}'),
                      onTap: () => _openCrewActivity(item),
                      color: const Color(0xFFFFF2F6),
                      borderColor: const Color(0xFFFFC8D9),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_add_alt_1_outlined,
                            color: StageDesignTokens.pink,
                          ),
                          const SizedBox(width: StageDesignTokens.space12),
                          Expanded(
                            child: Text(
                              '${item.actorDisplayName ?? '応募者'}さんから '
                              '${item.crewName} への応募があります',
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
          if (crewActivity.isNotEmpty) ...[
            const StageSectionHeader(title: 'クルーの最新情報'),
            ...crewActivity
                .take(3)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: StageDesignTokens.space12,
                    ),
                    child: StageCard(
                      key: ValueKey(
                        'stage-home-crew-activity-${item.activityKey}',
                      ),
                      onTap: () => _openCrewActivity(item),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _crewActivityIcon(item.activityType),
                          color: StageDesignTokens.purple,
                        ),
                        title: Text(item.postTitle ?? item.crewName),
                        subtitle: Text(
                          '${item.crewName} ・ ${_crewActivityLabel(item.activityType, item.activityStatus)}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    ),
                  ),
                ),
          ],
          const StageSectionHeader(title: 'クイックアクション'),
          _QuickActions(onSelectTab: widget.onSelectTab),
          const StageSectionHeader(title: 'おすすめのクルー募集'),
          if (dashboard.recruitments.hasError)
            const _SectionError(message: 'クルー募集を読み込めませんでした。')
          else if (recruitments.isEmpty)
            const _CompactEmpty(message: '現在公開中のクルー募集はありません。')
          else
            ...recruitments
                .take(3)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: StageDesignTokens.space12,
                    ),
                    child: _HomeCrewCard(
                      recruitment: item,
                      onTap: () => _openCrew(item),
                    ),
                  ),
                ),
          _SeeAllButton(
            label: 'クルー募集をもっと見る',
            onPressed: () => widget.onSelectTab(StageTab.crew),
          ),
          const StageSectionHeader(title: '新しいステージ'),
          if (dashboard.events.hasError)
            const _SectionError(message: 'イベント情報を読み込めませんでした。')
          else if (events.isEmpty)
            const _CompactEmpty(message: '現在公開中のイベントはありません。')
          else
            ...events
                .take(2)
                .map(
                  (event) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: StageDesignTokens.space12,
                    ),
                    child: _HomeEventCard(
                      event: event,
                      onTap: () => _openEvent(event),
                    ),
                  ),
                ),
          _SeeAllButton(
            label: 'ステージをもっと見る',
            onPressed: () => widget.onSelectTab(StageTab.stage),
          ),
          const StageSectionHeader(title: '練習場所を探す'),
          if (dashboard.studios.hasError)
            const _SectionError(message: 'スタジオ情報を読み込めませんでした。')
          else if (studios.isEmpty)
            const _CompactEmpty(message: '現在公開中のスタジオはありません。')
          else
            ...studios
                .take(2)
                .map(
                  (studio) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: StageDesignTokens.space12,
                    ),
                    child: _HomeStudioCard(
                      studio: studio,
                      onTap: () => _openStudio(studio),
                    ),
                  ),
                ),
          _SeeAllButton(
            label: 'スタジオをもっと見る',
            onPressed: () => widget.onSelectTab(StageTab.studio),
          ),
        ],
      ),
    );
  }

  Future<void> _load({bool showLoading = true}) async {
    final requestId = ++_requestId;
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final dashboard = await _repository.fetchDashboard();
      if (!mounted || requestId != _requestId) return;
      setState(() {
        if (dashboard.allSectionsFailed) {
          _loadError = StateError('Every dashboard section failed');
        } else {
          _dashboard = dashboard;
          _loadError = null;
        }
        _loading = false;
      });
    } on Object catch (error, stackTrace) {
      debugPrint('STAGE Home dashboard failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _openCrew(StageCrewRecruitment recruitment) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StageCrewDetailScreen(recruitment: recruitment),
      ),
    );
    await _load(showLoading: false);
  }

  Future<void> _openCrewActivity(StageActivity item) async {
    final announcementId = item.announcementId;
    if (announcementId != null) {
      await openStageCrewAnnouncementDetail(
        context,
        crewId: item.crewId,
        crewName: item.crewName,
        announcementId: announcementId,
        repository: widget.announcementRepository,
      );
      return;
    }
    final openCrew = widget.onOpenCrew;
    if (openCrew != null) {
      openCrew(item.crewId);
    } else if (widget.onOpenMyCrew != null) {
      widget.onOpenMyCrew!();
    } else {
      widget.onSelectTab(StageTab.crew);
    }
  }

  Future<void> _openEvent(StageEvent event) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StageEventDetailScreen(
          eventId: event.eventId,
          repository: StageEventDiscoveryService(),
        ),
      ),
    );
  }

  Future<void> _openStudio(StageStudio studio) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StageStudioDetailScreen(
          studioId: studio.studioId,
          repository: StageStudioDiscoveryService(),
        ),
      ),
    );
  }
}

class _ActivitySummary extends StatelessWidget {
  const _ActivitySummary({
    required this.managedCount,
    required this.participatingCount,
    required this.applicationCount,
    required this.attentionCount,
    required this.hasError,
    required this.onOpenCrew,
  });

  final int? managedCount;
  final int? participatingCount;
  final int? applicationCount;
  final int attentionCount;
  final bool hasError;
  final VoidCallback onOpenCrew;

  @override
  Widget build(BuildContext context) {
    if (hasError && managedCount == null) {
      return const _SectionError(message: '活動概要を読み込めませんでした。');
    }
    return StageCard(
      key: const ValueKey('stage-home-activity-summary'),
      onTap: onOpenCrew,
      child: Column(
        children: [
          Wrap(
            spacing: StageDesignTokens.space8,
            runSpacing: StageDesignTokens.space8,
            children: [
              StageTag('管理 ${managedCount ?? 0}'),
              StageTag('参加 ${participatingCount ?? 0}'),
              StageTag('応募 ${applicationCount ?? 0}'),
              if (attentionCount > 0)
                StageTag(
                  '要確認 $attentionCount',
                  color: const Color(0xFFFFE8EF),
                  foregroundColor: StageDesignTokens.pink,
                ),
            ],
          ),
          const SizedBox(height: StageDesignTokens.space12),
          const Row(
            children: [
              Expanded(child: Text('マイクルーと応募状況を確認')),
              Icon(
                Icons.chevron_right_rounded,
                color: StageDesignTokens.purple,
              ),
            ],
          ),
          if (hasError) ...[
            const SizedBox(height: StageDesignTokens.space8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '活動の一部を読み込めませんでした。',
                style: TextStyle(color: StageDesignTokens.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onSelectTab});

  final ValueChanged<StageTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.groups_outlined,
            label: 'クルーを探す',
            onTap: () => onSelectTab(StageTab.crew),
          ),
        ),
        const SizedBox(width: StageDesignTokens.space8),
        Expanded(
          child: _QuickAction(
            icon: Icons.mic_none_outlined,
            label: 'ステージ',
            onTap: () => onSelectTab(StageTab.stage),
          ),
        ),
        const SizedBox(width: StageDesignTokens.space8),
        Expanded(
          child: _QuickAction(
            icon: Icons.location_on_outlined,
            label: 'スタジオ',
            onTap: () => onSelectTab(StageTab.studio),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Column(
        children: [
          Icon(icon, color: StageDesignTokens.purple),
          const SizedBox(height: StageDesignTokens.space8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _HomeCrewCard extends StatelessWidget {
  const _HomeCrewCard({required this.recruitment, required this.onTap});

  final StageCrewRecruitment recruitment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      key: ValueKey('stage-home-crew-${recruitment.postId}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recruitment.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StageDesignTokens.space4),
          Text(recruitment.crewName),
          const SizedBox(height: StageDesignTokens.space8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...recruitment.danceGenreNames.take(3).map(StageTag.new),
              ...recruitment.areaNames.take(1).map(StageTag.new),
            ],
          ),
        ],
      ),
    );
  }
}

IconData _crewActivityIcon(String type) => switch (type) {
  'crew_practice' => Icons.event_available_outlined,
  'crew_poll' => Icons.how_to_vote_outlined,
  'crew_announcement' => Icons.campaign_outlined,
  'crew_resource' => Icons.folder_open_outlined,
  _ => Icons.groups_outlined,
};

String _crewActivityLabel(String type, String status) => switch (type) {
  'crew_practice' => status == 'cancelled' ? '練習中止' : '練習予定',
  'crew_poll' => status == 'open' ? '回答受付中' : '日程確定',
  'crew_announcement' => 'お知らせ',
  'crew_resource' => '練習資料',
  _ => 'クルー活動',
};

class _HomeEventCard extends StatelessWidget {
  const _HomeEventCard({required this.event, required this.onTap});

  final StageEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      key: ValueKey('stage-home-event-${event.eventId}'),
      onTap: onTap,
      child: Row(
        children: [
          const Icon(
            Icons.local_activity_outlined,
            color: StageDesignTokens.pink,
          ),
          const SizedBox(width: StageDesignTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('${event.venueName} ・ ${_date(event.startsAt)}'),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _HomeStudioCard extends StatelessWidget {
  const _HomeStudioCard({required this.studio, required this.onTap});

  final StageStudio studio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      key: ValueKey('stage-home-studio-${studio.studioId}'),
      onTap: onTap,
      child: Row(
        children: [
          const Icon(
            Icons.surround_sound_outlined,
            color: StageDesignTokens.purple,
          ),
          const SizedBox(width: StageDesignTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studio.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  studio.nearestStationName ??
                      studio.areaName ??
                      studio.addressDisplay,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, this.onRetry});

  final String message;
  final Future<void> Function({bool showLoading})? onRetry;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      color: StageDesignTokens.surfaceMuted,
      borderColor: StageDesignTokens.surfaceMuted,
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: StageDesignTokens.error),
          const SizedBox(width: StageDesignTokens.space8),
          Expanded(child: Text(message)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('再試行')),
        ],
      ),
    );
  }
}

class _CompactEmpty extends StatelessWidget {
  const _CompactEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      color: StageDesignTokens.surfaceMuted,
      borderColor: StageDesignTokens.surfaceMuted,
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: TextButton(onPressed: onPressed, child: Text('$label →')),
    );
  }
}

class _HomeFatalError extends StatelessWidget {
  const _HomeFatalError({required this.onRetry});

  final Future<void> Function({bool showLoading}) onRetry;

  @override
  Widget build(BuildContext context) {
    return StagePageContent(
      children: [
        StageCard(
          key: const ValueKey('stage-home-error'),
          child: Column(
            children: [
              const Text('ホームを読み込めませんでした。'),
              const SizedBox(height: StageDesignTokens.space12),
              OutlinedButton(
                key: const ValueKey('stage-home-retry'),
                onPressed: onRetry,
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _date(DateTime date) =>
    '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}';

import 'package:flutter/material.dart';

import '../models/stage_activity.dart';
import '../services/stage_activity_service.dart';
import '../services/stage_crew_activity_service.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';
import 'stage_crew_announcement_detail_screen.dart';

class StageActivityCenterScreen extends StatefulWidget {
  const StageActivityCenterScreen({
    super.key,
    this.repository,
    this.onOpenCrewArea,
    this.onOpenCrew,
    this.announcementRepository,
  });

  final StageActivityRepository? repository;
  final VoidCallback? onOpenCrewArea;
  final ValueChanged<String>? onOpenCrew;
  final StageCrewActivityRepository? announcementRepository;

  @override
  State<StageActivityCenterScreen> createState() =>
      _StageActivityCenterScreenState();
}

class _StageActivityCenterScreenState extends State<StageActivityCenterScreen> {
  late final StageActivityRepository _repository;
  late Future<List<StageActivity>> _activity;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? StageActivityService();
    _activity = _repository.fetchMyActivity();
  }

  @override
  Widget build(BuildContext context) {
    return StageMobilePageFrame(
      child: Scaffold(
        key: const ValueKey('stage-activity-center'),
        appBar: AppBar(title: const Text('アクティビティ')),
        body: FutureBuilder<List<StageActivity>>(
          future: _activity,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                key: ValueKey('stage-activity-loading'),
                child: CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return _ActivityError(onRetry: _retry);
            }
            final items = snapshot.data ?? const <StageActivity>[];
            if (items.isEmpty) {
              return const StagePageContent(
                children: [
                  StageEmptyState(
                    key: ValueKey('stage-activity-empty'),
                    icon: Icons.notifications_none_rounded,
                    title: '新しいアクティビティはありません',
                    message: '応募やクルーの動きがあると、ここで確認できます。',
                  ),
                ],
              );
            }
            return StagePageContent(
              children: [
                const StageCard(
                  color: StageDesignTokens.surfaceMuted,
                  borderColor: StageDesignTokens.surfaceMuted,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: StageDesignTokens.purple,
                      ),
                      SizedBox(width: StageDesignTokens.space12),
                      Expanded(
                        child: Text(
                          '現在は応募・承認・参加状況から最新のアクティビティを表示しています。既読管理はまだありません。',
                        ),
                      ),
                    ],
                  ),
                ),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: StageDesignTokens.space12,
                    ),
                    child: _ActivityCard(item: item, onTap: _onTap(item)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _retry() {
    final activity = _repository.fetchMyActivity();
    setState(() {
      _activity = activity;
    });
  }

  VoidCallback? _onTap(StageActivity item) {
    final announcementId = item.announcementId;
    if (announcementId != null) {
      return () => openStageCrewAnnouncementDetail(
        context,
        crewId: item.crewId,
        crewName: item.crewName,
        announcementId: announcementId,
        repository: widget.announcementRepository,
      );
    }
    if (widget.onOpenCrew == null && widget.onOpenCrewArea == null) return null;
    return () {
      Navigator.of(context).pop();
      final openCrew = widget.onOpenCrew;
      if (openCrew != null) {
        openCrew(item.crewId);
      } else {
        widget.onOpenCrewArea!();
      }
    };
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.item, required this.onTap});

  final StageActivity item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      key: ValueKey('stage-activity-${item.activityKey}'),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: item.requiresAttention
                ? const Color(0xFFFFE8EF)
                : StageDesignTokens.surfaceMuted,
            foregroundColor: item.requiresAttention
                ? StageDesignTokens.pink
                : StageDesignTokens.purple,
            child: Icon(_icon(item)),
          ),
          const SizedBox(width: StageDesignTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(item),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: StageDesignTokens.space4),
                Text(_description(item)),
                const SizedBox(height: StageDesignTokens.space8),
                Text(
                  _dateTime(item.occurredAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              color: StageDesignTokens.textMuted,
            ),
        ],
      ),
    );
  }
}

class _ActivityError extends StatelessWidget {
  const _ActivityError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return StagePageContent(
      children: [
        StageCard(
          key: const ValueKey('stage-activity-error'),
          child: Column(
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: StageDesignTokens.error,
              ),
              const SizedBox(height: StageDesignTokens.space8),
              const Text('アクティビティを読み込めませんでした。'),
              const SizedBox(height: StageDesignTokens.space12),
              OutlinedButton(onPressed: onRetry, child: const Text('再試行')),
            ],
          ),
        ),
      ],
    );
  }
}

IconData _icon(StageActivity item) => switch (item.activityType) {
  'crew_practice' => Icons.event_available_outlined,
  'crew_poll' => Icons.how_to_vote_outlined,
  'crew_announcement' => Icons.campaign_outlined,
  'crew_resource' => Icons.folder_open_outlined,
  'managed_application' => Icons.person_add_alt_1_outlined,
  'crew_membership' => Icons.groups_outlined,
  _ => switch (item.activityStatus) {
    'accepted' => Icons.check_circle_outline_rounded,
    'rejected' => Icons.info_outline_rounded,
    _ => Icons.schedule_send_outlined,
  },
};

String _title(StageActivity item) => switch (item.activityType) {
  'crew_practice' => '練習予定が更新されました',
  'crew_poll' when item.activityStatus == 'open' => '日程調整の回答を確認してください',
  'crew_poll' => '日程調整が確定しました',
  'crew_announcement' => 'クルーからのお知らせ',
  'crew_resource' => '新しい練習資料があります',
  'managed_application' when item.activityStatus == 'pending' => '新しい応募があります',
  'managed_application' => '応募の対応状況が更新されました',
  'crew_membership' => 'クルーに参加しています',
  _ => switch (item.activityStatus) {
    'accepted' => '応募が承認されました',
    'rejected' => '応募結果を確認してください',
    _ => '応募を受け付けました',
  },
};

String _description(StageActivity item) {
  final post = item.postTitle == null ? '' : '「${item.postTitle}」';
  if (item.activityType == 'managed_application') {
    final actor = item.actorDisplayName ?? '応募者';
    return '$actorさんが${item.crewName}の$postに応募しました。';
  }
  if (item.activityType == 'crew_membership') {
    return '${item.crewName}の参加状況をマイクルーで確認できます。';
  }
  if (item.activityType.startsWith('crew_')) {
    final title = item.postTitle == null ? '' : '「${item.postTitle}」';
    return '${item.crewName} $title';
  }
  return '${item.crewName} $post';
}

String _dateTime(DateTime date) =>
    '${date.year}/${date.month.toString().padLeft(2, '0')}/'
    '${date.day.toString().padLeft(2, '0')} '
    '${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}';

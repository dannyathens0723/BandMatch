import 'package:flutter/material.dart';

import '../models/stage_crew_activity.dart';
import '../services/stage_crew_activity_service.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';

Future<void> openStageCrewAnnouncementDetail(
  BuildContext context, {
  required String crewId,
  required String crewName,
  required String announcementId,
  StageCrewActivityRepository? repository,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) => StageCrewAnnouncementDetailScreen(
      crewId: crewId,
      crewName: crewName,
      announcementId: announcementId,
      repository: repository,
    ),
  ),
);

class StageCrewAnnouncementDetailScreen extends StatefulWidget {
  const StageCrewAnnouncementDetailScreen({
    required this.crewId,
    required this.crewName,
    required this.announcementId,
    super.key,
    this.repository,
  });

  final String crewId;
  final String crewName;
  final String announcementId;
  final StageCrewActivityRepository? repository;

  @override
  State<StageCrewAnnouncementDetailScreen> createState() =>
      _StageCrewAnnouncementDetailScreenState();
}

class _StageCrewAnnouncementDetailScreenState
    extends State<StageCrewAnnouncementDetailScreen> {
  late final StageCrewActivityRepository _repository;
  late Future<StageCrewAnnouncement> _announcement;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? StageCrewActivityService();
    _announcement = _load();
  }

  @override
  Widget build(BuildContext context) {
    return StageMobilePageFrame(
      child: Scaffold(
        key: const ValueKey('stage-crew-announcement-detail'),
        appBar: AppBar(title: const Text('お知らせ')),
        body: FutureBuilder<StageCrewAnnouncement>(
          future: _announcement,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _AnnouncementUnavailable(onRetry: _retry);
            }
            final announcement = snapshot.data!;
            return StagePageContent(
              children: [
                Text(
                  widget.crewName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: StageDesignTokens.space8),
                StageCard(
                  key: ValueKey(
                    'stage-crew-announcement-${announcement.announcementId}',
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              announcement.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          StageStatusBadge(
                            label: announcement.status == 'archived'
                                ? 'アーカイブ'
                                : '公開中',
                          ),
                        ],
                      ),
                      const SizedBox(height: StageDesignTokens.space16),
                      Text(announcement.body ?? ''),
                      const SizedBox(height: StageDesignTokens.space20),
                      const Divider(),
                      if (announcement.authorDisplayName != null)
                        Text('投稿: ${announcement.authorDisplayName}'),
                      if (announcement.publishedAt != null)
                        Text('公開: ${_dateTime(announcement.publishedAt!)}')
                      else if (announcement.createdAt != null)
                        Text('作成: ${_dateTime(announcement.createdAt!)}'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<StageCrewAnnouncement> _load() async {
    try {
      final snapshot = await _repository.fetchCrewActivity(widget.crewId);
      for (final announcement in snapshot.announcements) {
        if (announcement.announcementId == widget.announcementId) {
          return announcement;
        }
      }
      throw StateError('Announcement is not available for this Crew');
    } on Object catch (error, stackTrace) {
      debugPrint('STAGE Crew announcement detail failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  void _retry() {
    setState(() {
      _announcement = _load();
    });
  }
}

class _AnnouncementUnavailable extends StatelessWidget {
  const _AnnouncementUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => StagePageContent(
    children: [
      StageCard(
        key: const ValueKey('stage-crew-announcement-unavailable'),
        child: Column(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              color: StageDesignTokens.error,
            ),
            const SizedBox(height: StageDesignTokens.space8),
            const Text('お知らせを表示できません。アクセス権または公開状態をご確認ください。'),
            const SizedBox(height: StageDesignTokens.space12),
            OutlinedButton(onPressed: onRetry, child: const Text('再試行')),
          ],
        ),
      ),
    ],
  );
}

String _dateTime(DateTime value) =>
    '${value.year}/${value.month.toString().padLeft(2, '0')}/'
    '${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

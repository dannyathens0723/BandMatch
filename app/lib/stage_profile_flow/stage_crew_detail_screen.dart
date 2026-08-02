import 'package:flutter/material.dart';

import '../models/recruitment_application.dart';
import '../models/stage_crew_recruitment.dart';
import '../services/recruitment_application_service.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';
import 'stage_crew_application_screen.dart';

typedef StageCrewApplicationStateLoader =
    Future<RecruitmentApplicationState> Function(String postId);
typedef StageCrewApplicationSubmitter =
    Future<RecruitmentApplicationState> Function({
      required String postId,
      required String message,
    });

class StageCrewDetailScreen extends StatefulWidget {
  const StageCrewDetailScreen({
    required this.recruitment,
    super.key,
    this.loadApplicationState,
    this.submitApplication,
  });

  final StageCrewRecruitment recruitment;
  final StageCrewApplicationStateLoader? loadApplicationState;
  final StageCrewApplicationSubmitter? submitApplication;

  @override
  State<StageCrewDetailScreen> createState() => _StageCrewDetailScreenState();
}

class _StageCrewDetailScreenState extends State<StageCrewDetailScreen> {
  RecruitmentApplicationService? _applicationService;
  late Future<RecruitmentApplicationState> _applicationState;

  @override
  void initState() {
    super.initState();
    if (widget.loadApplicationState == null ||
        widget.submitApplication == null) {
      _applicationService = RecruitmentApplicationService();
    }
    _applicationState = _loadApplicationState();
  }

  @override
  Widget build(BuildContext context) {
    return StageMobilePageFrame(
      child: Scaffold(
        key: const ValueKey('stage-crew-detail-screen'),
        appBar: AppBar(title: const Text('クルー募集詳細')),
        body: ListView(
          padding: const EdgeInsets.all(StageDesignTokens.space16),
          children: [
            _CrewIdentity(recruitment: widget.recruitment),
            const SizedBox(height: StageDesignTokens.space16),
            StageCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recruitment.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: StageDesignTokens.space16),
                  Text(widget.recruitment.body),
                ],
              ),
            ),
            const SizedBox(height: StageDesignTokens.space16),
            _TaxonomyCard(recruitment: widget.recruitment),
            const SizedBox(height: StageDesignTokens.space24),
            _ApplicationAction(
              future: _applicationState,
              onRetry: _retryApplicationState,
              onApply: _openApplication,
            ),
          ],
        ),
      ),
    );
  }

  Future<RecruitmentApplicationState> _loadApplicationState() {
    return widget.loadApplicationState?.call(widget.recruitment.postId) ??
        _applicationService!.fetchMyApplicationState(widget.recruitment.postId);
  }

  void _retryApplicationState() {
    setState(() => _applicationState = _loadApplicationState());
  }

  Future<void> _openApplication() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StageCrewApplicationScreen(
          recruitment: widget.recruitment,
          submitApplication:
              widget.submitApplication ?? _applicationService!.applyToStagePost,
        ),
      ),
    );
    if (!mounted || submitted != true) return;
    setState(() {
      _applicationState = Future.value(
        const RecruitmentApplicationState(
          state: 'pending',
          applicationId: null,
        ),
      );
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('応募を受け付けました')));
  }
}

class _CrewIdentity extends StatelessWidget {
  const _CrewIdentity({required this.recruitment});

  final StageCrewRecruitment recruitment;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: StageDesignTokens.surfaceMuted,
            backgroundImage: recruitment.crewAvatarUrl == null
                ? null
                : NetworkImage(recruitment.crewAvatarUrl!),
            child: recruitment.crewAvatarUrl == null
                ? const Icon(Icons.groups_rounded)
                : null,
          ),
          const SizedBox(width: StageDesignTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recruitment.crewName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: StageDesignTokens.space4),
                const StageTag(
                  '募集中',
                  color: StageDesignTokens.pink,
                  foregroundColor: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaxonomyCard extends StatelessWidget {
  const _TaxonomyCard({required this.recruitment});

  final StageCrewRecruitment recruitment;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ジャンル', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: StageDesignTokens.space8),
          Wrap(
            spacing: StageDesignTokens.space8,
            runSpacing: StageDesignTokens.space8,
            children: recruitment.danceGenreNames
                .map((name) => StageTag(name))
                .toList(growable: false),
          ),
          if (recruitment.areaNames.isNotEmpty) ...[
            const SizedBox(height: StageDesignTokens.space16),
            Text('活動エリア', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: StageDesignTokens.space8),
            Wrap(
              spacing: StageDesignTokens.space8,
              runSpacing: StageDesignTokens.space8,
              children: recruitment.areaNames
                  .map(
                    (name) =>
                        StageTag(name, color: StageDesignTokens.textSecondary),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _ApplicationAction extends StatelessWidget {
  const _ApplicationAction({
    required this.future,
    required this.onRetry,
    required this.onApply,
  });

  final Future<RecruitmentApplicationState> future;
  final VoidCallback onRetry;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RecruitmentApplicationState>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return StageCard(
            color: StageDesignTokens.surfaceMuted,
            child: Column(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: StageDesignTokens.error,
                ),
                const SizedBox(height: StageDesignTokens.space8),
                const Text('応募状況を確認できませんでした'),
                const SizedBox(height: StageDesignTokens.space8),
                OutlinedButton(onPressed: onRetry, child: const Text('再試行')),
              ],
            ),
          );
        }

        final state = snapshot.data?.state ?? 'none';
        if (state == 'none') {
          return FilledButton(
            key: const ValueKey('stage-crew-apply-button'),
            onPressed: onApply,
            child: const Text('この募集に応募する'),
          );
        }
        return StageCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_statusIcon(state), color: _statusColor(state)),
              const SizedBox(width: StageDesignTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusLabel(state),
                      key: ValueKey('stage-application-state-$state'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (state == 'rejected') ...[
                      const SizedBox(height: StageDesignTokens.space4),
                      const Text(
                        'この募集には再応募できません',
                        key: ValueKey('stage-reapplication-unavailable'),
                        style: TextStyle(
                          color: StageDesignTokens.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusLabel(String state) => switch (state) {
    'pending' => '応募済み・確認中',
    'accepted' => '承認済み',
    'rejected' => '見送り',
    'own_group' => '管理中のクルーです',
    'group_member' => '参加中のクルーです',
    'closed' => '募集は終了しました',
    _ => '応募状況を確認してください',
  };

  IconData _statusIcon(String state) => switch (state) {
    'accepted' || 'group_member' => Icons.check_circle_outline_rounded,
    'rejected' || 'closed' => Icons.info_outline_rounded,
    _ => Icons.schedule_rounded,
  };

  Color _statusColor(String state) => switch (state) {
    'accepted' || 'group_member' => StageDesignTokens.success,
    'rejected' || 'closed' => StageDesignTokens.textMuted,
    _ => StageDesignTokens.purple,
  };
}

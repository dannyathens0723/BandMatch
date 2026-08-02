import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/stage_event.dart';
import '../services/stage_event_discovery_service.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';

typedef StageExternalLinkOpener = Future<bool> Function(Uri uri);

class StageEventDetailScreen extends StatefulWidget {
  const StageEventDetailScreen({
    required this.eventId,
    required this.repository,
    super.key,
    this.externalLinkOpener,
  });

  final String eventId;
  final StageEventDiscoveryRepository repository;
  final StageExternalLinkOpener? externalLinkOpener;

  @override
  State<StageEventDetailScreen> createState() => _StageEventDetailScreenState();
}

class _StageEventDetailScreenState extends State<StageEventDetailScreen> {
  late Future<StageEvent?> _event;
  bool _openingExternalLink = false;

  @override
  void initState() {
    super.initState();
    _event = widget.repository.fetchPublishedEvent(widget.eventId);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: StageDesignTokens.charcoal,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: StageDesignTokens.maxContentWidth,
          ),
          child: Scaffold(
            key: const ValueKey('stage-event-detail-screen'),
            appBar: AppBar(title: const Text('イベント詳細')),
            body: FutureBuilder<StageEvent?>(
              future: _event,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    key: ValueKey('stage-event-detail-loading'),
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return _DetailErrorState(onRetry: _retry);
                }
                return _buildDetail(context, snapshot.data!);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, StageEvent event) {
    return ListView(
      padding: const EdgeInsets.all(StageDesignTokens.space16),
      children: [
        StageCard(
          gradient: StageDesignTokens.heroGradient,
          borderColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: StageDesignTokens.space8,
                runSpacing: StageDesignTokens.space8,
                children: [
                  StageStatusBadge(label: _statusLabel(event.eventStatus)),
                  StageTag(
                    _categoryLabel(event.category),
                    color: Colors.white24,
                    foregroundColor: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: StageDesignTokens.space16),
              Text(
                event.title,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: StageDesignTokens.space12),
              Text(
                event.organizerName,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: StageDesignTokens.space16),
        StageCard(
          child: Column(
            children: [
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: '開催日時',
                value: _dateRange(event),
              ),
              const Divider(height: StageDesignTokens.space24),
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: '会場',
                value: event.venueName,
              ),
              if (event.feeSummary != null) ...[
                const Divider(height: StageDesignTokens.space24),
                _DetailRow(
                  icon: Icons.payments_outlined,
                  label: '参加費',
                  value: event.feeSummary!,
                ),
              ],
              if (event.applicationDeadline != null) ...[
                const Divider(height: StageDesignTokens.space24),
                _DetailRow(
                  icon: Icons.schedule_outlined,
                  label: '申込期限',
                  value: _formatDateTime(event.applicationDeadline!),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: StageDesignTokens.space16),
        StageCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('イベントについて', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: StageDesignTokens.space12),
              Text(event.summary),
              if (event.eligibilitySummary != null) ...[
                const SizedBox(height: StageDesignTokens.space16),
                Text('参加条件', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: StageDesignTokens.space8),
                Text(event.eligibilitySummary!),
              ],
            ],
          ),
        ),
        if (event.danceGenreNames.isNotEmpty || event.areaNames.isNotEmpty) ...[
          const SizedBox(height: StageDesignTokens.space16),
          StageCard(
            child: Wrap(
              spacing: StageDesignTokens.space8,
              runSpacing: StageDesignTokens.space8,
              children: [
                ...event.danceGenreNames.map(StageTag.new),
                ...event.areaNames.map(
                  (area) =>
                      StageTag(area, color: StageDesignTokens.surfaceMuted),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: StageDesignTokens.space16),
        _SourceCard(event: event),
        const SizedBox(height: StageDesignTokens.space24),
        StagePrimaryButton(
          label: _openingExternalLink ? '開いています…' : '公式情報・申込ページを開く',
          icon: Icons.open_in_new_rounded,
          onPressed: _openingExternalLink
              ? null
              : () => _confirmAndOpenExternalLink(event),
        ),
        const SizedBox(height: StageDesignTokens.space8),
        Text(
          '外部サイトへ移動します。申込条件と最新情報を主催者ページで確認してください。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  void _retry() {
    final event = widget.repository.fetchPublishedEvent(widget.eventId);
    setState(() {
      _event = event;
    });
  }

  Future<void> _confirmAndOpenExternalLink(StageEvent event) async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('外部サイトを開きますか？'),
        content: const Text('STAGEの外部にある主催者または情報元のページへ移動します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const ValueKey('stage-event-confirm-external-link'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('開く'),
          ),
        ],
      ),
    );
    if (shouldOpen != true || !mounted) return;

    setState(() => _openingExternalLink = true);
    try {
      final opened = await (widget.externalLinkOpener ?? _launchExternal)(
        event.primaryExternalUri,
      );
      if (!opened && mounted) _showOpenFailure();
    } on Object catch (error, stackTrace) {
      debugPrint('STAGE external event link failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) _showOpenFailure();
    } finally {
      if (mounted) setState(() => _openingExternalLink = false);
    }
  }

  Future<bool> _launchExternal(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showOpenFailure() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('外部ページを開けませんでした。時間をおいて再度お試しください。')),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: StageDesignTokens.purple, size: 22),
        const SizedBox(width: StageDesignTokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: StageDesignTokens.space4),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.event});

  final StageEvent event;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      color: StageDesignTokens.surfaceMuted,
      borderColor: StageDesignTokens.surfaceMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                color: StageDesignTokens.success,
              ),
              const SizedBox(width: StageDesignTokens.space8),
              Expanded(
                child: Text(
                  '情報元を確認済み',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: StageDesignTokens.space8),
          Text('主催者: ${event.organizerName}'),
          Text('情報元: ${_sourceTypeLabel(event.sourceType)}'),
          Text('最終確認: ${_formatDate(event.lastVerifiedAt)}'),
          const SizedBox(height: StageDesignTokens.space8),
          SelectableText(
            event.sourceUrl,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(StageDesignTokens.space24),
        child: StageCard(
          key: const ValueKey('stage-event-detail-error'),
          child: Column(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: StageDesignTokens.error,
              ),
              const SizedBox(height: StageDesignTokens.space8),
              const Text('イベント詳細を読み込めませんでした。'),
              const SizedBox(height: StageDesignTokens.space12),
              OutlinedButton(onPressed: onRetry, child: const Text('再試行')),
            ],
          ),
        ),
      ),
    );
  }
}

String _categoryLabel(String category) => switch (category) {
  'competition' => '大会',
  'showcase' => 'ショーケース',
  _ => 'イベント',
};

String _statusLabel(String status) => switch (status) {
  'applications_open' => '募集中',
  'applications_closed' => '募集終了',
  _ => '開催予定',
};

String _sourceTypeLabel(String sourceType) => switch (sourceType) {
  'official_site' => '公式サイト',
  'organizer_submission' => '主催者提供',
  _ => '運営確認済み',
};

String _dateRange(StageEvent event) {
  final start = _formatDateTime(event.startsAt);
  final end = event.endsAt;
  if (end == null) return start;
  return '$start ～ ${_formatDateTime(end)}';
}

String _formatDate(DateTime date) =>
    '${date.year}/${_twoDigits(date.month)}/${_twoDigits(date.day)}';

String _formatDateTime(DateTime date) =>
    '${_formatDate(date)} ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

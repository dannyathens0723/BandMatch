import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/stage_studio.dart';
import '../services/stage_studio_discovery_service.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';

typedef StageStudioExternalLinkOpener = Future<bool> Function(Uri uri);

class StageStudioDetailScreen extends StatefulWidget {
  const StageStudioDetailScreen({
    required this.studioId,
    required this.repository,
    super.key,
    this.externalLinkOpener,
  });

  final String studioId;
  final StageStudioDiscoveryRepository repository;
  final StageStudioExternalLinkOpener? externalLinkOpener;

  @override
  State<StageStudioDetailScreen> createState() =>
      _StageStudioDetailScreenState();
}

class _StageStudioDetailScreenState extends State<StageStudioDetailScreen> {
  late Future<StageStudio?> _studio;
  bool _openingExternalLink = false;

  @override
  void initState() {
    super.initState();
    _studio = widget.repository.fetchPublishedStudio(widget.studioId);
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
            key: const ValueKey('stage-studio-detail-screen'),
            appBar: AppBar(title: const Text('スタジオ詳細')),
            body: FutureBuilder<StageStudio?>(
              future: _studio,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    key: ValueKey('stage-studio-detail-loading'),
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return _StudioDetailErrorState(onRetry: _retry);
                }
                return _buildDetail(context, snapshot.data!);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, StageStudio studio) {
    final externalUri = studio.primaryExternalUri;
    return ListView(
      padding: const EdgeInsets.all(StageDesignTokens.space16),
      children: [
        StageCard(
          gradient: StageDesignTokens.heroGradient,
          borderColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StageStatusBadge(
                label: '運営確認済み',
                color: StageDesignTokens.success,
              ),
              const SizedBox(height: StageDesignTokens.space12),
              Text(
                studio.name,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: StageDesignTokens.space8),
              Text(
                _accessSummary(studio),
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
                icon: Icons.location_on_outlined,
                label: '所在地',
                value: studio.addressDisplay,
              ),
              if (studio.accessNote != null) ...[
                const Divider(height: StageDesignTokens.space24),
                _DetailRow(
                  icon: Icons.directions_walk_outlined,
                  label: 'アクセス',
                  value: studio.accessNote!,
                ),
              ],
              if (studio.openingHoursSummary != null) ...[
                const Divider(height: StageDesignTokens.space24),
                _DetailRow(
                  icon: Icons.schedule_outlined,
                  label: '営業時間',
                  value: studio.openingHoursSummary!,
                ),
              ],
              if (studio.minimumHourlyPriceYen != null) ...[
                const Divider(height: StageDesignTokens.space24),
                _DetailRow(
                  icon: Icons.payments_outlined,
                  label: '参考料金',
                  value: '¥${_number(studio.minimumHourlyPriceYen!)}/時間〜',
                ),
              ],
            ],
          ),
        ),
        if (studio.facilityNames.isNotEmpty) ...[
          const SizedBox(height: StageDesignTokens.space16),
          StageCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('設備', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: StageDesignTokens.space12),
                Wrap(
                  spacing: StageDesignTokens.space8,
                  runSpacing: StageDesignTokens.space8,
                  children: studio.facilityNames.map(StageTag.new).toList(),
                ),
              ],
            ),
          ),
        ],
        if (studio.rooms.isNotEmpty) ...[
          const SizedBox(height: StageDesignTokens.space16),
          Text('ルーム', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: StageDesignTokens.space8),
          ...studio.rooms.map(
            (room) => Padding(
              padding: const EdgeInsets.only(bottom: StageDesignTokens.space12),
              child: _RoomCard(room: room),
            ),
          ),
        ],
        if (studio.reviewSummary != null) ...[
          const SizedBox(height: StageDesignTokens.space4),
          StageCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('利用情報', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: StageDesignTokens.space8),
                if (studio.rating != null)
                  Text(
                    '評価 ${studio.rating!.toStringAsFixed(1)} / 5.0'
                    '（${studio.ratingCount}件）',
                  ),
                const SizedBox(height: StageDesignTokens.space4),
                Text(studio.reviewSummary!),
              ],
            ),
          ),
        ],
        const SizedBox(height: StageDesignTokens.space16),
        _StudioSourceCard(studio: studio),
        const SizedBox(height: StageDesignTokens.space24),
        StagePrimaryButton(
          key: const ValueKey('stage-studio-external-action'),
          label: externalUri == null
              ? '予約ページを確認できません'
              : _openingExternalLink
              ? '開いています…'
              : '外部予約ページを開く',
          icon: Icons.open_in_new_rounded,
          onPressed: externalUri == null || _openingExternalLink
              ? null
              : () => _confirmAndOpenExternalLink(externalUri),
        ),
        const SizedBox(height: StageDesignTokens.space8),
        Text(
          externalUri == null
              ? '有効なHTTPS予約ページが確認できません。掲載元の情報をご確認ください。'
              : '外部サイトへ移動します。料金・空室・予約条件は移動先で確認してください。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  void _retry() {
    final studio = widget.repository.fetchPublishedStudio(widget.studioId);
    setState(() {
      _studio = studio;
    });
  }

  Future<void> _confirmAndOpenExternalLink(Uri uri) async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('外部予約ページを開きますか？'),
        content: const Text('STAGEの外部にあるスタジオの予約・公式ページへ移動します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const ValueKey('stage-studio-confirm-external-link'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('開く'),
          ),
        ],
      ),
    );
    if (shouldOpen != true || !mounted) return;

    setState(() => _openingExternalLink = true);
    try {
      final opened = await (widget.externalLinkOpener ?? _launchExternal)(uri);
      if (!opened && mounted) _showOpenFailure();
    } on Object catch (error, stackTrace) {
      debugPrint('STAGE external studio link failed: $error');
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

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room});

  final StageStudioRoom room;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(room.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: StageDesignTokens.space8),
          Wrap(
            spacing: StageDesignTokens.space12,
            runSpacing: StageDesignTokens.space8,
            children: [
              if (room.hourlyPriceYen != null)
                Text('¥${_number(room.hourlyPriceYen!)}/時間'),
              if (room.capacity != null) Text('〜${room.capacity}名'),
              if (room.sizeSqm != null) Text('${_decimal(room.sizeSqm!)}㎡'),
            ],
          ),
          if (room.facilityNames.isNotEmpty) ...[
            const SizedBox(height: StageDesignTokens.space8),
            Wrap(
              spacing: StageDesignTokens.space8,
              runSpacing: StageDesignTokens.space8,
              children: room.facilityNames.map(StageTag.new).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StudioSourceCard extends StatelessWidget {
  const _StudioSourceCard({required this.studio});

  final StageStudio studio;

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
                  '公開情報を確認済み',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: StageDesignTokens.space8),
          Text('情報元: ${studio.sourceLabel}'),
          Text('最終確認: ${_date(studio.lastVerifiedAt)}'),
          const SizedBox(height: StageDesignTokens.space8),
          SelectableText(
            studio.sourceUrl,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StudioDetailErrorState extends StatelessWidget {
  const _StudioDetailErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(StageDesignTokens.space24),
        child: StageCard(
          key: const ValueKey('stage-studio-detail-error'),
          child: Column(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: StageDesignTokens.error,
              ),
              const SizedBox(height: StageDesignTokens.space8),
              const Text('スタジオ詳細を読み込めませんでした。'),
              const SizedBox(height: StageDesignTokens.space12),
              OutlinedButton(onPressed: onRetry, child: const Text('再試行')),
            ],
          ),
        ),
      ),
    );
  }
}

String _accessSummary(StageStudio studio) {
  final station = studio.nearestStationName;
  final walk = studio.walkingMinutes;
  if (station != null && walk != null) return '$station 徒歩$walk分';
  return station ?? studio.areaName ?? studio.addressDisplay;
}

String _number(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

String _decimal(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

String _date(DateTime date) =>
    '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

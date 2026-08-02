import 'package:flutter/material.dart';

import '../models/stage_event.dart';
import '../services/stage_event_discovery_service.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';
import 'stage_event_detail_screen.dart';

typedef StageEventDetailBuilder =
    Widget Function(
      BuildContext context,
      StageEvent event,
      StageEventDiscoveryRepository repository,
    );

class StageEventDiscoveryScreen extends StatefulWidget {
  const StageEventDiscoveryScreen({
    super.key,
    this.repository,
    this.detailBuilder,
  });

  final StageEventDiscoveryRepository? repository;
  final StageEventDetailBuilder? detailBuilder;

  @override
  State<StageEventDiscoveryScreen> createState() =>
      _StageEventDiscoveryScreenState();
}

class _StageEventDiscoveryScreenState extends State<StageEventDiscoveryScreen> {
  late final StageEventDiscoveryRepository _repository;
  late Future<List<StageEvent>> _events;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? StageEventDiscoveryService();
    _events = _repository.fetchPublishedEvents();
  }

  @override
  Widget build(BuildContext context) {
    return StagePageContent(
      key: const PageStorageKey('stage-auth-stage'),
      children: [
        const _TrustNotice(),
        const StageSectionHeader(title: 'イベント・大会'),
        FutureBuilder<List<StageEvent>>(
          future: _events,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _EventLoadingState();
            }
            if (snapshot.hasError) {
              return _EventErrorState(onRetry: _retry);
            }

            final events = snapshot.data ?? const [];
            if (events.isEmpty) return const _EventEmptyState();

            final categories =
                events
                    .map((event) => event.category)
                    .toSet()
                    .toList(growable: false)
                  ..sort();
            final visibleEvents = events
                .where(
                  (event) =>
                      _selectedCategory == null ||
                      event.category == _selectedCategory,
                )
                .toList(growable: false);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CategoryFilters(
                  categories: categories,
                  selectedCategory: _selectedCategory,
                  onSelected: (category) {
                    setState(() => _selectedCategory = category);
                  },
                ),
                const SizedBox(height: StageDesignTokens.space16),
                ...visibleEvents.map(
                  (event) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: StageDesignTokens.space12,
                    ),
                    child: _EventCard(
                      event: event,
                      onTap: () => _openDetail(event),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const StageSectionHeader(title: 'レッスン・ワークショップ'),
        const _LessonsDeferredState(),
      ],
    );
  }

  void _retry() {
    final events = _repository.fetchPublishedEvents();
    setState(() {
      _events = events;
    });
  }

  Future<void> _openDetail(StageEvent event) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            widget.detailBuilder?.call(context, event, _repository) ??
            StageEventDetailScreen(
              eventId: event.eventId,
              repository: _repository,
            ),
      ),
    );
  }
}

class _TrustNotice extends StatelessWidget {
  const _TrustNotice();

  @override
  Widget build(BuildContext context) {
    return StageCard(
      key: const ValueKey('stage-event-trust-notice'),
      color: StageDesignTokens.surfaceMuted,
      borderColor: StageDesignTokens.surfaceMuted,
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: StageDesignTokens.purple),
          SizedBox(width: StageDesignTokens.space12),
          Expanded(child: Text('主催者と情報元を確認した、公開中のDanceイベントを掲載しています。')),
        ],
      ),
    );
  }
}

class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('すべて'),
            selected: selectedCategory == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final category in categories) ...[
            const SizedBox(width: StageDesignTokens.space8),
            ChoiceChip(
              label: Text(_categoryLabel(category)),
              selected: selectedCategory == category,
              onSelected: (_) => onSelected(category),
            ),
          ],
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});

  final StageEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      key: ValueKey('stage-event-card-${event.eventId}'),
      onTap: onTap,
      showShadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _EventIcon(),
              const SizedBox(width: StageDesignTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: StageDesignTokens.space8,
                      runSpacing: StageDesignTokens.space4,
                      children: [
                        StageStatusBadge(
                          label: _statusLabel(event.eventStatus),
                          color: _statusColor(event.eventStatus),
                        ),
                        StageTag(_categoryLabel(event.category)),
                      ],
                    ),
                    const SizedBox(height: StageDesignTokens.space8),
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: StageDesignTokens.space12),
          _EventMetadata(
            icon: Icons.calendar_today_outlined,
            label: _formatDateTime(event.startsAt),
          ),
          const SizedBox(height: StageDesignTokens.space8),
          _EventMetadata(
            icon: Icons.location_on_outlined,
            label: event.venueName,
          ),
          if (event.feeSummary != null) ...[
            const SizedBox(height: StageDesignTokens.space8),
            _EventMetadata(
              icon: Icons.payments_outlined,
              label: event.feeSummary!,
            ),
          ],
          if (event.danceGenreNames.isNotEmpty ||
              event.areaNames.isNotEmpty) ...[
            const SizedBox(height: StageDesignTokens.space12),
            Wrap(
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
          ],
          const SizedBox(height: StageDesignTokens.space12),
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 16,
                color: StageDesignTokens.success,
              ),
              const SizedBox(width: StageDesignTokens.space4),
              Expanded(
                child: Text(
                  '${event.organizerName} ・ ${_formatDate(event.lastVerifiedAt)}確認',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: StageDesignTokens.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventIcon extends StatelessWidget {
  const _EventIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 58,
      decoration: BoxDecoration(
        color: StageDesignTokens.charcoal,
        borderRadius: BorderRadius.circular(StageDesignTokens.radius12),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.local_activity_outlined, color: Colors.white),
    );
  }
}

class _EventMetadata extends StatelessWidget {
  const _EventMetadata({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: StageDesignTokens.textSecondary),
        const SizedBox(width: StageDesignTokens.space8),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _EventLoadingState extends StatelessWidget {
  const _EventLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: ValueKey('stage-event-loading'),
      padding: EdgeInsets.symmetric(vertical: StageDesignTokens.space32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EventEmptyState extends StatelessWidget {
  const _EventEmptyState();

  @override
  Widget build(BuildContext context) {
    return const StageEmptyState(
      key: ValueKey('stage-event-empty'),
      icon: Icons.event_busy_outlined,
      title: '公開中のイベントはまだありません',
      message: '確認済みのイベント・大会が公開されると、ここに表示されます。',
    );
  }
}

class _EventErrorState extends StatelessWidget {
  const _EventErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      key: const ValueKey('stage-event-error'),
      color: StageDesignTokens.surfaceMuted,
      borderColor: StageDesignTokens.surfaceMuted,
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: StageDesignTokens.error,
            size: 32,
          ),
          const SizedBox(height: StageDesignTokens.space8),
          Text(
            'イベント情報を読み込めませんでした',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StageDesignTokens.space4),
          const Text('時間をおいて再度お試しください。'),
          const SizedBox(height: StageDesignTokens.space12),
          OutlinedButton(
            key: const ValueKey('stage-event-retry'),
            onPressed: onRetry,
            child: const Text('再試行'),
          ),
        ],
      ),
    );
  }
}

class _LessonsDeferredState extends StatelessWidget {
  const _LessonsDeferredState();

  @override
  Widget build(BuildContext context) {
    return const StageCard(
      key: ValueKey('stage-lessons-deferred'),
      color: StageDesignTokens.surfaceMuted,
      borderColor: StageDesignTokens.surfaceMuted,
      child: Row(
        children: [
          Icon(Icons.school_outlined, color: StageDesignTokens.purple),
          SizedBox(width: StageDesignTokens.space12),
          Expanded(child: Text('レッスン・ワークショップ情報は、講師確認の仕組みとあわせて順次公開します。')),
        ],
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

Color _statusColor(String status) => switch (status) {
  'applications_open' => StageDesignTokens.success,
  'applications_closed' => StageDesignTokens.textMuted,
  _ => StageDesignTokens.purple,
};

String _formatDate(DateTime date) =>
    '${date.year}/${_twoDigits(date.month)}/${_twoDigits(date.day)}';

String _formatDateTime(DateTime date) =>
    '${_formatDate(date)} ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

import 'package:flutter/material.dart';

import '../models/stage_studio.dart';
import '../services/stage_studio_discovery_service.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';
import 'stage_studio_detail_screen.dart';

typedef StageStudioDetailBuilder =
    Widget Function(
      BuildContext context,
      StageStudio studio,
      StageStudioDiscoveryRepository repository,
    );

class StageStudioDiscoveryScreen extends StatefulWidget {
  const StageStudioDiscoveryScreen({
    super.key,
    this.repository,
    this.detailBuilder,
  });

  final StageStudioDiscoveryRepository? repository;
  final StageStudioDetailBuilder? detailBuilder;

  @override
  State<StageStudioDiscoveryScreen> createState() =>
      _StageStudioDiscoveryScreenState();
}

class _StageStudioDiscoveryScreenState
    extends State<StageStudioDiscoveryScreen> {
  late final StageStudioDiscoveryRepository _repository;
  late Future<List<StageStudio>> _studios;
  final _searchController = TextEditingController();
  String? _selectedArea;
  String? _selectedFacility;
  int? _maximumHourlyPriceYen;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? StageStudioDiscoveryService();
    _studios = _repository.fetchPublishedStudios();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StagePageContent(
      key: const PageStorageKey('stage-auth-studio'),
      children: [
        const _StudioTrustNotice(),
        Text('スタジオを探す', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: StageDesignTokens.space12),
        TextField(
          key: const ValueKey('stage-studio-search'),
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'スタジオ名・駅名で検索',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: StageDesignTokens.space16),
        FutureBuilder<List<StageStudio>>(
          future: _studios,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _StudioLoadingState();
            }
            if (snapshot.hasError) {
              return _StudioErrorState(onRetry: _retry);
            }

            final studios = snapshot.data ?? const [];
            if (studios.isEmpty) return const _StudioEmptyState();

            final areas = _distinctSorted(
              studios.map((studio) => studio.areaName),
            );
            final facilities = _distinctSorted(
              studios.expand((studio) => studio.facilityNames),
            );
            final visibleStudios = studios.where(_matchesFilters).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StudioFilters(
                  areas: areas,
                  facilities: facilities,
                  selectedArea: _selectedArea,
                  selectedFacility: _selectedFacility,
                  maximumHourlyPriceYen: _maximumHourlyPriceYen,
                  onAreaSelected: (value) {
                    setState(() => _selectedArea = value);
                  },
                  onFacilitySelected: (value) {
                    setState(() => _selectedFacility = value);
                  },
                  onPriceSelected: (value) {
                    setState(() => _maximumHourlyPriceYen = value);
                  },
                ),
                const SizedBox(height: StageDesignTokens.space16),
                const _MapModeNotice(),
                const SizedBox(height: StageDesignTokens.space16),
                Padding(
                  padding: const EdgeInsets.only(
                    top: StageDesignTokens.space8,
                    bottom: StageDesignTokens.space12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedArea == null
                              ? 'スタジオ一覧'
                              : '$_selectedAreaのスタジオ',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        '${visibleStudios.length}件',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (visibleStudios.isEmpty)
                  const _FilteredEmptyState()
                else
                  ...visibleStudios.map(
                    (studio) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: StageDesignTokens.space12,
                      ),
                      child: _StudioCard(
                        studio: studio,
                        onTap: () => _openDetail(studio),
                      ),
                    ),
                  ),
                const SizedBox(height: StageDesignTokens.space4),
                _RecommendationNotice(onTap: _showRecommendationNotice),
              ],
            );
          },
        ),
      ],
    );
  }

  bool _matchesFilters(StageStudio studio) {
    final price = studio.minimumHourlyPriceYen;
    return studio.matchesKeyword(_searchController.text) &&
        (_selectedArea == null || studio.areaName == _selectedArea) &&
        (_selectedFacility == null ||
            studio.facilityNames.contains(_selectedFacility)) &&
        (_maximumHourlyPriceYen == null ||
            (price != null && price <= _maximumHourlyPriceYen!));
  }

  void _retry() {
    final studios = _repository.fetchPublishedStudios();
    setState(() {
      _studios = studios;
    });
  }

  Future<void> _openDetail(StageStudio studio) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            widget.detailBuilder?.call(context, studio, _repository) ??
            StageStudioDetailScreen(
              studioId: studio.studioId,
              repository: _repository,
            ),
      ),
    );
  }

  void _showRecommendationNotice() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('クルー向けスタジオ推薦は現在準備中です')));
  }
}

class _StudioFilters extends StatelessWidget {
  const _StudioFilters({
    required this.areas,
    required this.facilities,
    required this.selectedArea,
    required this.selectedFacility,
    required this.maximumHourlyPriceYen,
    required this.onAreaSelected,
    required this.onFacilitySelected,
    required this.onPriceSelected,
  });

  final List<String> areas;
  final List<String> facilities;
  final String? selectedArea;
  final String? selectedFacility;
  final int? maximumHourlyPriceYen;
  final ValueChanged<String?> onAreaSelected;
  final ValueChanged<String?> onFacilitySelected;
  final ValueChanged<int?> onPriceSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterRow<String>(
          label: 'エリア',
          values: areas,
          selectedValue: selectedArea,
          labelFor: (value) => value,
          onSelected: onAreaSelected,
        ),
        if (facilities.isNotEmpty) ...[
          const SizedBox(height: StageDesignTokens.space8),
          _FilterRow<String>(
            label: '設備',
            values: facilities,
            selectedValue: selectedFacility,
            labelFor: (value) => value,
            onSelected: onFacilitySelected,
          ),
        ],
        const SizedBox(height: StageDesignTokens.space8),
        _FilterRow<int>(
          label: '料金',
          values: const [2000, 3000, 5000],
          selectedValue: maximumHourlyPriceYen,
          labelFor: (value) => '¥${_number(value)}/h以下',
          onSelected: onPriceSelected,
        ),
      ],
    );
  }
}

class _FilterRow<T> extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.values,
    required this.selectedValue,
    required this.labelFor,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final T? selectedValue;
  final String Function(T value) labelFor;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: StageDesignTokens.space8),
          ChoiceChip(
            label: const Text('すべて'),
            selected: selectedValue == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final value in values) ...[
            const SizedBox(width: StageDesignTokens.space8),
            ChoiceChip(
              label: Text(labelFor(value)),
              selected: selectedValue == value,
              onSelected: (_) => onSelected(value),
            ),
          ],
        ],
      ),
    );
  }
}

class _StudioCard extends StatelessWidget {
  const _StudioCard({required this.studio, required this.onTap});

  final StageStudio studio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      key: ValueKey('stage-studio-card-${studio.studioId}'),
      onTap: onTap,
      showShadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: StageDesignTokens.brandGradient,
                  borderRadius: BorderRadius.circular(
                    StageDesignTokens.radius12,
                  ),
                ),
                child: const Icon(
                  Icons.surround_sound_outlined,
                  color: Colors.white,
                ),
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
                    const SizedBox(height: StageDesignTokens.space4),
                    Text(_accessSummary(studio)),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: StageDesignTokens.purple,
              ),
            ],
          ),
          const SizedBox(height: StageDesignTokens.space12),
          Wrap(
            spacing: StageDesignTokens.space12,
            runSpacing: StageDesignTokens.space8,
            children: [
              _Metric(
                icon: Icons.payments_outlined,
                label: studio.minimumHourlyPriceYen == null
                    ? '料金は詳細で確認'
                    : '¥${_number(studio.minimumHourlyPriceYen!)}/h〜',
              ),
              if (studio.maxCapacity != null)
                _Metric(
                  icon: Icons.groups_outlined,
                  label: '〜${studio.maxCapacity}名',
                ),
              if (studio.largestRoomSizeSqm != null)
                _Metric(
                  icon: Icons.square_foot_outlined,
                  label: '${_decimal(studio.largestRoomSizeSqm!)}㎡',
                ),
            ],
          ),
          if (studio.facilityNames.isNotEmpty) ...[
            const SizedBox(height: StageDesignTokens.space12),
            Wrap(
              spacing: StageDesignTokens.space8,
              runSpacing: StageDesignTokens.space8,
              children: studio.facilityNames.take(5).map(StageTag.new).toList(),
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
                  '${studio.sourceLabel} ・ ${_date(studio.lastVerifiedAt)}確認',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: StageDesignTokens.textSecondary),
        const SizedBox(width: StageDesignTokens.space4),
        Text(label),
      ],
    );
  }
}

class _StudioTrustNotice extends StatelessWidget {
  const _StudioTrustNotice();

  @override
  Widget build(BuildContext context) {
    return const StageCard(
      key: ValueKey('stage-studio-trust-notice'),
      color: StageDesignTokens.surfaceMuted,
      borderColor: StageDesignTokens.surfaceMuted,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: StageDesignTokens.purple),
          SizedBox(width: StageDesignTokens.space12),
          Expanded(child: Text('運営が公開情報を確認した、営業中のダンススタジオを掲載しています。')),
        ],
      ),
    );
  }
}

class _MapModeNotice extends StatelessWidget {
  const _MapModeNotice();

  @override
  Widget build(BuildContext context) {
    return const StageCard(
      key: ValueKey('stage-studio-map-deferred'),
      color: StageDesignTokens.charcoal,
      borderColor: StageDesignTokens.charcoal,
      child: Row(
        children: [
          Icon(Icons.map_outlined, color: Colors.white),
          SizedBox(width: StageDesignTokens.space12),
          Expanded(
            child: Text(
              '現在はエリア・駅名・条件からリストで検索できます。地図表示は位置データの整備後に対応します。',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationNotice extends StatelessWidget {
  const _RecommendationNotice({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      gradient: StageDesignTokens.heroGradient,
      borderColor: Colors.transparent,
      onTap: onTap,
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_outlined, color: Colors.white),
          SizedBox(width: StageDesignTokens.space12),
          Expanded(
            child: Text(
              'クルーのみんなに合うスタジオを探す',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

class _StudioLoadingState extends StatelessWidget {
  const _StudioLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: ValueKey('stage-studio-loading'),
      padding: EdgeInsets.symmetric(vertical: StageDesignTokens.space32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _StudioEmptyState extends StatelessWidget {
  const _StudioEmptyState();

  @override
  Widget build(BuildContext context) {
    return const StageEmptyState(
      key: ValueKey('stage-studio-empty'),
      icon: Icons.meeting_room_outlined,
      title: '公開中のスタジオはまだありません',
      message: '運営による確認が完了したスタジオが公開されると、ここに表示されます。',
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState();

  @override
  Widget build(BuildContext context) {
    return const StageEmptyState(
      key: ValueKey('stage-studio-filtered-empty'),
      icon: Icons.search_off_rounded,
      title: '条件に合うスタジオが見つかりません',
      message: '検索語や絞り込み条件を変更してお試しください。',
    );
  }
}

class _StudioErrorState extends StatelessWidget {
  const _StudioErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      key: const ValueKey('stage-studio-error'),
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
            'スタジオ情報を読み込めませんでした',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StageDesignTokens.space4),
          const Text('時間をおいて再度お試しください。'),
          const SizedBox(height: StageDesignTokens.space12),
          OutlinedButton(
            key: const ValueKey('stage-studio-retry'),
            onPressed: onRetry,
            child: const Text('再試行'),
          ),
        ],
      ),
    );
  }
}

List<String> _distinctSorted(Iterable<String?> values) {
  final result = values
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();
  result.sort();
  return result;
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

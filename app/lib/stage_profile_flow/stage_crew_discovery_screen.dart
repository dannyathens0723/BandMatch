import 'dart:async';

import 'package:flutter/material.dart';

import '../models/stage_crew_recruitment.dart';
import '../models/stage_my_crew.dart';
import '../services/stage_crew_discovery_service.dart';
import '../services/stage_crew_management_service.dart';
import '../services/stage_my_crew_service.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';
import 'stage_crew_detail_screen.dart';
import 'stage_crew_home_screen.dart';
import 'stage_crew_management_screens.dart';
import 'stage_my_crew_overview.dart';

typedef StageCrewDetailBuilder =
    Widget Function(BuildContext context, StageCrewRecruitment recruitment);

class StageCrewDiscoveryController extends ChangeNotifier {
  bool get showingMyCrew => _showingMyCrew;

  bool _showingMyCrew = false;

  void showDiscovery() => _setShowingMyCrew(false);

  void showMyCrew() => _setShowingMyCrew(true);

  void _setShowingMyCrew(bool value) {
    if (_showingMyCrew == value) return;
    _showingMyCrew = value;
    notifyListeners();
  }
}

class StageCrewDiscoveryScreen extends StatefulWidget {
  const StageCrewDiscoveryScreen({
    super.key,
    this.repository,
    this.detailBuilder,
    this.myCrewRepository,
    this.myCrewDetailBuilder,
    this.applicationDetailBuilder,
    this.managementRepository,
    this.controller,
  });

  final StageCrewDiscoveryRepository? repository;
  final StageCrewDetailBuilder? detailBuilder;
  final StageMyCrewRepository? myCrewRepository;
  final StageMyCrewDetailBuilder? myCrewDetailBuilder;
  final StageMyCrewApplicationDetailBuilder? applicationDetailBuilder;
  final StageCrewManagementRepository? managementRepository;
  final StageCrewDiscoveryController? controller;

  @override
  State<StageCrewDiscoveryScreen> createState() =>
      _StageCrewDiscoveryScreenState();
}

class _StageCrewDiscoveryScreenState extends State<StageCrewDiscoveryScreen> {
  final _searchController = TextEditingController();
  late final StageCrewDiscoveryRepository _repository;
  StageMyCrewRepository? _myCrewRepository;
  late Future<List<StageCrewRecruitment>> _recruitments;
  Future<StageMyCrewOverview>? _myCrewOverview;
  StageMyCrewOverview? _lastMyCrewOverview;
  StageCrewManagementRepository? _managementRepository;
  String? _selectedGenre;
  bool _showingMyCrew = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? StageCrewDiscoveryService();
    _recruitments = _repository.fetchOpenRecruitments();
    _showingMyCrew = widget.controller?.showingMyCrew ?? false;
    if (_showingMyCrew) _myCrewOverview = _loadMyCrewOverview();
    widget.controller?.addListener(_syncController);
  }

  @override
  void didUpdateWidget(covariant StageCrewDiscoveryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller?.removeListener(_syncController);
    widget.controller?.addListener(_syncController);
    _syncController();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_syncController);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StagePageContent(
      key: const PageStorageKey('stage-auth-crew'),
      children: [
        _DiscoverySegments(
          showingMyCrew: _showingMyCrew,
          onFind: _showDiscovery,
          onMyCrew: _showMyCrew,
        ),
        const SizedBox(height: StageDesignTokens.space16),
        if (!_showingMyCrew) ...[
          TextField(
            key: const ValueKey('stage-crew-search-field'),
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'ジャンル・エリア・クルー名で検索',
              prefixIcon: Icon(Icons.search_rounded),
              filled: true,
              fillColor: StageDesignTokens.surface,
            ),
          ),
          const SizedBox(height: StageDesignTokens.space16),
          FutureBuilder<List<StageCrewRecruitment>>(
            future: _recruitments,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _CrewLoadingState();
              }
              if (snapshot.hasError) {
                return _CrewErrorState(onRetry: _retry);
              }

              final recruitments = snapshot.data ?? const [];
              if (recruitments.isEmpty) {
                return const _CrewEmptyState();
              }

              final genres =
                  recruitments
                      .expand((item) => item.danceGenreNames)
                      .toSet()
                      .toList(growable: false)
                    ..sort();
              final visibleRecruitments = recruitments
                  .where(
                    (item) =>
                        item.matches(_searchController.text, _selectedGenre),
                  )
                  .toList(growable: false);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GenreFilters(
                    genres: genres,
                    selectedGenre: _selectedGenre,
                    onSelected: (genre) {
                      setState(() => _selectedGenre = genre);
                    },
                  ),
                  const SizedBox(height: StageDesignTokens.space16),
                  if (visibleRecruitments.isEmpty)
                    const _FilteredEmptyState()
                  else
                    ...visibleRecruitments.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: StageDesignTokens.space12,
                        ),
                        child: _CrewRecruitmentCard(
                          recruitment: item,
                          onTap: () => _openDetail(item),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ] else
          StageMyCrewOverviewPanel(
            future: _myCrewOverview!,
            onRetry: _retryMyCrew,
            onFindCrews: _showDiscovery,
            onOpenCrew: _openMyCrewDetail,
            onOpenApplication: _openApplicationDetail,
            onCreateCrew: _createCrew,
          ),
      ],
    );
  }

  void _retry() {
    setState(() {
      _recruitments = _repository.fetchOpenRecruitments();
    });
  }

  Future<void> _openDetail(StageCrewRecruitment recruitment) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            widget.detailBuilder?.call(context, recruitment) ??
            StageCrewDetailScreen(recruitment: recruitment),
      ),
    );
  }

  void _showDiscovery() {
    final controller = widget.controller;
    if (controller != null) {
      controller.showDiscovery();
      return;
    }
    _applyShowingMyCrew(false);
  }

  void _showMyCrew() {
    final controller = widget.controller;
    if (controller != null) {
      controller.showMyCrew();
      return;
    }
    _applyShowingMyCrew(true);
  }

  void _syncController() {
    if (!mounted) return;
    _applyShowingMyCrew(widget.controller?.showingMyCrew ?? false);
  }

  void _applyShowingMyCrew(bool value) {
    if (_showingMyCrew == value) return;
    final overview = value ? _loadMyCrewOverview() : null;
    setState(() {
      _showingMyCrew = value;
      if (overview != null) _myCrewOverview = overview;
    });
  }

  void _retryMyCrew() {
    final overview = _loadMyCrewOverview();
    setState(() {
      _myCrewOverview = overview;
    });
  }

  Future<void> _openMyCrewDetail(StageMyCrew crew) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            widget.myCrewDetailBuilder?.call(context, crew) ??
            StageCrewHomeScreen(
              initialCrew: crew,
              availableCrews: _lastMyCrewOverview?.crews ?? [crew],
            ),
      ),
    );
    _refreshAll();
  }

  Future<void> _createCrew() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            StageCrewEditorScreen(repository: _managementRepositoryInstance),
      ),
    );
    if (changed == true) _refreshAll();
  }

  StageCrewManagementRepository get _managementRepositoryInstance =>
      _managementRepository ??=
          widget.managementRepository ?? StageCrewManagementService();

  void _refreshAll() {
    if (!mounted) return;
    setState(() {
      _myCrewOverview = _loadMyCrewOverview();
      _recruitments = _repository.fetchOpenRecruitments();
    });
  }

  Future<void> _openApplicationDetail(
    StageMyCrewApplication application,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            widget.applicationDetailBuilder?.call(context, application) ??
            StageMyCrewApplicationDetailScreen(application: application),
      ),
    );
  }

  StageMyCrewRepository get _myCrewRepositoryInstance =>
      _myCrewRepository ??= widget.myCrewRepository ?? StageMyCrewService();

  Future<StageMyCrewOverview> _loadMyCrewOverview() {
    final completer = Completer<StageMyCrewOverview>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        completer.complete(
          await _myCrewRepositoryInstance.fetchMyCrewOverview().then((value) {
            _lastMyCrewOverview = value;
            return value;
          }),
        );
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

class _DiscoverySegments extends StatelessWidget {
  const _DiscoverySegments({
    required this.showingMyCrew,
    required this.onFind,
    required this.onMyCrew,
  });

  final bool showingMyCrew;
  final VoidCallback onFind;
  final VoidCallback onMyCrew;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: showingMyCrew
              ? OutlinedButton(
                  key: const ValueKey('stage-crew-find-segment'),
                  onPressed: onFind,
                  child: const Text('さがす'),
                )
              : FilledButton(
                  key: const ValueKey('stage-crew-find-segment'),
                  style: FilledButton.styleFrom(
                    backgroundColor: StageDesignTokens.charcoal,
                  ),
                  onPressed: onFind,
                  child: const Text('さがす'),
                ),
        ),
        const SizedBox(width: StageDesignTokens.space8),
        Expanded(
          child: showingMyCrew
              ? FilledButton(
                  key: const ValueKey('stage-crew-mine-segment'),
                  style: FilledButton.styleFrom(
                    backgroundColor: StageDesignTokens.charcoal,
                  ),
                  onPressed: onMyCrew,
                  child: const Text('マイクルー'),
                )
              : OutlinedButton(
                  key: const ValueKey('stage-crew-mine-segment'),
                  onPressed: onMyCrew,
                  child: const Text('マイクルー'),
                ),
        ),
      ],
    );
  }
}

class _GenreFilters extends StatelessWidget {
  const _GenreFilters({
    required this.genres,
    required this.selectedGenre,
    required this.onSelected,
  });

  final List<String> genres;
  final String? selectedGenre;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('すべて'),
            selected: selectedGenre == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final genre in genres) ...[
            const SizedBox(width: StageDesignTokens.space8),
            ChoiceChip(
              label: Text(genre),
              selected: selectedGenre == genre,
              onSelected: (_) => onSelected(genre),
            ),
          ],
        ],
      ),
    );
  }
}

class _CrewRecruitmentCard extends StatelessWidget {
  const _CrewRecruitmentCard({required this.recruitment, required this.onTap});

  final StageCrewRecruitment recruitment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('stage-crew-card-${recruitment.postId}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(StageDesignTokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StageTag(
                '募集中',
                color: StageDesignTokens.pink,
                foregroundColor: Colors.white,
              ),
              const SizedBox(height: StageDesignTokens.space8),
              Text(
                recruitment.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: StageDesignTokens.space8),
              Text(
                recruitment.crewName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: StageDesignTokens.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: StageDesignTokens.space12),
              _MetadataWrap(
                genres: recruitment.danceGenreNames,
                areas: recruitment.areaNames,
              ),
              const SizedBox(height: StageDesignTokens.space12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Text(
                    '詳細を見る',
                    style: TextStyle(
                      color: StageDesignTokens.purple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: StageDesignTokens.space4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: StageDesignTokens.purple,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetadataWrap extends StatelessWidget {
  const _MetadataWrap({required this.genres, required this.areas});

  final List<String> genres;
  final List<String> areas;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: StageDesignTokens.space8,
      runSpacing: StageDesignTokens.space8,
      children: [
        ...genres.map((genre) => StageTag(genre)),
        ...areas.map(
          (area) => StageTag(area, color: StageDesignTokens.textSecondary),
        ),
      ],
    );
  }
}

class _CrewLoadingState extends StatelessWidget {
  const _CrewLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: ValueKey('stage-crew-loading'),
      padding: EdgeInsets.symmetric(vertical: StageDesignTokens.space32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _CrewEmptyState extends StatelessWidget {
  const _CrewEmptyState();

  @override
  Widget build(BuildContext context) {
    return const StageEmptyState(
      key: ValueKey('stage-crew-empty'),
      icon: Icons.groups_outlined,
      title: '募集中のクルーはまだありません',
      message: '新しい募集が公開されると、ここに表示されます',
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState();

  @override
  Widget build(BuildContext context) {
    return const StageEmptyState(
      key: ValueKey('stage-crew-filter-empty'),
      icon: Icons.search_off_rounded,
      title: '条件に合う募集がありません',
      message: '検索語やジャンルを変えてお試しください',
    );
  }
}

class _CrewErrorState extends StatelessWidget {
  const _CrewErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      key: const ValueKey('stage-crew-error'),
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
            'クルー募集を読み込めませんでした',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: StageDesignTokens.space4),
          const Text('時間をおいて再度お試しください'),
          const SizedBox(height: StageDesignTokens.space12),
          OutlinedButton(
            key: const ValueKey('stage-crew-retry'),
            onPressed: onRetry,
            child: const Text('再試行'),
          ),
        ],
      ),
    );
  }
}

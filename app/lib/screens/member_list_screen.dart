import 'package:flutter/material.dart';

import '../models/master_data_item.dart';
import '../models/member_profile.dart';
import '../models/member_search_filters.dart';
import '../services/master_data_service.dart';
import '../services/member_search_service.dart';
import '../widgets/member_card.dart';
import 'member_detail_screen.dart';

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  final _memberSearchService = MemberSearchService();
  final _masterDataService = MasterDataService();
  final _keywordController = TextEditingController();
  final _partIds = <String>{};
  final _genreIds = <String>{};
  final _areaIds = <String>{};
  final _experienceLevels = <String>{};
  final _purposes = <String>{};
  late Future<MasterData> _masterData;
  late Future<List<MemberProfile>> _members;
  MemberSearchFilters _activeFilters = const MemberSearchFilters();

  @override
  void initState() {
    super.initState();
    _masterData = _masterDataService.fetchActiveMasterData();
    _members = _memberSearchService.fetchMembers();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _masterData = _masterDataService.fetchActiveMasterData();
      _members = _memberSearchService.fetchMembers(filters: _activeFilters);
    });
  }

  void _applyFilters() {
    final filters = MemberSearchFilters(
      partIds: Set<String>.from(_partIds),
      genreIds: Set<String>.from(_genreIds),
      areaIds: Set<String>.from(_areaIds),
      experienceLevels: Set<String>.from(_experienceLevels),
      purposes: Set<String>.from(_purposes),
      keyword: _keywordController.text,
    );
    setState(() {
      _activeFilters = filters;
      _members = _memberSearchService.fetchMembers(filters: filters);
    });
  }

  void _clearFilters() {
    setState(() {
      _keywordController.clear();
      _partIds.clear();
      _genreIds.clear();
      _areaIds.clear();
      _experienceLevels.clear();
      _purposes.clear();
      _activeFilters = const MemberSearchFilters();
      _members = _memberSearchService.fetchMembers();
    });
  }

  void _toggle(Set<String> values, String value, bool selected) {
    setState(() {
      if (selected) {
        values.add(value);
      } else {
        values.remove(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メンバーを探す'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<MasterData>(
          future: _masterData,
          builder: (context, masterSnapshot) {
            if (masterSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (masterSnapshot.hasError) {
              return _MemberListError(onRetry: _reload);
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: FutureBuilder<List<MemberProfile>>(
                  future: _members,
                  builder: (context, memberSnapshot) {
                    final isLoading =
                        memberSnapshot.connectionState ==
                        ConnectionState.waiting;
                    final hasError = memberSnapshot.hasError;
                    final members = memberSnapshot.data ?? const [];

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      children: [
                        _FilterPanel(
                          masterData: masterSnapshot.requireData,
                          keywordController: _keywordController,
                          selectedPartIds: _partIds,
                          selectedGenreIds: _genreIds,
                          selectedAreaIds: _areaIds,
                          selectedExperienceLevels: _experienceLevels,
                          selectedPurposes: _purposes,
                          onToggle: _toggle,
                          onApply: _applyFilters,
                          onClear: _clearFilters,
                        ),
                        const SizedBox(height: 16),
                        if (isLoading)
                          const SizedBox(
                            height: 240,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (hasError)
                          _MemberListError(onRetry: _reload)
                        else if (members.isEmpty)
                          _EmptyMemberList(
                            isFiltered: _activeFilters.hasActiveFilters,
                          )
                        else
                          _MemberGrid(members: members),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.masterData,
    required this.keywordController,
    required this.selectedPartIds,
    required this.selectedGenreIds,
    required this.selectedAreaIds,
    required this.selectedExperienceLevels,
    required this.selectedPurposes,
    required this.onToggle,
    required this.onApply,
    required this.onClear,
  });

  final MasterData masterData;
  final TextEditingController keywordController;
  final Set<String> selectedPartIds;
  final Set<String> selectedGenreIds;
  final Set<String> selectedAreaIds;
  final Set<String> selectedExperienceLevels;
  final Set<String> selectedPurposes;
  final void Function(Set<String> values, String value, bool selected) onToggle;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('検索条件', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: keywordController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'キーワード',
                hintText: '表示名で検索',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => onApply(),
            ),
            const SizedBox(height: 20),
            _MasterDataFilterSection(
              title: 'パート',
              items: masterData.parts,
              selectedIds: selectedPartIds,
              onToggle: onToggle,
            ),
            const SizedBox(height: 18),
            _MasterDataFilterSection(
              title: 'ジャンル',
              items: masterData.genres,
              selectedIds: selectedGenreIds,
              onToggle: onToggle,
            ),
            if (masterData.areas.isNotEmpty) ...[
              const SizedBox(height: 18),
              _MasterDataFilterSection(
                title: 'エリア',
                items: masterData.areas,
                selectedIds: selectedAreaIds,
                onToggle: onToggle,
              ),
            ],
            const SizedBox(height: 18),
            _ValueFilterSection(
              title: '経験',
              values: _experienceLevelLabels,
              selectedValues: selectedExperienceLevels,
              onToggle: onToggle,
            ),
            const SizedBox(height: 18),
            _ValueFilterSection(
              title: '目的',
              values: _purposeLabels,
              selectedValues: selectedPurposes,
              onToggle: onToggle,
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onApply,
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: const Text('絞り込む'),
                ),
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear),
                  label: const Text('クリア'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MasterDataFilterSection extends StatelessWidget {
  const _MasterDataFilterSection({
    required this.title,
    required this.items,
    required this.selectedIds,
    required this.onToggle,
  });

  final String title;
  final List<MasterDataItem> items;
  final Set<String> selectedIds;
  final void Function(Set<String> values, String value, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return _FilterSection(
      title: title,
      children: items.map((item) {
        return FilterChip(
          label: Text(item.name),
          selected: selectedIds.contains(item.id),
          onSelected: (selected) => onToggle(selectedIds, item.id, selected),
        );
      }).toList(),
    );
  }
}

class _ValueFilterSection extends StatelessWidget {
  const _ValueFilterSection({
    required this.title,
    required this.values,
    required this.selectedValues,
    required this.onToggle,
  });

  final String title;
  final Map<String, String> values;
  final Set<String> selectedValues;
  final void Function(Set<String> values, String value, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    return _FilterSection(
      title: title,
      children: values.entries.map((entry) {
        return FilterChip(
          label: Text(entry.value),
          selected: selectedValues.contains(entry.key),
          onSelected: (selected) =>
              onToggle(selectedValues, entry.key, selected),
        );
      }).toList(),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _MemberGrid extends StatelessWidget {
  const _MemberGrid({required this.members});

  final List<MemberProfile> members;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 640
            ? 2
            : 1;
        const spacing = 16.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: members.map((member) {
            return SizedBox(
              width: cardWidth,
              height: 380,
              child: MemberCard(
                member: member,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MemberDetailScreen(memberId: member.id),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _EmptyMemberList extends StatelessWidget {
  const _EmptyMemberList({required this.isFiltered});

  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 44),
            const SizedBox(height: 16),
            Text(
              isFiltered ? '条件に合うメンバーがまだいません' : '表示できるメンバーはまだいません',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered ? '条件を変更して再度お試しください' : 'ほかのメンバーが登録されると、ここに表示されます',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberListError extends StatelessWidget {
  const _MemberListError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44),
            const SizedBox(height: 16),
            const Text('メンバー一覧を読み込めませんでした'),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
          ],
        ),
      ),
    );
  }
}

const _experienceLevelLabels = {
  'beginner_new': '未経験・始めたばかり',
  'beginner': '初心者',
  'experienced': '経験者',
  'pro_oriented': 'プロ志向',
};

const _purposeLabels = {
  'recruit': 'メンバー募集',
  'join': '参加希望',
  'practice': '練習仲間探し',
};

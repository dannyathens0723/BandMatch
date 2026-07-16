import 'package:flutter/material.dart';

import '../models/my_group_profile.dart';
import '../services/group_profile_service.dart';
import 'group_edit_screen.dart';

class MyGroupsScreen extends StatefulWidget {
  const MyGroupsScreen({super.key});

  @override
  State<MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends State<MyGroupsScreen> {
  final _service = GroupProfileService();
  late Future<List<MyGroupProfile>> _groups;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _groups = _service.fetchMyGroups();
  }

  Future<bool> _reload({bool showErrorSnackBar = false}) async {
    final nextGroups = _service.fetchMyGroups();
    setState(() {
      _groups = nextGroups;
      _isRefreshing = true;
    });

    try {
      await nextGroups;
      return true;
    } catch (error, stackTrace) {
      debugPrint('My groups refresh failed: $error\n$stackTrace');
      if (mounted && showErrorSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('グループ一覧を更新できませんでした。時間をおいて再度お試しください。')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _openCreate() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const GroupEditScreen()),
    );
    if (!mounted) return;
    if (result == 'created') {
      final refreshed = await _reload(showErrorSnackBar: true);
      if (!mounted || !refreshed) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('グループを作成しました')));
    }
  }

  Future<void> _openEdit(MyGroupProfile group) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => GroupEditScreen(group: group)),
    );
    if (!mounted) return;
    if (result == 'updated') {
      final refreshed = await _reload(showErrorSnackBar: true);
      if (!mounted || !refreshed) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('グループを更新しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('バンド・グループ'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            onPressed: _isRefreshing
                ? null
                : () => _reload(showErrorSnackBar: true),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('グループを作成'),
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<MyGroupProfile>>(
          future: _groups,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _MyGroupsError(
                onRetry: () => _reload(showErrorSnackBar: true),
              );
            }

            final groups = snapshot.requireData;
            if (groups.isEmpty) {
              return _EmptyGroups(onCreate: _openCreate);
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _GroupCard(
                      group: group,
                      onTap: () => _openEdit(group),
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

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onTap});

  final MyGroupProfile group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFFFF3CA),
                    child: Text(group.name.characters.first),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group.name, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          '更新: ${_formatDate(group.updatedAt)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if (_hasText(group.bio)) ...[
                const SizedBox(height: 16),
                Text(group.bio!),
              ],
              const SizedBox(height: 16),
              _GroupSummaryChips(label: '活動エリア', values: group.areaNames),
              _GroupSummaryChips(label: 'ジャンル', values: group.genreNames),
              _GroupSummaryChips(
                label: '募集パート',
                values: group.recruitingPartNames,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$month/$day';
  }
}

class _GroupSummaryChips extends StatelessWidget {
  const _GroupSummaryChips({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: values.map((value) => Chip(label: Text(value))).toList(),
          ),
        ],
      ),
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                'バンド・グループはまだありません',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '一緒に活動するメンバーを探すために、まずはグループを作成しましょう。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('グループを作成'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyGroupsError extends StatelessWidget {
  const _MyGroupsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 44),
              const SizedBox(height: 16),
              const Text('バンド・グループを読み込めませんでした。時間をおいて再度お試しください。'),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
            ],
          ),
        ),
      ),
    );
  }
}

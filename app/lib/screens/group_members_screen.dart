import 'package:flutter/material.dart';

import '../models/group_member.dart';
import '../models/my_group_profile.dart';
import '../services/group_member_service.dart';

class GroupMembersScreen extends StatefulWidget {
  const GroupMembersScreen({super.key, required this.group});

  final MyGroupProfile group;

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final _service = GroupMemberService();
  late Future<List<GroupMember>> _members;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _members = _service.fetchGroupMembers(widget.group.id);
  }

  Future<void> _reload({bool showErrorSnackBar = false}) async {
    final nextMembers = _service.fetchGroupMembers(widget.group.id);
    setState(() {
      _members = nextMembers;
      _isRefreshing = true;
    });

    try {
      await nextMembers;
    } catch (error, stackTrace) {
      debugPrint('Group members refresh failed: $error\n$stackTrace');
      if (mounted && showErrorSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メンバー一覧を更新できませんでした。時間をおいて再度お試しください。')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メンバー一覧'),
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
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<GroupMember>>(
          future: _members,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _GroupMembersError(
                onRetry: () => _reload(showErrorSnackBar: true),
              );
            }

            final members = snapshot.requireData;
            if (members.isEmpty) {
              return const _EmptyGroupMembers();
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  itemCount: members.length + 1,
                  separatorBuilder: (_, index) => index == 0
                      ? const SizedBox(height: 16)
                      : const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _GroupHeader(group: widget.group);
                    }
                    final member = members[index - 1];
                    return _GroupMemberCard(member: member);
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

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final MyGroupProfile group;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFFFFF3CA),
              child: Icon(Icons.groups_outlined),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text('このグループの参加メンバー'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupMemberCard extends StatelessWidget {
  const _GroupMemberCard({required this.member});

  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: member.avatarUrl == null
                      ? null
                      : NetworkImage(member.avatarUrl!),
                  child: member.avatarUrl == null
                      ? Text(member.displayName.characters.first)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '参加日: ${_formatDate(member.joinedAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(member.isAdmin ? '管理' : 'メンバー')),
              ],
            ),
            if (_hasText(member.experienceLevel)) ...[
              const SizedBox(height: 12),
              Text('経験: ${member.experienceLevel!}'),
            ],
            const SizedBox(height: 14),
            _MemberSummaryChips(label: 'パート', values: member.partNames),
            _MemberSummaryChips(label: 'ジャンル', values: member.genreNames),
          ],
        ),
      ),
    );
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  String _formatDate(DateTime value) {
    final year = value.year.toString();
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }
}

class _MemberSummaryChips extends StatelessWidget {
  const _MemberSummaryChips({required this.label, required this.values});

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

class _EmptyGroupMembers extends StatelessWidget {
  const _EmptyGroupMembers();

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
                'メンバーはまだいません',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupMembersError extends StatelessWidget {
  const _GroupMembersError({required this.onRetry});

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
              const Text('メンバー一覧を読み込めませんでした。時間をおいて再度お試しください。'),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
            ],
          ),
        ),
      ),
    );
  }
}

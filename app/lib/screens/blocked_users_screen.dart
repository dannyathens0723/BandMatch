import 'package:flutter/material.dart';

import '../models/blocked_user.dart';
import '../services/blocked_user_service.dart';
import '../services/user_safety_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _blockedUserService = BlockedUserService();
  final _userSafetyService = UserSafetyService();
  final _unblockingUserIds = <String>{};
  List<BlockedUser>? _blockedUsers;
  Object? _loadError;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final blockedUsers = await _blockedUserService.fetchMyBlockedUsers();
      if (!mounted) return;
      setState(() => _blockedUsers = blockedUsers);
    } catch (error, stackTrace) {
      debugPrint('Blocked users screen load failed: $error\n$stackTrace');
      if (mounted) setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmUnblock(BlockedUser user) async {
    if (_unblockingUserIds.contains(user.userId)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ブロックを解除しますか？'),
        content: const Text('解除すると、このユーザーとのメッセージリクエストやメッセージ送信が再び可能になります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('解除する'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _unblock(user);
  }

  Future<void> _unblock(BlockedUser user) async {
    if (_unblockingUserIds.contains(user.userId)) return;
    setState(() => _unblockingUserIds.add(user.userId));
    try {
      await _userSafetyService.unblockUser(user.userId);
      if (!mounted) return;
      setState(
        () => _blockedUsers = (_blockedUsers ?? const [])
            .where((blockedUser) => blockedUser.userId != user.userId)
            .toList(growable: false),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ブロックを解除しました')));
    } catch (error, stackTrace) {
      debugPrint('Blocked users screen unblock failed: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ブロックを解除できませんでした。時間をおいて再度お試しください。')),
      );
    } finally {
      if (mounted) {
        setState(() => _unblockingUserIds.remove(user.userId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final blockedUsers = _blockedUsers;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ブロックしたユーザー'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            onPressed: _isLoading ? null : _loadBlockedUsers,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null || blockedUsers == null
            ? _BlockedUsersError(onRetry: _loadBlockedUsers)
            : blockedUsers.isEmpty
            ? const _EmptyBlockedUsers()
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    itemCount: blockedUsers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final user = blockedUsers[index];
                      return _BlockedUserCard(
                        user: user,
                        isUnblocking: _unblockingUserIds.contains(user.userId),
                        onUnblock: () => _confirmUnblock(user),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }
}

class _BlockedUserCard extends StatelessWidget {
  const _BlockedUserCard({
    required this.user,
    required this.isUnblocking,
    required this.onUnblock,
  });

  final BlockedUser user;
  final bool isUnblocking;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BlockedUserAvatar(user: user),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (user.experienceLevel != null) ...[
                        const SizedBox(height: 4),
                        Text(_experienceLevelLabel(user.experienceLevel!)),
                      ],
                      const SizedBox(height: 5),
                      Text(
                        'ブロック日時: ${_formatDate(user.blockedAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (user.partNames.isNotEmpty || user.genreNames.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...user.partNames.map((name) => Chip(label: Text(name))),
                  ...user.genreNames.map((name) => Chip(label: Text(name))),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: isUnblocking ? null : onUnblock,
                icon: isUnblocking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open_outlined),
                label: const Text('ブロックを解除'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _experienceLevelLabel(String value) {
    return switch (value) {
      'beginner_new' => '未経験・始めたばかり',
      'beginner' => '初心者',
      'experienced' => '経験者',
      'pro_oriented' => 'プロ志向',
      _ => value,
    };
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString();
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }
}

class _BlockedUserAvatar extends StatelessWidget {
  const _BlockedUserAvatar({required this.user});

  final BlockedUser user;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl;
    final initial = user.displayName.isEmpty
        ? '?'
        : user.displayName.characters.first;
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return CircleAvatar(radius: 30, child: Text(initial));
    }
    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            CircleAvatar(radius: 30, child: Text(initial)),
      ),
    );
  }
}

class _EmptyBlockedUsers extends StatelessWidget {
  const _EmptyBlockedUsers();

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
              const Icon(Icons.person_off_outlined, size: 44),
              const SizedBox(height: 16),
              Text(
                'ブロックしたユーザーはいません',
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

class _BlockedUsersError extends StatelessWidget {
  const _BlockedUsersError({required this.onRetry});

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
              const Text('ブロック一覧を読み込めませんでした。時間をおいて再度お試しください。'),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
            ],
          ),
        ),
      ),
    );
  }
}

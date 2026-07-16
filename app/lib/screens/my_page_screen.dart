import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/my_page_profile.dart';
import '../services/my_page_service.dart';
import 'my_groups_screen.dart';
import 'profile_edit_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final _myPageService = MyPageService();
  MyPageProfile? _profile;
  Object? _loadError;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSigningOut = false;
  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile(showFullScreenLoading: true);
  }

  Future<bool> _loadProfile({bool showFullScreenLoading = false}) async {
    final requestId = ++_loadRequestId;
    if (mounted) {
      setState(() {
        _loadError = null;
        if (showFullScreenLoading || _profile == null) {
          _isLoading = true;
        } else {
          _isRefreshing = true;
        }
      });
    }

    try {
      final profile = await _myPageService.fetchMyPageProfile();
      if (!mounted || requestId != _loadRequestId) return false;
      setState(() {
        _profile = profile;
        _loadError = null;
      });
      return true;
    } catch (error, stackTrace) {
      debugPrint('My Page refresh failed: $error\n$stackTrace');
      if (mounted && requestId == _loadRequestId) {
        setState(() => _loadError = error);
      }
      return false;
    } finally {
      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _openProfileEdit() async {
    final wasUpdated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ProfileEditScreen()),
    );
    if (!mounted) return;

    final refreshed = await _loadProfile();
    if (!mounted) return;

    if (!refreshed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('マイページを更新できませんでした。時間をおいて再度お試しください。')),
      );
      return;
    }

    if (wasUpdated == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('プロフィールを更新しました')));
    }
  }

  Future<void> _openMyGroups() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MyGroupsScreen()));
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } on AuthException {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$titleは次のステップで実装します')));
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email;
    final profile = _profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('マイページ'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            onPressed: _isRefreshing
                ? null
                : () => _loadProfile(showFullScreenLoading: profile == null),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null || profile == null
            ? _MyPageLoadError(
                onRetry: () => _loadProfile(showFullScreenLoading: true),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    children: [
                      if (_isRefreshing) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 16),
                      ],
                      _ProfileSummaryCard(profile: profile),
                      if (email != null && email.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _AccountCard(email: email),
                      ],
                      const SizedBox(height: 16),
                      _ActionCard(
                        isSigningOut: _isSigningOut,
                        onProfileEdit: _openProfileEdit,
                        onMyGroups: _openMyGroups,
                        onSignOut: _signOut,
                        onComingSoon: _showComingSoon,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.profile});

  final MyPageProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(
                  avatarUrl: profile.avatarUrl,
                  displayName: profile.displayName,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        style: theme.textTheme.headlineSmall,
                      ),
                      if (profile.experienceLevel != null) ...[
                        const SizedBox(height: 4),
                        Text(_experienceLevelLabel(profile.experienceLevel!)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SummaryChips(
              icon: Icons.music_note_outlined,
              label: 'パート',
              values: profile.partNames,
            ),
            _SummaryChips(
              icon: Icons.queue_music_outlined,
              label: 'ジャンル',
              values: profile.genreNames,
            ),
            _SummaryChips(
              icon: Icons.location_on_outlined,
              label: 'エリア',
              values: profile.areaNames,
            ),
          ],
        ),
      ),
    );
  }

  static String _experienceLevelLabel(String value) {
    return switch (value) {
      'beginner_new' => '未経験・始めたばかり',
      'beginner' => '初心者',
      'experienced' => '経験者',
      'pro_oriented' => 'プロ志向',
      _ => value,
    };
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.alternate_email),
        title: const Text('ログイン中のメールアドレス'),
        subtitle: Text(email),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.isSigningOut,
    required this.onProfileEdit,
    required this.onMyGroups,
    required this.onSignOut,
    required this.onComingSoon,
  });

  final bool isSigningOut;
  final VoidCallback onProfileEdit;
  final VoidCallback onMyGroups;
  final VoidCallback onSignOut;
  final void Function(String title) onComingSoon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('プロフィール編集'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onProfileEdit,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('バンド・グループ'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onMyGroups,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('通知設定'),
              subtitle: const Text('次のステップで実装します'),
              onTap: () => onComingSoon('通知設定'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('ブロック・通報管理'),
              subtitle: const Text('次のステップで実装します'),
              onTap: () => onComingSoon('ブロック・通報管理'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('アカウント削除'),
              subtitle: const Text('次のステップで実装します'),
              onTap: () => onComingSoon('アカウント削除'),
            ),
            const Divider(height: 1),
            ListTile(
              enabled: !isSigningOut,
              leading: isSigningOut
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              title: const Text('ログアウト'),
              onTap: isSigningOut ? null : onSignOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChips extends StatelessWidget {
  const _SummaryChips({
    required this.icon,
    required this.label,
    required this.values,
  });

  final IconData icon;
  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: values
                      .map((value) => Chip(label: Text(value)))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatarUrl, required this.displayName});

  final String? avatarUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return CircleAvatar(
        radius: 34,
        child: Text(displayName.characters.first),
      );
    }

    return ClipOval(
      child: Image.network(
        avatarUrl!,
        width: 68,
        height: 68,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            CircleAvatar(radius: 34, child: Text(displayName.characters.first)),
      ),
    );
  }
}

class _MyPageLoadError extends StatelessWidget {
  const _MyPageLoadError({required this.onRetry});

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
              const Text('マイページを読み込めませんでした。時間をおいて再度お試しください。'),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/master_data_item.dart';
import 'chat_rooms_screen.dart';
import 'member_list_screen.dart';
import 'profile_edit_screen.dart';
import 'received_message_requests_screen.dart';
import '../services/master_data_service.dart';
import '../services/received_message_request_service.dart';
import '../widgets/master_data_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MasterDataService _masterDataService = MasterDataService();
  final ReceivedMessageRequestService _receivedRequestsService =
      ReceivedMessageRequestService();
  late Future<MasterData> _masterData;
  bool _isSigningOut = false;
  int _pendingRequestCount = 0;

  @override
  void initState() {
    super.initState();
    _masterData = _masterDataService.fetchActiveMasterData();
    _loadPendingRequestCount();
  }

  void _reload() {
    setState(() => _masterData = _masterDataService.fetchActiveMasterData());
    _loadPendingRequestCount();
  }

  Future<void> _loadPendingRequestCount() async {
    try {
      final count = await _receivedRequestsService
          .fetchPendingReceivedRequestCount();
      if (mounted) setState(() => _pendingRequestCount = count);
    } catch (_) {
      // Keep the icon unbadged when the count cannot be loaded. The inbox
      // screen provides the explicit retry/error state for real failures.
      if (mounted) setState(() => _pendingRequestCount = 0);
    }
  }

  Future<void> _openReceivedRequests() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ReceivedMessageRequestsScreen(),
      ),
    );
    if (mounted) await _loadPendingRequestCount();
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } on AuthException {
      // A network failure must not leave a usable local session behind.
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BandMatch'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'メンバーを探す',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MemberListScreen()),
            ),
            icon: const Icon(Icons.people_outline),
          ),
          IconButton(
            tooltip: 'プロフィール編集',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ProfileEditScreen(),
              ),
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            tooltip: 'メッセージ',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ChatRoomsScreen()),
            ),
            icon: const Icon(Icons.forum_outlined),
          ),
          _MessageRequestInboxButton(
            hasPendingRequests: _pendingRequestCount > 0,
            onPressed: _openReceivedRequests,
          ),
          IconButton(
            tooltip: 'サインアウト',
            onPressed: _isSigningOut ? null : _signOut,
            icon: _isSigningOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: FutureBuilder<MasterData>(
                future: _masterData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _LoadError(error: snapshot.error!, onRetry: _reload);
                  }

                  final data = snapshot.requireData;
                  return ListView(
                    children: [
                      Text(
                        'まずは、音楽でつながろう。',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'プロフィールの設定が完了しました。',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MemberListScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.people_outline),
                        label: const Text('メンバーを探す'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ChatRoomsScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.forum_outlined),
                        label: const Text('メッセージ'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ProfileEditScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.account_circle_outlined),
                        label: const Text('プロフィール編集'),
                      ),
                      const SizedBox(height: 28),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 760;
                          final sections = [
                            MasterDataSection(
                              title: '担当パート',
                              description: '募集・参加したいパートの選択肢',
                              items: data.parts,
                              icon: Icons.music_note_outlined,
                            ),
                            MasterDataSection(
                              title: '音楽ジャンル',
                              description: '好きな音楽・演奏したい音楽の選択肢',
                              items: data.genres,
                              icon: Icons.queue_music_outlined,
                            ),
                          ];
                          if (!isWide) {
                            return Column(
                              children: [
                                sections[0],
                                const SizedBox(height: 16),
                                sections[1],
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: sections[0]),
                              const SizedBox(width: 20),
                              Expanded(child: sections[1]),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageRequestInboxButton extends StatelessWidget {
  const _MessageRequestInboxButton({
    required this.hasPendingRequests,
    required this.onPressed,
  });

  final bool hasPendingRequests;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: 'メッセージリクエスト',
      onPressed: onPressed,
      icon: const Icon(Icons.mail_outline),
    );
    if (!hasPendingRequests) return button;
    return Badge(smallSize: 9, child: button);
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 16),
              const Text('データを表示できません'),
              const SizedBox(height: 8),
              Text('詳細: $error'),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/master_data_item.dart';
import '../services/master_data_service.dart';
import '../widgets/master_data_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MasterDataService _masterDataService = MasterDataService();
  late Future<MasterData> _masterData;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    _masterData = _masterDataService.fetchActiveMasterData();
  }

  void _reload() =>
      setState(() => _masterData = _masterDataService.fetchActiveMasterData());

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

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

  @override
  void initState() {
    super.initState();
    _masterData = _masterDataService.fetchActiveMasterData();
  }

  void _reload() {
    setState(() {
      _masterData = _masterDataService.fetchActiveMasterData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = Supabase.instance.client.auth.currentSession != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BandMatch'),
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
                    return _LoadError(
                      isSignedIn: isSignedIn,
                      error: snapshot.error!,
                      onRetry: _reload,
                    );
                  }

                  final data = snapshot.requireData;
                  return ListView(
                    children: [
                      Text('まずは、音楽でつながろう。',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Supabase に接続し、Phase 1 のマスターデータを読み込んでいます。',
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
  const _LoadError({
    required this.isSignedIn,
    required this.error,
    required this.onRetry,
  });

  final bool isSignedIn;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = isSignedIn
        ? 'マスターデータを読み込めませんでした。Supabase のマイグレーションとRLS設定を確認してください。'
        : '現在のRLS設定では、担当パートと音楽ジャンルは認証済みユーザーだけが読み取れます。認証機能を追加後、再読み込みしてください。';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40),
                const SizedBox(height: 16),
                Text('データを表示できません',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(message),
                if (!isSignedIn) ...[
                  const SizedBox(height: 20),
                  const _EmailSignInForm(),
                ],
                const SizedBox(height: 8),
                Text('詳細: $error', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('再読み込み'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailSignInForm extends StatefulWidget {
  const _EmailSignInForm();

  @override
  State<_EmailSignInForm> createState() => _EmailSignInFormState();
}

class _EmailSignInFormState extends State<_EmailSignInForm> {
  final _emailController = TextEditingController();
  bool _isSending = false;
  String? _status;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _status = '有効なメールアドレスを入力してください。');
      return;
    }

    setState(() {
      _isSending = true;
      _status = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: Uri.base.origin,
      );
      if (mounted) {
        setState(() {
          _status = 'サインイン用リンクを送信しました。メールのリンクを開いてください。';
        });
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _status = '送信できませんでした: ${error.message}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _status = '送信できませんでした。接続設定を確認してください。');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('テスト用サインイン', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'メールリンクでサインインすると、RLSで許可されたマスターデータを表示できます。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          enabled: !_isSending,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'メールアドレス',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _sendMagicLink(),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isSending ? null : _sendMagicLink,
          icon: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.mark_email_read_outlined),
          label: const Text('サインイン用リンクを送る'),
        ),
        if (_status case final status?) ...[
          const SizedBox(height: 8),
          Text(status, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

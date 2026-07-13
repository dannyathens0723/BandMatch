import 'package:flutter/material.dart';

import '../models/member_profile.dart';
import '../services/member_search_service.dart';

class MemberDetailScreen extends StatefulWidget {
  const MemberDetailScreen({super.key, required this.memberId});

  final String memberId;

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  final _memberSearchService = MemberSearchService();
  late Future<MemberProfile?> _member;

  @override
  void initState() {
    super.initState();
    _member = _memberSearchService.fetchMemberDetail(widget.memberId);
  }

  void _reload() {
    setState(
      () => _member = _memberSearchService.fetchMemberDetail(widget.memberId),
    );
  }

  void _showMessagePlaceholder() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('メッセージ機能は次のステップで実装します')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メンバー詳細'),
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
        child: FutureBuilder<MemberProfile?>(
          future: _member,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _DetailError(error: snapshot.error!, onRetry: _reload);
            }
            final member = snapshot.data;
            if (member == null) return const _DetailUnavailable();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MemberHeader(member: member),
                      const SizedBox(height: 16),
                      _DetailCard(
                        title: '音楽プロフィール',
                        children: [
                          _DetailChips(
                            icon: Icons.flag_outlined,
                            label: '利用目的',
                            values: member.purposes.map(_purposeLabel).toList(),
                          ),
                          _DetailChips(
                            icon: Icons.music_note_outlined,
                            label: '担当パート',
                            values: member.partNames,
                          ),
                          _DetailChips(
                            icon: Icons.queue_music_outlined,
                            label: '好きなジャンル',
                            values: member.genreNames,
                          ),
                          _DetailChips(
                            icon: Icons.location_on_outlined,
                            label: '活動エリア',
                            values: member.areaNames,
                          ),
                        ],
                      ),
                      if (_hasAnyAboutField(member)) ...[
                        const SizedBox(height: 16),
                        _DetailCard(
                          title: 'もっと知る',
                          children: [
                            if (_hasText(member.bio))
                              _DetailText(label: '自己紹介', value: member.bio!),
                            if (_hasText(member.favoriteArtists))
                              _DetailText(
                                label: '好きなアーティスト',
                                value: member.favoriteArtists!,
                              ),
                            if (_hasText(member.gear))
                              _DetailText(label: '機材', value: member.gear!),
                            if (member.activityFrequency != null)
                              _DetailText(
                                label: '活動頻度',
                                value: _activityFrequencyLabel(
                                  member.activityFrequency!,
                                ),
                              ),
                            if (_hasText(member.activityDays))
                              _DetailText(
                                label: '活動しやすい曜日',
                                value: member.activityDays!,
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _showMessagePlaceholder,
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('メッセージを送る'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  bool _hasAnyAboutField(MemberProfile member) {
    return _hasText(member.bio) ||
        _hasText(member.favoriteArtists) ||
        _hasText(member.gear) ||
        member.activityFrequency != null ||
        _hasText(member.activityDays);
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  String _purposeLabel(String value) {
    return switch (value) {
      'recruit' => 'メンバー募集',
      'join' => '参加希望',
      'practice' => '練習仲間探し',
      _ => value,
    };
  }

  String _activityFrequencyLabel(String value) {
    return switch (value) {
      'monthly_1_2' => '月1〜2回',
      'weekly_1_2' => '週1〜2回',
      'daily' => 'ほぼ毎日',
      _ => value,
    };
  }
}

class _MemberHeader extends StatelessWidget {
  const _MemberHeader({required this.member});

  final MemberProfile member;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (member.age != null) '${member.age}歳',
      if (member.gender != null) _genderLabel(member.gender!),
      if (member.experienceLevel != null)
        _experienceLevelLabel(member.experienceLevel!),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            _LargeAvatar(
              avatarUrl: member.avatarUrl,
              displayName: member.displayName,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(subtitle.join(' ・ ')),
                  ],
                ],
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

  String _genderLabel(String value) {
    return switch (value) {
      'male' => '男性',
      'female' => '女性',
      'non_binary' => 'ノンバイナリー',
      'no_answer' => '回答しない',
      _ => value,
    };
  }
}

class _LargeAvatar extends StatelessWidget {
  const _LargeAvatar({required this.avatarUrl, required this.displayName});

  final String? avatarUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return CircleAvatar(
        radius: 36,
        child: Text(displayName.characters.first),
      );
    }
    return ClipOval(
      child: Image.network(
        avatarUrl!,
        height: 72,
        width: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            CircleAvatar(radius: 36, child: Text(displayName.characters.first)),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailChips extends StatelessWidget {
  const _DetailChips({
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

class _DetailText extends StatelessWidget {
  const _DetailText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 5),
          Text(value),
        ],
      ),
    );
  }
}

class _DetailUnavailable extends StatelessWidget {
  const _DetailUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined, size: 44),
              SizedBox(height: 16),
              Text('このメンバーは表示できません'),
              SizedBox(height: 8),
              Text('プロフィールの公開状況が変わった可能性があります。'),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 44),
              const SizedBox(height: 16),
              const Text('メンバー詳細を読み込めませんでした'),
              const SizedBox(height: 8),
              Text('詳細: $error', maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
            ],
          ),
        ),
      ),
    );
  }
}

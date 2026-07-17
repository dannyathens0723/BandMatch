import 'package:flutter/material.dart';

import '../models/recruitment_post.dart';
import '../services/public_recruitment_post_service.dart';
import 'public_recruitment_post_detail_screen.dart';

class PublicRecruitmentPostsScreen extends StatefulWidget {
  const PublicRecruitmentPostsScreen({super.key});

  @override
  State<PublicRecruitmentPostsScreen> createState() =>
      _PublicRecruitmentPostsScreenState();
}

class _PublicRecruitmentPostsScreenState
    extends State<PublicRecruitmentPostsScreen> {
  final _service = PublicRecruitmentPostService();
  late Future<List<PublicRecruitmentPost>> _posts;

  @override
  void initState() {
    super.initState();
    _posts = _service.fetchOpenPosts();
  }

  void _reload() {
    setState(() => _posts = _service.fetchOpenPosts());
  }

  void _openDetail(PublicRecruitmentPost post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicRecruitmentPostDetailScreen(post: post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('募集を探す'),
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
            child: FutureBuilder<List<PublicRecruitmentPost>>(
              future: _posts,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _PublicRecruitmentPostsError(onRetry: _reload);
                }

                final posts = snapshot.requireData;
                if (posts.isEmpty) {
                  return const _EmptyPublicRecruitmentPosts();
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  itemCount: posts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return _PublicRecruitmentPostCard(
                      post: post,
                      onTap: () => _openDetail(post),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicRecruitmentPostCard extends StatelessWidget {
  const _PublicRecruitmentPostCard({required this.post, required this.onTap});

  final PublicRecruitmentPost post;
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFFFF3CA),
                    child: Icon(Icons.campaign_outlined),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.title, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(post.groupName),
                        const SizedBox(height: 4),
                        Text(
                          '更新: ${_formatDate(post.updatedAt)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _preview(post.body),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              _PostSummaryChips(label: '募集パート', values: post.wantedPartNames),
              _PostSummaryChips(label: 'ジャンル', values: post.genreNames),
              _PostSummaryChips(label: '活動エリア', values: post.areaNames),
            ],
          ),
        ),
      ),
    );
  }

  String _preview(String value) {
    final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.length <= 120) return text;
    return '${text.substring(0, 120)}…';
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$month/$day';
  }
}

class _PostSummaryChips extends StatelessWidget {
  const _PostSummaryChips({required this.label, required this.values});

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

class _EmptyPublicRecruitmentPosts extends StatelessWidget {
  const _EmptyPublicRecruitmentPosts();

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
              const Icon(Icons.campaign_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                '公開中の募集はまだありません',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text('新しい募集が公開されるまでお待ちください', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicRecruitmentPostsError extends StatelessWidget {
  const _PublicRecruitmentPostsError({required this.onRetry});

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
              const Text(
                '募集一覧を読み込めませんでした。時間をおいて再度お試しください。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
            ],
          ),
        ),
      ),
    );
  }
}

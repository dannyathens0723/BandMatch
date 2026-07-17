import 'package:flutter/material.dart';

import '../models/my_group_profile.dart';
import '../models/recruitment_post.dart';
import '../services/recruitment_post_service.dart';
import 'recruitment_post_edit_screen.dart';

class RecruitmentPostsScreen extends StatefulWidget {
  const RecruitmentPostsScreen({super.key, required this.group});

  final MyGroupProfile group;

  @override
  State<RecruitmentPostsScreen> createState() => _RecruitmentPostsScreenState();
}

class _RecruitmentPostsScreenState extends State<RecruitmentPostsScreen> {
  final _service = RecruitmentPostService();
  late Future<List<RecruitmentPost>> _posts;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _posts = _service.fetchMyGroupPosts(widget.group.id);
  }

  Future<bool> _reload({bool showErrorSnackBar = false}) async {
    final nextPosts = _service.fetchMyGroupPosts(widget.group.id);
    setState(() {
      _posts = nextPosts;
      _isRefreshing = true;
    });

    try {
      await nextPosts;
      return true;
    } catch (error, stackTrace) {
      debugPrint('Recruitment posts refresh failed: $error\n$stackTrace');
      if (mounted && showErrorSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('募集投稿一覧を更新できませんでした。時間をおいて再度お試しください。')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _openCreate() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => RecruitmentPostEditScreen(group: widget.group),
      ),
    );
    if (!mounted) return;
    if (result == 'created') {
      final refreshed = await _reload(showErrorSnackBar: true);
      if (!mounted || !refreshed) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('募集投稿を作成しました')));
    }
  }

  Future<void> _openEdit(RecruitmentPost post) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) =>
            RecruitmentPostEditScreen(group: widget.group, post: post),
      ),
    );
    if (!mounted) return;
    if (result == 'updated') {
      final refreshed = await _reload(showErrorSnackBar: true);
      if (!mounted || !refreshed) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('募集投稿を更新しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('募集投稿'),
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
        label: const Text('募集を作成'),
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<RecruitmentPost>>(
          future: _posts,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _RecruitmentPostsError(
                onRetry: () => _reload(showErrorSnackBar: true),
              );
            }

            final posts = snapshot.requireData;
            if (posts.isEmpty) {
              return _EmptyRecruitmentPosts(onCreate: _openCreate);
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                  itemCount: posts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return _RecruitmentPostCard(
                      post: post,
                      onTap: () => _openEdit(post),
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

class _RecruitmentPostCard extends StatelessWidget {
  const _RecruitmentPostCard({required this.post, required this.onTap});

  final RecruitmentPost post;
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
                  Expanded(
                    child: Text(post.title, style: theme.textTheme.titleLarge),
                  ),
                  const SizedBox(width: 12),
                  Chip(label: Text(_statusLabel(post.status))),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '更新: ${_formatDate(post.updatedAt)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Text(post.body, maxLines: 3, overflow: TextOverflow.ellipsis),
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

  String _statusLabel(String status) {
    return switch (status) {
      'draft' => '下書き',
      'open' => '公開中',
      'closed' => '終了',
      _ => status,
    };
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

class _EmptyRecruitmentPosts extends StatelessWidget {
  const _EmptyRecruitmentPosts({required this.onCreate});

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
              const Icon(Icons.campaign_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                '募集投稿はまだありません',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '必要なパートや活動内容を投稿して、メンバーを探しましょう。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('募集を作成'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecruitmentPostsError extends StatelessWidget {
  const _RecruitmentPostsError({required this.onRetry});

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
              const Text('募集投稿を読み込めませんでした。時間をおいて再度お試しください。'),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
            ],
          ),
        ),
      ),
    );
  }
}

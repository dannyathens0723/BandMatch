import 'package:flutter/material.dart';

import '../models/recruitment_post.dart';

class PublicRecruitmentPostDetailScreen extends StatelessWidget {
  const PublicRecruitmentPostDetailScreen({super.key, required this.post});

  final PublicRecruitmentPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('募集詳細')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.campaign_outlined),
                            const SizedBox(width: 8),
                            Text('公開中', style: theme.textTheme.labelLarge),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(post.title, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text(
                          post.groupName,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '更新: ${_formatDate(post.updatedAt)} / 作成: ${_formatDate(post.createdAt)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 24),
                        _DetailChips(
                          label: '募集パート',
                          values: post.wantedPartNames,
                        ),
                        _DetailChips(label: 'ジャンル', values: post.genreNames),
                        _DetailChips(label: '活動エリア', values: post.areaNames),
                        const SizedBox(height: 20),
                        Text('募集内容', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(post.body, style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline),
                            SizedBox(width: 12),
                            Expanded(child: Text('応募機能は次のステップで実装します')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.send_outlined),
                            label: const Text('応募する'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString();
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }
}

class _DetailChips extends StatelessWidget {
  const _DetailChips({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values.map((value) => Chip(label: Text(value))).toList(),
          ),
        ],
      ),
    );
  }
}

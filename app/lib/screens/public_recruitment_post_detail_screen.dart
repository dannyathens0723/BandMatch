import 'package:flutter/material.dart';

import '../models/recruitment_application.dart';
import '../models/recruitment_post.dart';
import '../services/recruitment_application_service.dart';

class PublicRecruitmentPostDetailScreen extends StatefulWidget {
  const PublicRecruitmentPostDetailScreen({super.key, required this.post});

  final PublicRecruitmentPost post;

  @override
  State<PublicRecruitmentPostDetailScreen> createState() =>
      _PublicRecruitmentPostDetailScreenState();
}

class _PublicRecruitmentPostDetailScreenState
    extends State<PublicRecruitmentPostDetailScreen> {
  final _applicationService = RecruitmentApplicationService();
  final _messageController = TextEditingController();
  late Future<RecruitmentApplicationState> _applicationState;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _applicationState = _applicationService.fetchMyApplicationState(
      widget.post.postId,
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _reloadApplicationState() {
    setState(() {
      _applicationState = _applicationService.fetchMyApplicationState(
        widget.post.postId,
      );
    });
  }

  Future<void> _apply() async {
    if (_isSubmitting) return;

    final message = _messageController.text.trim();
    if (message.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('応募メッセージは500文字以内で入力してください。')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final nextState = await _applicationService.applyToPost(
        postId: widget.post.postId,
        message: message,
      );
      if (!mounted) return;
      _messageController.clear();
      setState(() => _applicationState = Future.value(nextState));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('応募しました')));
    } catch (_) {
      if (!mounted) return;
      final recoveredState = await _recoverApplicationStateAfterSubmitError();
      if (!mounted) return;
      if (recoveredState != null && !recoveredState.canApply) {
        setState(() => _applicationState = Future.value(recoveredState));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('応募できませんでした。時間をおいて再度お試しください。')),
      );
      _reloadApplicationState();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<RecruitmentApplicationState?>
  _recoverApplicationStateAfterSubmitError() async {
    try {
      return await _applicationService.fetchMyApplicationState(
        widget.post.postId,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Recruitment application submit failed and state recovery also failed: '
        '$error\n$stackTrace',
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
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
                FutureBuilder<RecruitmentApplicationState>(
                  future: _applicationState,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _ApplicationLoadError(
                        onRetry: _reloadApplicationState,
                      );
                    }
                    return _ApplicationCard(
                      state: snapshot.requireData,
                      messageController: _messageController,
                      isSubmitting: _isSubmitting,
                      onApply: _apply,
                    );
                  },
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

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.state,
    required this.messageController,
    required this.isSubmitting,
    required this.onApply,
  });

  final RecruitmentApplicationState state;
  final TextEditingController messageController;
  final bool isSubmitting;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final stateLabel = _stateLabel(state.state);
    final canApply = state.canApply && !isSubmitting;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.how_to_reg_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '応募',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (stateLabel != null) Chip(label: Text(stateLabel)),
              ],
            ),
            const SizedBox(height: 16),
            if (state.canApply) ...[
              TextField(
                controller: messageController,
                enabled: !isSubmitting,
                maxLength: 500,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '応募メッセージ',
                  hintText: '自己紹介や参加したい理由を入力できます',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canApply ? onApply : null,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(isSubmitting ? '応募中...' : '応募する'),
                ),
              ),
            ] else
              Text(_stateDescription(state.state)),
          ],
        ),
      ),
    );
  }

  String? _stateLabel(String state) {
    return switch (state) {
      'pending' => '応募済み',
      'accepted' => '参加済み',
      'group_member' => '参加済み',
      'rejected' => '見送り済み',
      'own_group' => '自分のグループ',
      'closed' => '募集終了',
      _ => null,
    };
  }

  String _stateDescription(String state) {
    return switch (state) {
      'pending' => '応募済みです。グループからの確認をお待ちください。',
      'accepted' => '承認済みです。グループメンバーとして参加しています。',
      'group_member' => 'すでにこのグループに参加しています。',
      'rejected' => 'この応募は見送り済みです。',
      'own_group' => '自分が管理しているグループの募集には応募できません。',
      'closed' => 'この募集は現在応募できません。',
      _ => 'この募集には現在応募できません。',
    };
  }
}

class _ApplicationLoadError extends StatelessWidget {
  const _ApplicationLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 12),
            const Text('応募状態を読み込めませんでした。時間をおいて再度お試しください。'),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
          ],
        ),
      ),
    );
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

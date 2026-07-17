import 'package:flutter/material.dart';

import '../models/my_group_profile.dart';
import '../models/recruitment_application.dart';
import '../services/recruitment_application_service.dart';

class RecruitmentApplicationsScreen extends StatefulWidget {
  const RecruitmentApplicationsScreen({super.key, required this.group});

  final MyGroupProfile group;

  @override
  State<RecruitmentApplicationsScreen> createState() =>
      _RecruitmentApplicationsScreenState();
}

class _RecruitmentApplicationsScreenState
    extends State<RecruitmentApplicationsScreen> {
  final _service = RecruitmentApplicationService();
  late Future<List<RecruitmentApplication>> _applications;
  final _respondingIds = <String>{};
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _applications = _service.fetchGroupApplications(widget.group.id);
  }

  Future<bool> _reload({bool showErrorSnackBar = false}) async {
    final nextApplications = _service.fetchGroupApplications(widget.group.id);
    setState(() {
      _applications = nextApplications;
      _isRefreshing = true;
    });

    try {
      await nextApplications;
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'Recruitment applications refresh failed: $error\n$stackTrace',
      );
      if (mounted && showErrorSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('応募一覧を更新できませんでした。時間をおいて再度お試しください。')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _respond({
    required RecruitmentApplication application,
    required bool accept,
  }) async {
    if (_respondingIds.contains(application.id)) return;
    setState(() => _respondingIds.add(application.id));

    try {
      if (accept) {
        await _service.acceptApplication(application.id);
      } else {
        await _service.rejectApplication(application.id);
      }
      final refreshed = await _reload(showErrorSnackBar: true);
      if (!mounted || !refreshed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? '応募を承認しました' : '応募をお断りしました')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('応募を更新できませんでした。時間をおいて再度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _respondingIds.remove(application.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('応募一覧'),
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
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<RecruitmentApplication>>(
          future: _applications,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ApplicationsError(
                onRetry: () => _reload(showErrorSnackBar: true),
              );
            }

            final applications = snapshot.requireData;
            if (applications.isEmpty) {
              return const _EmptyApplications();
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  itemCount: applications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final application = applications[index];
                    return _ApplicationCard(
                      application: application,
                      isResponding: _respondingIds.contains(application.id),
                      onAccept: () =>
                          _respond(application: application, accept: true),
                      onReject: () =>
                          _respond(application: application, accept: false),
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

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.isResponding,
    required this.onAccept,
    required this.onReject,
  });

  final RecruitmentApplication application;
  final bool isResponding;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: application.applicantAvatarUrl == null
                      ? null
                      : NetworkImage(application.applicantAvatarUrl!),
                  child: application.applicantAvatarUrl == null
                      ? Text(application.applicantDisplayName.characters.first)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application.applicantDisplayName,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        application.postTitle,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '応募日: ${_formatDate(application.createdAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(_statusLabel(application.status))),
              ],
            ),
            if (_hasText(application.applicantExperienceLevel)) ...[
              const SizedBox(height: 12),
              Text('経験: ${application.applicantExperienceLevel!}'),
            ],
            const SizedBox(height: 14),
            _ApplicationSummaryChips(
              label: 'パート',
              values: application.applicantPartNames,
            ),
            _ApplicationSummaryChips(
              label: 'ジャンル',
              values: application.applicantGenreNames,
            ),
            if (_hasText(application.note)) ...[
              const SizedBox(height: 8),
              Text('応募メッセージ', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(application.note!),
            ],
            if (application.isPending) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isResponding ? null : onAccept,
                      icon: isResponding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('承認する'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isResponding ? null : onReject,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('お断りする'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  String _statusLabel(String status) {
    return switch (status) {
      'pending' => '確認待ち',
      'accepted' => '承認済み',
      'rejected' => 'お断り済み',
      _ => status,
    };
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString();
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }
}

class _ApplicationSummaryChips extends StatelessWidget {
  const _ApplicationSummaryChips({required this.label, required this.values});

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

class _EmptyApplications extends StatelessWidget {
  const _EmptyApplications();

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
              const Icon(Icons.assignment_ind_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                '応募者はまだいません',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text('応募が届くとここに表示されます', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplicationsError extends StatelessWidget {
  const _ApplicationsError({required this.onRetry});

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
              const Text('応募一覧を読み込めませんでした。時間をおいて再度お試しください。'),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/received_message_request.dart';
import '../services/received_message_request_service.dart';
import 'chat_room_screen.dart';

class ReceivedMessageRequestsScreen extends StatefulWidget {
  const ReceivedMessageRequestsScreen({super.key});

  @override
  State<ReceivedMessageRequestsScreen> createState() =>
      _ReceivedMessageRequestsScreenState();
}

class _ReceivedMessageRequestsScreenState
    extends State<ReceivedMessageRequestsScreen> {
  final _service = ReceivedMessageRequestService();
  final Set<String> _processingRequestIds = {};
  late Future<List<ReceivedMessageRequest>> _requests;

  @override
  void initState() {
    super.initState();
    _requests = _service.fetchReceivedRequests();
  }

  void _reload() {
    setState(() => _requests = _service.fetchReceivedRequests());
  }

  Future<void> _accept(ReceivedMessageRequest request) async {
    setState(() => _processingRequestIds.add(request.id));
    try {
      final roomId = await _service.acceptRequest(request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('リクエストを承認しました'),
          action: SnackBarAction(
            label: 'メッセージルームを開く',
            onPressed: () => _openRoom(roomId, request),
          ),
        ),
      );
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('承認に失敗しました。時間をおいて再度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _processingRequestIds.remove(request.id));
    }
  }

  Future<void> _openRoom(
    String roomId,
    ReceivedMessageRequest request,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatRoomScreen(
          roomId: roomId,
          roomTitle: request.senderDisplayName,
          otherAvatarUrl: request.senderAvatarUrl,
        ),
      ),
    );
  }

  Future<void> _reject(ReceivedMessageRequest request) async {
    await _process(
      request,
      action: _service.rejectRequest,
      successMessage: 'リクエストをお断りしました',
    );
  }

  Future<void> _process(
    ReceivedMessageRequest request, {
    required Future<void> Function(String requestId) action,
    required String successMessage,
  }) async {
    setState(() => _processingRequestIds.add(request.id));
    try {
      await action(request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作に失敗しました。時間をおいて再度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _processingRequestIds.remove(request.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メッセージリクエスト'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            onPressed: _processingRequestIds.isEmpty ? _reload : null,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<ReceivedMessageRequest>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return _InboxError(onRetry: _reload);

            final requests = snapshot.requireData;
            if (requests.isEmpty) return const _EmptyInbox();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  itemCount: requests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return _RequestCard(
                      request: request,
                      isProcessing: _processingRequestIds.contains(request.id),
                      onAccept: () => _accept(request),
                      onReject: () => _reject(request),
                      onOpenRoom: request.roomId == null
                          ? null
                          : () => _openRoom(request.roomId!, request),
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

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.isProcessing,
    required this.onAccept,
    required this.onReject,
    required this.onOpenRoom,
  });

  final ReceivedMessageRequest request;
  final bool isProcessing;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback? onOpenRoom;

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
                _Avatar(url: request.senderAvatarUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.senderDisplayName,
                        style: theme.textTheme.titleLarge,
                      ),
                      if (_hasText(request.senderExperienceLevel)) ...[
                        const SizedBox(height: 4),
                        Text(request.senderExperienceLevel!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _StatusChip(status: request.status),
              ],
            ),
            const SizedBox(height: 16),
            Text('受信日時: ${_formatDate(request.createdAt)}'),
            if (_hasText(request.note)) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(request.note!),
              ),
            ],
            if (request.partNames.isNotEmpty || request.genreNames.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ProfileTags(label: 'パート', values: request.partNames),
              if (request.partNames.isNotEmpty && request.genreNames.isNotEmpty)
                const SizedBox(height: 10),
              _ProfileTags(label: 'ジャンル', values: request.genreNames),
            ],
            if (request.isPending) ...[
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 430;
                  final acceptButton = FilledButton.icon(
                    onPressed: isProcessing ? null : onAccept,
                    icon: isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('承認する'),
                  );
                  final rejectButton = OutlinedButton.icon(
                    onPressed: isProcessing ? null : onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('お断りする'),
                  );
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        acceptButton,
                        const SizedBox(height: 10),
                        rejectButton,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      acceptButton,
                      const SizedBox(width: 12),
                      rejectButton,
                    ],
                  );
                },
              ),
            ],
            if (request.status == 'accepted' && onOpenRoom != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onOpenRoom,
                icon: const Icon(Icons.forum_outlined),
                label: const Text('メッセージルームを開く'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}年$month月$day日 $hour:$minute';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.trim().isNotEmpty;
    return CircleAvatar(
      radius: 28,
      backgroundColor: const Color(0xFFFFF3CA),
      backgroundImage: hasUrl ? NetworkImage(url!) : null,
      child: hasUrl ? null : const Icon(Icons.person_outline),
    );
  }
}

class _ProfileTags extends StatelessWidget {
  const _ProfileTags({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        ...values.map((value) => Chip(label: Text(value))),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'accepted' => ('承認済み', const Color(0xFFE1F4E5)),
      'rejected' => ('お断り済み', const Color(0xFFF7E4E4)),
      _ => ('承認待ち', const Color(0xFFFFF3CA)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mark_email_read_outlined, size: 44),
              const SizedBox(height: 16),
              Text(
                '届いているリクエストはまだありません',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('気になるメンバーにメッセージを送ってみましょう'),
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxError extends StatelessWidget {
  const _InboxError({required this.onRetry});

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
              const Text('リクエストを読み込めませんでした'),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
            ],
          ),
        ),
      ),
    );
  }
}

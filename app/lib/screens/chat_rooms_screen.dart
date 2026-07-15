import 'package:flutter/material.dart';

import '../models/chat_room_summary.dart';
import '../services/chat_room_service.dart';

class ChatRoomsScreen extends StatefulWidget {
  const ChatRoomsScreen({super.key});

  @override
  State<ChatRoomsScreen> createState() => _ChatRoomsScreenState();
}

class _ChatRoomsScreenState extends State<ChatRoomsScreen> {
  final _service = ChatRoomService();
  late Future<List<ChatRoomSummary>> _rooms;

  @override
  void initState() {
    super.initState();
    _rooms = _service.fetchMyChatRooms();
  }

  void _reload() => setState(() => _rooms = _service.fetchMyChatRooms());

  void _showChatPlaceholder() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('チャット画面は次のステップで実装します')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メッセージ'),
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
        child: FutureBuilder<List<ChatRoomSummary>>(
          future: _rooms,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return _ChatRoomsError(onRetry: _reload);

            final rooms = snapshot.requireData;
            if (rooms.isEmpty) return const _EmptyChatRooms();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  itemCount: rooms.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _ChatRoomCard(
                    room: rooms[index],
                    onTap: _showChatPlaceholder,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChatRoomCard extends StatelessWidget {
  const _ChatRoomCard({required this.room, required this.onTap});

  final ChatRoomSummary room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = room.avatarUrl?.trim().isNotEmpty ?? false;
    final timestamp = room.lastMessageAt ?? room.createdAt;
    final timestampLabel = room.lastMessageAt == null ? 'ルーム作成' : '最終更新';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFFFF3CA),
                backgroundImage: hasAvatar
                    ? NetworkImage(room.avatarUrl!)
                    : null,
                child: hasAvatar ? null : const Icon(Icons.person_outline),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_hasText(room.experienceLevel)) ...[
                      const SizedBox(height: 4),
                      Text(room.experienceLevel!),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '$timestampLabel: ${_formatDate(timestamp)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
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
    return '$month/$day $hour:$minute';
  }
}

class _EmptyChatRooms extends StatelessWidget {
  const _EmptyChatRooms();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.forum_outlined, size: 44),
              const SizedBox(height: 16),
              Text(
                'メッセージルームはまだありません',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('リクエストが承認されると、ここに表示されます'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatRoomsError extends StatelessWidget {
  const _ChatRoomsError({required this.onRetry});

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
              const Text('メッセージルームを読み込めませんでした'),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
            ],
          ),
        ),
      ),
    );
  }
}

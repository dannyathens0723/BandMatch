import 'package:flutter/material.dart';

import '../models/chat_room.dart';
import '../services/chat_service.dart';
import 'chat_room_screen.dart';

class ChatRoomsScreen extends StatefulWidget {
  const ChatRoomsScreen({super.key});

  @override
  State<ChatRoomsScreen> createState() => _ChatRoomsScreenState();
}

class _ChatRoomsScreenState extends State<ChatRoomsScreen> {
  final _chatService = ChatService();
  late Future<List<ChatRoom>> _rooms;

  @override
  void initState() {
    super.initState();
    _rooms = _chatService.fetchRooms();
  }

  void _reload() => setState(() => _rooms = _chatService.fetchRooms());

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
        child: FutureBuilder<List<ChatRoom>>(
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
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  itemCount: rooms.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return _ChatRoomCard(
                      room: room,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ChatRoomScreen(
                              roomId: room.id,
                              roomTitle: room.otherDisplayName,
                              otherAvatarUrl: room.otherAvatarUrl,
                            ),
                          ),
                        );
                        if (mounted) _reload();
                      },
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

class _ChatRoomCard extends StatelessWidget {
  const _ChatRoomCard({required this.room, required this.onTap});

  final ChatRoom room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = room.lastMessageBody?.trim();
    final timestamp = room.lastMessageCreatedAt ?? room.createdAt;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _RoomAvatar(url: room.otherAvatarUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.otherDisplayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_hasText(room.otherExperienceLevel)) ...[
                      const SizedBox(height: 3),
                      Text(
                        room.otherExperienceLevel!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      preview?.isNotEmpty == true
                          ? preview!
                          : 'まだメッセージはありません',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDate(timestamp),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  const Icon(Icons.chevron_right),
                ],
              ),
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
    return '${value.year}/$month/$day';
  }
}

class _RoomAvatar extends StatelessWidget {
  const _RoomAvatar({this.url});

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

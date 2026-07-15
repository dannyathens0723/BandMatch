import 'package:flutter/material.dart';

import '../models/chat_room_message.dart';
import '../services/chat_room_message_service.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.roomTitle,
  });

  final String roomId;
  final String roomTitle;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _service = ChatRoomMessageService();
  late Future<_ChatRoomData> _roomData;

  @override
  void initState() {
    super.initState();
    _roomData = _loadRoomData();
  }

  Future<_ChatRoomData> _loadRoomData() async {
    final results = await Future.wait([
      _service.fetchMessages(widget.roomId),
      _service.fetchCurrentProfileId(),
    ]);
    return _ChatRoomData(
      messages: results[0] as List<ChatRoomMessage>,
      currentUserId: results[1] as String,
    );
  }

  void _reload() => setState(() => _roomData = _loadRoomData());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomTitle),
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
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<_ChatRoomData>(
                future: _roomData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _ChatRoomError(onRetry: _reload);
                  }

                  final data = snapshot.requireData;
                  if (data.messages.isEmpty) {
                    return const _EmptyChatRoom();
                  }

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                        itemCount: data.messages.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final message = data.messages[index];
                          return _MessageBubble(
                            message: message,
                            isMine: message.senderUserId == data.currentUserId,
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            const _SendingPlaceholder(),
          ],
        ),
      ),
    );
  }
}

class _ChatRoomData {
  const _ChatRoomData({required this.messages, required this.currentUserId});

  final List<ChatRoomMessage> messages;
  final String currentUserId;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatRoomMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isMine ? const Color(0xFFFFE9A6) : Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.body),
                const SizedBox(height: 5),
                Text(
                  _formatDate(message.createdAt),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }
}

class _SendingPlaceholder extends StatelessWidget {
  const _SendingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.send_outlined),
              label: const Text('メッセージ送信は次のステップで実装します'),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChatRoom extends StatelessWidget {
  const _EmptyChatRoom();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 44),
              const SizedBox(height: 16),
              Text(
                'まだメッセージはありません',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('次のステップでメッセージ送信を実装します'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatRoomError extends StatelessWidget {
  const _ChatRoomError({required this.onRetry});

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
              const Text('メッセージを読み込めませんでした'),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
            ],
          ),
        ),
      ),
    );
  }
}

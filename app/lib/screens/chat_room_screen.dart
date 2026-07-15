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
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late Future<_ChatRoomData> _roomData;
  bool _isSending = false;

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
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_isSending) return;

    final body = _messageController.text.trim();
    if (body.isEmpty || body.length > 1000) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('メッセージは1〜1000文字で入力してください。')));
      return;
    }

    setState(() => _isSending = true);
    try {
      final sentMessage = await _service.sendMessage(
        roomId: widget.roomId,
        body: body,
      );
      if (!mounted) return;

      _messageController.clear();
      await _appendSentMessage(sentMessage);
    } catch (error, stackTrace) {
      debugPrint('Chat message send flow failed: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メッセージを送信できませんでした。時間をおいて再度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _appendSentMessage(ChatRoomMessage sentMessage) async {
    try {
      final data = await _roomData;
      if (!mounted) return;

      final messages = [...data.messages];
      if (!messages.any(
        (message) => message.messageId == sentMessage.messageId,
      )) {
        messages.add(sentMessage);
      }
      setState(
        () => _roomData = Future.value(
          _ChatRoomData(messages: messages, currentUserId: data.currentUserId),
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Chat message was sent but could not be appended to the UI: '
        '$error\n$stackTrace',
      );
    }
  }

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
                        controller: _scrollController,
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
            _MessageComposer(
              controller: _messageController,
              isSending: _isSending,
              onSend: _send,
            ),
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

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !isSending,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    hintText: 'メッセージを入力',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: isSending ? null : onSend,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(52, 52),
                  padding: EdgeInsets.zero,
                ),
                child: isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
              ),
            ],
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

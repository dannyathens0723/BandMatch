import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.roomTitle,
    this.otherAvatarUrl,
  });

  final String roomId;
  final String roomTitle;
  final String? otherAvatarUrl;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _chatService = ChatService();
  final _messageController = TextEditingController();
  late Future<_ChatData> _chatData;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _chatData = _loadChatData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<_ChatData> _loadChatData() async {
    final results = await Future.wait([
      _chatService.fetchMessages(widget.roomId),
      _chatService.currentProfileId(),
    ]);
    return _ChatData(
      messages: results[0] as List<ChatMessage>,
      currentUserId: results[1] as String,
    );
  }

  void _reload() => setState(() => _chatData = _loadChatData());

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
    late final _ChatData currentData;
    ChatMessage? pendingMessage;
    ChatMessage sentMessage;
    try {
      currentData = await _chatData;
      pendingMessage = ChatMessage(
        id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
        body: body,
        senderUserId: currentData.currentUserId,
        createdAt: DateTime.now(),
        isPending: true,
      );
      if (!mounted) return;
      _messageController.clear();
      _appendSentMessage(pendingMessage, currentData);

      sentMessage = await _chatService
          .sendMessage(
            roomId: widget.roomId,
            body: body,
            senderUserId: currentData.currentUserId,
          )
          .timeout(const Duration(seconds: 6));
    } on TimeoutException catch (error, stackTrace) {
      debugPrint('Chat message send response timed out: $error\n$stackTrace');
      if (mounted) setState(() => _isSending = false);
      unawaited(_reconcileTimedOutSend(pendingMessage!));
      return;
    } catch (error, stackTrace) {
      debugPrint('Chat message send failed: $error\n$stackTrace');
      if (!mounted) return;
      if (pendingMessage != null) {
        _removePendingMessage(pendingMessage.id, currentData);
      }
      if (_messageController.text.isEmpty) _messageController.text = body;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メッセージを送信できませんでした。時間をおいて再度お試しください。')),
      );
      if (mounted) setState(() => _isSending = false);
      return;
    }

    if (!mounted) return;
    _replacePendingMessage(
      pendingMessageId: pendingMessage.id,
      sentMessage: sentMessage,
      currentData: currentData,
    );

    _refreshInBackground();
  }

  void _appendSentMessage(ChatMessage sentMessage, _ChatData currentData) {
    final messages = [...currentData.messages];
    if (!messages.any((message) => message.id == sentMessage.id)) {
      messages.add(sentMessage);
    }
    setState(
      () => _chatData = Future.value(
        _ChatData(messages: messages, currentUserId: currentData.currentUserId),
      ),
    );
  }

  void _replacePendingMessage({
    required String pendingMessageId,
    required ChatMessage sentMessage,
    required _ChatData currentData,
  }) {
    var replaced = false;
    final messages = currentData.messages.map((message) {
      if (message.id != pendingMessageId) return message;
      replaced = true;
      return sentMessage;
    }).toList();
    if (!replaced) messages.add(sentMessage);
    setState(() {
      _chatData = Future.value(
        _ChatData(messages: messages, currentUserId: currentData.currentUserId),
      );
      _isSending = false;
    });
  }

  void _removePendingMessage(String pendingMessageId, _ChatData currentData) {
    setState(
      () => _chatData = Future.value(
        _ChatData(
          messages: currentData.messages
              .where((message) => message.id != pendingMessageId)
              .toList(growable: false),
          currentUserId: currentData.currentUserId,
        ),
      ),
    );
  }

  Future<void> _reconcileTimedOutSend(ChatMessage pendingMessage) async {
    // The write can commit even when the browser does not receive the RPC
    // response. Check the safe message projection instead of asking the user
    // to manually reload the chat room.
    for (var attempt = 0; attempt < 3; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      try {
        final refreshedData = await _loadChatData().timeout(
          const Duration(seconds: 3),
        );
        final hasSentMessage = refreshedData.messages.any(
          (message) =>
              message.senderUserId == pendingMessage.senderUserId &&
              message.body == pendingMessage.body &&
              message.createdAt.isAfter(
                pendingMessage.createdAt.subtract(const Duration(minutes: 1)),
              ),
        );
        if (!mounted) return;
        if (hasSentMessage) {
          setState(() {
            _chatData = Future.value(refreshedData);
            _isSending = false;
          });
          return;
        }
      } catch (error) {
        debugPrint('Chat message reconciliation failed: $error');
      }
    }

    if (!mounted) return;
    setState(() => _isSending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('送信状況を確認しています。しばらくしてから再読み込みしてください。')),
    );
  }

  Future<void> _refreshInBackground() async {
    try {
      final refreshedData = await _loadChatData();
      if (mounted) setState(() => _chatData = Future.value(refreshedData));
    } catch (error) {
      debugPrint('Chat refresh after successful send failed: $error');
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
            onPressed: _isSending ? null : _reload,
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
              child: FutureBuilder<_ChatData>(
                future: _chatData,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) return _ChatError(onRetry: _reload);

                  final data = snapshot.requireData;
                  if (data.messages.isEmpty) return const _EmptyChat();
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    itemCount: data.messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _MessageBubble(
                      message: data.messages[index],
                      isMine:
                          data.messages[index].senderUserId ==
                          data.currentUserId,
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

class _ChatData {
  const _ChatData({required this.messages, required this.currentUserId});

  final List<ChatMessage> messages;
  final String currentUserId;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final timestamp = _formatDate(message.createdAt);
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
                  message.isPending ? '送信中' : timestamp,
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
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.month}/${value.day} $hour:$minute';
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
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 12,
          ),
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

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

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
              const Text('最初のメッセージを送ってみましょう'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.onRetry});

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

import 'package:flutter/material.dart';

import '../models/chat_room_summary.dart';
import '../services/chat_room_service.dart';
import '../widgets/count_badge.dart';
import 'chat_room_screen.dart';

class ChatRoomsScreen extends StatefulWidget {
  const ChatRoomsScreen({super.key});

  @override
  State<ChatRoomsScreen> createState() => _ChatRoomsScreenState();
}

class _ChatRoomsScreenState extends State<ChatRoomsScreen> {
  final _service = ChatRoomService();
  List<ChatRoomSummary>? _rooms;
  Object? _loadError;
  bool _isLoading = true;
  bool _isRefreshing = false;
  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadRooms(showFullScreenLoading: true);
  }

  Future<bool> _loadRooms({
    bool showFullScreenLoading = false,
    bool showErrorSnackBar = false,
  }) async {
    final requestId = ++_loadRequestId;
    setState(() {
      _loadError = null;
      if (showFullScreenLoading || _rooms == null) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }
    });

    try {
      final rooms = await _service.fetchMyChatRooms();
      if (!mounted || requestId != _loadRequestId) return false;
      setState(() {
        _rooms = rooms;
        _loadError = null;
      });
      return true;
    } catch (error, stackTrace) {
      debugPrint('Chat room list refresh failed: $error\n$stackTrace');
      if (mounted && requestId == _loadRequestId) {
        setState(() => _loadError = error);
        if (showErrorSnackBar && _rooms != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('メッセージルームを更新できませんでした。時間をおいて再度お試しください。'),
            ),
          );
        }
      }
      return false;
    } finally {
      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _openRoom(ChatRoomSummary room) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChatRoomScreen(roomId: room.roomId, roomTitle: room.displayName),
      ),
    );
    if (!mounted) return;

    final currentRooms = _rooms;
    if (currentRooms != null) {
      setState(
        () => _rooms = currentRooms
            .map(
              (currentRoom) => currentRoom.roomId == room.roomId
                  ? currentRoom.copyWith(unreadCount: 0)
                  : currentRoom,
            )
            .toList(growable: false),
      );
    }
    await _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メッセージ'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            onPressed: _isRefreshing
                ? null
                : () => _loadRooms(showErrorSnackBar: true),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null && _rooms == null
            ? _ChatRoomsError(
                onRetry: () => _loadRooms(showFullScreenLoading: true),
              )
            : (_rooms ?? const []).isEmpty
            ? const _EmptyChatRooms()
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    itemCount: _rooms!.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _ChatRoomCard(
                      room: _rooms![index],
                      onTap: () => _openRoom(_rooms![index]),
                    ),
                  ),
                ),
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
              CountBadge(
                count: room.unreadCount,
                semanticLabel: '${room.displayName}の未読メッセージ',
                child: const Icon(Icons.chevron_right),
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

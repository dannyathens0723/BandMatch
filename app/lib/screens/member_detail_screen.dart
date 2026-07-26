import 'package:flutter/material.dart';

import '../models/member_relationship.dart';
import '../models/member_profile.dart';
import '../models/user_safety_state.dart';
import '../services/member_search_service.dart';
import '../services/message_request_service.dart';
import '../services/user_safety_service.dart';
import '../widgets/message_request_sheet.dart';
import '../widgets/user_report_dialog.dart';
import 'chat_room_screen.dart';
import 'received_message_requests_screen.dart';

class MemberDetailScreen extends StatefulWidget {
  const MemberDetailScreen({super.key, required this.memberId});

  final String memberId;

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  final _memberSearchService = MemberSearchService();
  final _messageRequestService = MessageRequestService();
  final _userSafetyService = UserSafetyService();
  late Future<MemberProfile?> _member;
  bool _isRequestStateLoading = true;
  MemberRelationship? _relationship;
  String? _requestStateError;
  bool _isSafetyStateLoading = true;
  UserSafetyState? _safetyState;
  String? _safetyStateError;
  bool _isBlockActionRunning = false;

  @override
  void initState() {
    super.initState();
    _member = _memberSearchService.fetchMemberDetail(widget.memberId);
    _loadRequestState();
    _loadSafetyState();
  }

  void _reload() {
    setState(
      () => _member = _memberSearchService.fetchMemberDetail(widget.memberId),
    );
    _loadRequestState();
    _loadSafetyState();
  }

  Future<void> _loadSafetyState() async {
    setState(() {
      _isSafetyStateLoading = true;
      _safetyStateError = null;
      _safetyState = null;
    });
    try {
      final state = await _userSafetyService.fetchState(widget.memberId);
      if (mounted) setState(() => _safetyState = state);
    } catch (_) {
      if (mounted) {
        setState(() => _safetyStateError = '安全状態を確認できませんでした。');
      }
    } finally {
      if (mounted) setState(() => _isSafetyStateLoading = false);
    }
  }

  Future<void> _loadRequestState() async {
    setState(() {
      _isRequestStateLoading = true;
      _requestStateError = null;
      _relationship = null;
    });
    try {
      final relationship = await _messageRequestService.fetchRelationship(
        widget.memberId,
      );
      if (mounted) setState(() => _relationship = relationship);
    } catch (_) {
      if (mounted) {
        setState(() => _requestStateError = 'リクエスト状態を確認できませんでした。');
      }
    } finally {
      if (mounted) setState(() => _isRequestStateLoading = false);
    }
  }

  Future<void> _openRequestSheet(MemberProfile member) async {
    final wasSent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => MessageRequestSheet(
        receiverName: member.displayName,
        onSubmit: (message) => _messageRequestService.sendRequest(
          receiverUserId: member.id,
          message: message,
        ),
      ),
    );

    if (wasSent != true || !mounted) return;
    await _loadRequestState();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('メッセージリクエストを送信しました')));
  }

  Future<void> _confirmBlockUser() async {
    if (_isBlockActionRunning) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('このユーザーをブロックしますか？'),
        content: const Text('ブロックすると、メッセージリクエストや新しいメッセージの送信が制限されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ブロックする'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _blockUser();
  }

  Future<void> _blockUser() async {
    if (_isBlockActionRunning) return;
    setState(() => _isBlockActionRunning = true);
    try {
      await _userSafetyService.blockUser(widget.memberId);
      if (!mounted) return;
      setState(() {
        _safetyState = UserSafetyState.blockedByMe;
        _safetyStateError = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ユーザーをブロックしました')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作を完了できませんでした。時間をおいて再度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _isBlockActionRunning = false);
    }
  }

  Future<void> _unblockUser() async {
    if (_isBlockActionRunning) return;
    setState(() => _isBlockActionRunning = true);
    try {
      await _userSafetyService.unblockUser(widget.memberId);
      if (!mounted) return;
      setState(
        () => _member = _memberSearchService.fetchMemberDetail(widget.memberId),
      );
      await Future.wait([_loadSafetyState(), _loadRequestState()]);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ブロックを解除しました')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作を完了できませんでした。時間をおいて再度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _isBlockActionRunning = false);
    }
  }

  Future<void> _openReportDialog() async {
    final reported = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UserReportDialog(
        onSubmit: (reason, note) => _userSafetyService.reportUser(
          targetUserId: widget.memberId,
          reason: reason,
          note: note,
        ),
      ),
    );
    if (reported != true || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('通報を受け付けました')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メンバー詳細'),
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
        child: FutureBuilder<MemberProfile?>(
          future: _member,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_safetyState == UserSafetyState.blockedByMe ||
                _safetyState == UserSafetyState.blockedMe) {
              return _RestrictedMemberDetail(
                state: _safetyState!,
                isBlockActionRunning: _isBlockActionRunning,
                onUnblock: _unblockUser,
                onReport: _openReportDialog,
              );
            }
            if (snapshot.hasError) {
              return _DetailError(error: snapshot.error!, onRetry: _reload);
            }
            final member = snapshot.data;
            if (member == null) return const _DetailUnavailable();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MemberHeader(member: member),
                      const SizedBox(height: 16),
                      _DetailCard(
                        title: '音楽プロフィール',
                        children: [
                          _DetailChips(
                            icon: Icons.flag_outlined,
                            label: '利用目的',
                            values: member.purposes.map(_purposeLabel).toList(),
                          ),
                          _DetailChips(
                            icon: Icons.music_note_outlined,
                            label: '担当パート',
                            values: member.partNames,
                          ),
                          _DetailChips(
                            icon: Icons.queue_music_outlined,
                            label: '好きなジャンル',
                            values: member.genreNames,
                          ),
                          _DetailChips(
                            icon: Icons.location_on_outlined,
                            label: '活動エリア',
                            values: member.areaNames,
                          ),
                        ],
                      ),
                      if (_hasAnyAboutField(member)) ...[
                        const SizedBox(height: 16),
                        _DetailCard(
                          title: 'もっと知る',
                          children: [
                            if (_hasText(member.bio))
                              _DetailText(label: '自己紹介', value: member.bio!),
                            if (_hasText(member.favoriteArtists))
                              _DetailText(
                                label: '好きなアーティスト',
                                value: member.favoriteArtists!,
                              ),
                            if (_hasText(member.gear))
                              _DetailText(label: '機材', value: member.gear!),
                            if (member.activityFrequency != null)
                              _DetailText(
                                label: '活動頻度',
                                value: _activityFrequencyLabel(
                                  member.activityFrequency!,
                                ),
                              ),
                            if (_hasText(member.activityDays))
                              _DetailText(
                                label: '活動しやすい曜日',
                                value: member.activityDays!,
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (_isSafetyStateLoading)
                        const _SafetyActionsLoading()
                      else if (_safetyStateError != null ||
                          _safetyState == null ||
                          _safetyState == UserSafetyState.unavailable)
                        _SafetyStateWarning(onRetry: _loadSafetyState)
                      else ...[
                        _MessageRequestButton(
                          isLoading: _isRequestStateLoading,
                          relationship: _relationship,
                          error: _requestStateError,
                          onSendRequest: () => _openRequestSheet(member),
                          onOpenInbox: _openReceivedRequests,
                          onOpenRoom: () => _openRoom(member),
                        ),
                        const SizedBox(height: 16),
                        _SafetyActionsCard(
                          isBlockActionRunning: _isBlockActionRunning,
                          onBlock: _confirmBlockUser,
                          onReport: _openReportDialog,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  bool _hasAnyAboutField(MemberProfile member) {
    return _hasText(member.bio) ||
        _hasText(member.favoriteArtists) ||
        _hasText(member.gear) ||
        member.activityFrequency != null ||
        _hasText(member.activityDays);
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  String _purposeLabel(String value) {
    return switch (value) {
      'recruit' => 'メンバー募集',
      'join' => '参加希望',
      'practice' => '練習仲間探し',
      _ => value,
    };
  }

  String _activityFrequencyLabel(String value) {
    return switch (value) {
      'monthly_1_2' => '月1〜2回',
      'weekly_1_2' => '週1〜2回',
      'daily' => 'ほぼ毎日',
      _ => value,
    };
  }

  Future<void> _openReceivedRequests() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ReceivedMessageRequestsScreen(),
      ),
    );
    if (mounted) await _loadRequestState();
  }

  void _openRoom(MemberProfile member) {
    final roomId = _relationship?.roomId;
    if (roomId == null || roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メッセージルームを開けませんでした。時間をおいて再度お試しください。')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChatRoomScreen(roomId: roomId, roomTitle: member.displayName),
      ),
    );
  }
}

class _RestrictedMemberDetail extends StatelessWidget {
  const _RestrictedMemberDetail({
    required this.state,
    required this.isBlockActionRunning,
    required this.onUnblock,
    required this.onReport,
  });

  final UserSafetyState state;
  final bool isBlockActionRunning;
  final VoidCallback onUnblock;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final isBlockedByMe = state == UserSafetyState.blockedByMe;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.block_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    isBlockedByMe ? 'このユーザーをブロックしています' : 'このユーザーとは現在やり取りできません',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'メッセージリクエストと新しいメッセージの送信は利用できません。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (isBlockedByMe) ...[
                    OutlinedButton.icon(
                      onPressed: isBlockActionRunning ? null : onUnblock,
                      icon: isBlockActionRunning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_open_outlined),
                      label: const Text('ブロックを解除'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextButton.icon(
                    onPressed: onReport,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('通報する'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SafetyActionsCard extends StatelessWidget {
  const _SafetyActionsCard({
    required this.isBlockActionRunning,
    required this.onBlock,
    required this.onReport,
  });

  final bool isBlockActionRunning;
  final VoidCallback onBlock;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('安全に利用する', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: isBlockActionRunning ? null : onBlock,
                  icon: isBlockActionRunning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.block_outlined),
                  label: const Text('ブロックする'),
                ),
                TextButton.icon(
                  onPressed: onReport,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('通報する'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageRequestButton extends StatelessWidget {
  const _MessageRequestButton({
    required this.isLoading,
    required this.relationship,
    required this.error,
    required this.onSendRequest,
    required this.onOpenInbox,
    required this.onOpenRoom,
  });

  final bool isLoading;
  final MemberRelationship? relationship;
  final String? error;
  final VoidCallback onSendRequest;
  final VoidCallback onOpenInbox;
  final VoidCallback onOpenRoom;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error case final requestError?) ...[
          Text(requestError, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
        ],
        _buttonForState(context),
      ],
    );
  }

  Widget _buttonForState(BuildContext context) {
    final state = relationship?.state;
    return switch (state) {
      MemberRelationshipState.none => FilledButton.icon(
        onPressed: onSendRequest,
        icon: const Icon(Icons.mail_outline),
        label: const Text('メッセージを送る'),
      ),
      MemberRelationshipState.outgoingPending => FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.schedule),
        label: const Text('メッセージリクエスト送信済み'),
      ),
      MemberRelationshipState.incomingPending => OutlinedButton.icon(
        onPressed: onOpenInbox,
        icon: const Icon(Icons.mark_email_unread_outlined),
        label: const Text('届いているリクエストを確認'),
      ),
      MemberRelationshipState.accepted ||
      MemberRelationshipState.roomExists => FilledButton.icon(
        onPressed: onOpenRoom,
        icon: const Icon(Icons.forum_outlined),
        label: const Text('メッセージルームを開く'),
      ),
      MemberRelationshipState.rejected => FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.block_outlined),
        label: const Text('リクエストは終了しました'),
      ),
      null => FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.mail_outline),
        label: const Text('メッセージを送る'),
      ),
    };
  }
}

class _MemberHeader extends StatelessWidget {
  const _MemberHeader({required this.member});

  final MemberProfile member;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (member.age != null) '${member.age}歳',
      if (member.gender != null) _genderLabel(member.gender!),
      if (member.experienceLevel != null)
        _experienceLevelLabel(member.experienceLevel!),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            _LargeAvatar(
              avatarUrl: member.avatarUrl,
              displayName: member.displayName,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(subtitle.join(' ・ ')),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _experienceLevelLabel(String value) {
    return switch (value) {
      'beginner_new' => '未経験・始めたばかり',
      'beginner' => '初心者',
      'experienced' => '経験者',
      'pro_oriented' => 'プロ志向',
      _ => value,
    };
  }

  String _genderLabel(String value) {
    return switch (value) {
      'male' => '男性',
      'female' => '女性',
      'non_binary' => 'ノンバイナリー',
      'no_answer' => '回答しない',
      _ => value,
    };
  }
}

class _LargeAvatar extends StatelessWidget {
  const _LargeAvatar({required this.avatarUrl, required this.displayName});

  final String? avatarUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return CircleAvatar(
        radius: 36,
        child: Text(displayName.characters.first),
      );
    }
    return ClipOval(
      child: Image.network(
        avatarUrl!,
        height: 72,
        width: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            CircleAvatar(radius: 36, child: Text(displayName.characters.first)),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailChips extends StatelessWidget {
  const _DetailChips({
    required this.icon,
    required this.label,
    required this.values,
  });

  final IconData icon;
  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: values
                      .map((value) => Chip(label: Text(value)))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailText extends StatelessWidget {
  const _DetailText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 5),
          Text(value),
        ],
      ),
    );
  }
}

class _DetailUnavailable extends StatelessWidget {
  const _DetailUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined, size: 44),
              SizedBox(height: 16),
              Text('このメンバーは表示できません'),
              SizedBox(height: 8),
              Text('プロフィールの公開状況が変わった可能性があります。'),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyActionsLoading extends StatelessWidget {
  const _SafetyActionsLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

class _SafetyStateWarning extends StatelessWidget {
  const _SafetyStateWarning({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined),
                  SizedBox(width: 10),
                  Expanded(child: Text('安全状態を確認できませんでした。')),
                ],
              ),
              const SizedBox(height: 8),
              const Text('安全確認が完了するまで、メッセージ・ブロック・通報操作は利用できません。'),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('安全状態を再確認')),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.error, required this.onRetry});

  final Object error;
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
              const Text('メンバー詳細を読み込めませんでした'),
              const SizedBox(height: 8),
              Text('詳細: $error', maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
            ],
          ),
        ),
      ),
    );
  }
}

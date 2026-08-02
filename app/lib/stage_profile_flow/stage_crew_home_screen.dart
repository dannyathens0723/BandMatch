import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/stage_crew_activity.dart';
import '../models/stage_event.dart';
import '../models/stage_my_crew.dart';
import '../services/stage_crew_activity_service.dart';
import '../services/stage_crew_management_service.dart';
import '../services/stage_event_discovery_service.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';
import 'stage_crew_announcement_detail_screen.dart';
import 'stage_crew_management_screens.dart';

typedef StageCrewHomeLoad = ({
  StageCrewHome home,
  StageCrewActivitySnapshot activity,
});

class StageCrewHomeScreen extends StatefulWidget {
  const StageCrewHomeScreen({
    required this.initialCrew,
    required this.availableCrews,
    super.key,
    this.repository,
  });

  final StageMyCrew initialCrew;
  final List<StageMyCrew> availableCrews;
  final StageCrewActivityRepository? repository;

  @override
  State<StageCrewHomeScreen> createState() => _StageCrewHomeScreenState();
}

class _StageCrewHomeScreenState extends State<StageCrewHomeScreen> {
  late final StageCrewActivityRepository _repository;
  late StageMyCrew _crew;
  late Future<StageCrewHomeLoad> _load;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? StageCrewActivityService();
    _crew = widget.initialCrew;
    _load = _loadCrew(_crew.crewId);
  }

  @override
  Widget build(BuildContext context) {
    return StageMobilePageFrame(
      child: Scaffold(
        key: const ValueKey('stage-crew-home-screen'),
        appBar: AppBar(title: const Text('クルーホーム')),
        body: FutureBuilder<StageCrewHomeLoad>(
          future: _load,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _LoadError(
                message: 'クルーホームを読み込めませんでした。',
                onRetry: _reload,
              );
            }
            final data = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(StageDesignTokens.space16),
                children: [
                  if (widget.availableCrews.length > 1) ...[
                    DropdownButtonFormField<String>(
                      key: const ValueKey('stage-crew-context-switcher'),
                      initialValue: _crew.crewId,
                      decoration: const InputDecoration(labelText: '表示するクルー'),
                      items: widget.availableCrews
                          .map(
                            (crew) => DropdownMenuItem(
                              value: crew.crewId,
                              child: Text(crew.crewName),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _switchCrew,
                    ),
                    const SizedBox(height: StageDesignTokens.space12),
                  ],
                  _CrewHero(home: data.home),
                  const SizedBox(height: StageDesignTokens.space16),
                  if (data.home.isAdmin)
                    OutlinedButton.icon(
                      key: const ValueKey('stage-crew-management-action'),
                      onPressed: _openManagement,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('クルー・募集を管理'),
                    ),
                  _HomeEntry(
                    icon: Icons.flag_outlined,
                    title: '目標イベント',
                    value: data.home.targetEvent?.title ?? '目標イベントは未設定です',
                    onTap: () => _openSection(_CrewSection.history),
                  ),
                  _HomeEntry(
                    icon: Icons.event_available_outlined,
                    title: '次の練習',
                    value: data.home.nextPractice == null
                        ? '予定されている練習はありません'
                        : data.home.nextPractice!.title,
                    detail: data.home.nextPractice == null
                        ? null
                        : '${_dateTime(data.home.nextPractice!.startsAt)} ・ '
                              '${_attendanceLabel(data.home.nextPractice!.myAttendance)}',
                    onTap: () => _openSection(_CrewSection.practices),
                  ),
                  _HomeEntry(
                    icon: Icons.how_to_vote_outlined,
                    title: '日程調整',
                    value: data.home.openPoll?.title ?? '回答受付中の投票はありません',
                    onTap: () => _openSection(_CrewSection.polls),
                  ),
                  _HomeEntry(
                    key: const ValueKey('stage-crew-announcements-entry'),
                    icon: Icons.campaign_outlined,
                    title: 'お知らせ',
                    value:
                        data.home.latestAnnouncement?.title ?? 'お知らせはまだありません',
                    onTap: () => _openSection(_CrewSection.announcements),
                  ),
                  _HomeEntry(
                    key: const ValueKey('stage-crew-resources-entry'),
                    icon: Icons.folder_open_outlined,
                    title: '練習資料',
                    value: data.home.latestResource?.title ?? '資料はまだありません',
                    onTap: () => _openSection(_CrewSection.resources),
                  ),
                  const SizedBox(height: StageDesignTokens.space16),
                  Text(
                    '最近のクルー活動',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: StageDesignTokens.space8),
                  _RecentActivity(snapshot: data.activity),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<StageCrewHomeLoad> _loadCrew(String crewId) async {
    final values = await Future.wait<Object>([
      _repository.fetchCrewHome(crewId),
      _repository.fetchCrewActivity(crewId),
    ]);
    return (
      home: values[0] as StageCrewHome,
      activity: values[1] as StageCrewActivitySnapshot,
    );
  }

  Future<void> _reload() async {
    final next = _loadCrew(_crew.crewId);
    setState(() {
      _load = next;
    });
    await next;
  }

  void _switchCrew(String? crewId) {
    if (crewId == null || crewId == _crew.crewId) return;
    final selected = widget.availableCrews.firstWhere(
      (crew) => crew.crewId == crewId,
    );
    setState(() {
      _crew = selected;
      _load = _loadCrew(selected.crewId);
    });
  }

  Future<void> _openManagement() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StageManagedCrewScreen(
          crew: _crew,
          repository: StageCrewManagementService(),
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _openSection(_CrewSection section) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _StageCrewActivitySectionScreen(
          crew: _crew,
          section: section,
          repository: _repository,
        ),
      ),
    );
    if (mounted) await _reload();
  }
}

enum _CrewSection { practices, polls, announcements, resources, history }

class _StageCrewActivitySectionScreen extends StatefulWidget {
  const _StageCrewActivitySectionScreen({
    required this.crew,
    required this.section,
    required this.repository,
  });

  final StageMyCrew crew;
  final _CrewSection section;
  final StageCrewActivityRepository repository;

  @override
  State<_StageCrewActivitySectionScreen> createState() =>
      _StageCrewActivitySectionScreenState();
}

class _StageCrewActivitySectionScreenState
    extends State<_StageCrewActivitySectionScreen> {
  late Future<StageCrewActivitySnapshot> _load;
  bool _mutating = false;

  bool get _isAdmin => widget.crew.isManaged;

  @override
  void initState() {
    super.initState();
    _load = widget.repository.fetchCrewActivity(widget.crew.crewId);
  }

  @override
  Widget build(BuildContext context) {
    return StageMobilePageFrame(
      child: Scaffold(
        key: ValueKey('stage-crew-${widget.section.name}-screen'),
        appBar: AppBar(
          title: Text(_sectionTitle(widget.section)),
          actions: [
            if (_isAdmin && widget.section != _CrewSection.history)
              IconButton(
                key: ValueKey('stage-crew-${widget.section.name}-add'),
                tooltip: '追加',
                onPressed: _mutating ? null : _add,
                icon: const Icon(Icons.add_rounded),
              ),
          ],
        ),
        body: FutureBuilder<StageCrewActivitySnapshot>(
          future: _load,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _LoadError(
                message: '${_sectionTitle(widget.section)}を読み込めませんでした。',
                onRetry: _reload,
              );
            }
            final data = snapshot.data!;
            final children = _buildItems(data);
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.all(StageDesignTokens.space16),
                children: children.isEmpty
                    ? [
                        StageEmptyState(
                          icon: _sectionIcon(widget.section),
                          title: '${_sectionTitle(widget.section)}はまだありません',
                          message: _isAdmin
                              ? '右上の追加ボタンから登録できます。'
                              : '管理者が登録するとここに表示されます。',
                        ),
                      ]
                    : children,
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildItems(StageCrewActivitySnapshot data) =>
      switch (widget.section) {
        _CrewSection.practices =>
          data.practices
              .map(
                (item) => _PracticeCard(
                  item: item,
                  isAdmin: _isAdmin,
                  onAttendance: (value) => _respondAttendance(item, value),
                  onEdit: () => _editPractice(item),
                  onComplete: () => _completePractice(item),
                  onCancel: () => _cancelPractice(item),
                ),
              )
              .toList(),
        _CrewSection.polls =>
          data.polls
              .map(
                (item) => _PollCard(
                  poll: item,
                  isAdmin: _isAdmin,
                  onRespond: (responses) => _respondPoll(item, responses),
                  onFinalize: (optionId) => _finalizePoll(item, optionId),
                  onCancel: () => _cancelPoll(item),
                ),
              )
              .toList(),
        _CrewSection.announcements =>
          data.announcements
              .map(
                (item) => _AnnouncementCard(
                  item: item,
                  isAdmin: _isAdmin,
                  onOpen: () => _openAnnouncement(item),
                  onEdit: () => _editAnnouncement(item),
                  onArchive: () => _archiveAnnouncement(item),
                ),
              )
              .toList(),
        _CrewSection.resources =>
          data.resources
              .map(
                (item) => _ResourceCard(
                  item: item,
                  isAdmin: _isAdmin,
                  onOpen: () => _openResource(item),
                  onEdit: () => _editResource(item),
                  onArchive: () => _archiveResource(item),
                ),
              )
              .toList(),
        _CrewSection.history => [
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.only(bottom: StageDesignTokens.space12),
              child: StagePrimaryButton(
                key: const ValueKey('stage-crew-target-select'),
                label: '目標イベントを変更',
                icon: Icons.flag_outlined,
                onPressed: _mutating ? null : _selectTarget,
              ),
            ),
          ...data.targets.map(_TargetCard.new),
          ...data.practices
              .where(
                (item) =>
                    item.status != 'scheduled' ||
                    item.endsAt.isBefore(DateTime.now()),
              )
              .map(
                (item) => _HistoryCard(
                  title: item.title,
                  subtitle: '練習 ・ ${_statusLabel(item.status)}',
                ),
              ),
          ...data.polls
              .where((item) => item.status != 'open')
              .map(
                (item) => _HistoryCard(
                  title: item.title,
                  subtitle: '日程調整 ・ ${_statusLabel(item.status)}',
                ),
              ),
          ...data.announcements
              .where((item) => item.status == 'archived')
              .map(
                (item) =>
                    _HistoryCard(title: item.title, subtitle: 'お知らせ ・ アーカイブ'),
              ),
          ...data.resources
              .where((item) => item.status == 'archived')
              .map(
                (item) =>
                    _HistoryCard(title: item.title, subtitle: '練習資料 ・ アーカイブ'),
              ),
        ],
      };

  Future<void> _reload() async {
    final next = widget.repository.fetchCrewActivity(widget.crew.crewId);
    setState(() {
      _load = next;
    });
    await next;
  }

  Future<void> _add() async {
    switch (widget.section) {
      case _CrewSection.practices:
        return _editPractice(null);
      case _CrewSection.polls:
        return _createPoll();
      case _CrewSection.announcements:
        return _editAnnouncement(null);
      case _CrewSection.resources:
        return _editResource(null);
      case _CrewSection.history:
        return _selectTarget();
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
      await _reload();
    } catch (error, stackTrace) {
      debugPrint('STAGE Crew activity update failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      final message = error is StageCrewResourceUrlException
          ? stageCrewResourceUrlErrorMessage
          : '更新できませんでした。時間をおいて再度お試しください。';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _editPractice(StageCrewPractice? item) async {
    final draft = await showDialog<_PracticeDraft>(
      context: context,
      builder: (_) => _PracticeDialog(initial: item),
    );
    if (draft == null) return;
    await _run(() async {
      await widget.repository.savePractice(
        crewId: widget.crew.crewId,
        practiceId: item?.practiceId,
        title: draft.title,
        startsAt: draft.startsAt,
        endsAt: draft.endsAt,
        locationName: draft.location,
        description: draft.description,
        attendanceDeadline: draft.startsAt.subtract(const Duration(days: 1)),
      );
    }, item == null ? '練習予定を作成しました' : '練習予定を更新しました');
  }

  Future<void> _cancelPractice(StageCrewPractice item) async {
    if (!await _confirm('この練習を中止しますか？', '出欠履歴は保持されます。')) return;
    await _run(
      () => widget.repository.setPracticeStatus(
        crewId: widget.crew.crewId,
        practiceId: item.practiceId,
        status: 'cancelled',
      ),
      '練習を中止しました',
    );
  }

  Future<void> _completePractice(StageCrewPractice item) async {
    if (!await _confirm('この練習を完了にしますか？', '出欠履歴はそのまま保持されます。')) {
      return;
    }
    await _run(
      () => widget.repository.setPracticeStatus(
        crewId: widget.crew.crewId,
        practiceId: item.practiceId,
        status: 'completed',
      ),
      '練習を完了しました',
    );
  }

  Future<void> _respondAttendance(StageCrewPractice item, String value) => _run(
    () => widget.repository.respondAttendance(
      crewId: widget.crew.crewId,
      practiceId: item.practiceId,
      response: value,
    ),
    '出欠を更新しました',
  );

  Future<void> _createPoll() async {
    final draft = await showDialog<_PollDraft>(
      context: context,
      builder: (_) => const _PollDialog(),
    );
    if (draft == null) return;
    await _run(() async {
      await widget.repository.createPoll(
        crewId: widget.crew.crewId,
        title: draft.title,
        options: draft.options,
      );
    }, '日程調整を公開しました');
  }

  Future<void> _respondPoll(StageCrewPoll poll, Map<String, String> values) =>
      _run(
        () => widget.repository.respondPoll(
          crewId: widget.crew.crewId,
          pollId: poll.pollId,
          responses: values,
        ),
        '回答を更新しました',
      );

  Future<void> _finalizePoll(StageCrewPoll poll, String optionId) async {
    if (!await _confirm('この候補で確定しますか？', '確定後は回答を変更できず、練習予定が1件作成されます。')) return;
    await _run(
      () => widget.repository.finalizePoll(
        crewId: widget.crew.crewId,
        pollId: poll.pollId,
        optionId: optionId,
      ),
      '日程を確定しました',
    );
  }

  Future<void> _cancelPoll(StageCrewPoll poll) async {
    if (!await _confirm('この日程調整を中止しますか？', 'これまでの回答は履歴として保持されます。')) return;
    await _run(
      () => widget.repository.cancelPoll(
        crewId: widget.crew.crewId,
        pollId: poll.pollId,
      ),
      '日程調整を中止しました',
    );
  }

  Future<void> _editAnnouncement(StageCrewAnnouncement? item) async {
    final draft = await showDialog<_TextDraft>(
      context: context,
      builder: (_) => _TextDialog(
        title: 'お知らせ',
        initialTitle: item?.title,
        initialBody: item?.body,
      ),
    );
    if (draft == null) return;
    await _run(() async {
      await widget.repository.saveAnnouncement(
        crewId: widget.crew.crewId,
        announcementId: item?.announcementId,
        title: draft.title,
        body: draft.body,
        status: 'published',
      );
    }, 'お知らせを保存しました');
  }

  Future<void> _openAnnouncement(StageCrewAnnouncement item) =>
      openStageCrewAnnouncementDetail(
        context,
        crewId: widget.crew.crewId,
        crewName: widget.crew.crewName,
        announcementId: item.announcementId,
        repository: widget.repository,
      );

  Future<void> _archiveAnnouncement(StageCrewAnnouncement item) async {
    await _run(() async {
      await widget.repository.saveAnnouncement(
        crewId: widget.crew.crewId,
        announcementId: item.announcementId,
        title: item.title,
        body: item.body ?? '',
        status: 'archived',
      );
    }, 'お知らせをアーカイブしました');
  }

  Future<void> _editResource(StageCrewResource? item) async {
    final draft = await showDialog<_ResourceDraft>(
      context: context,
      builder: (_) => _ResourceDialog(initial: item),
    );
    if (draft == null) return;
    await _run(() async {
      await widget.repository.saveResource(
        crewId: widget.crew.crewId,
        resourceId: item?.resourceId,
        title: draft.title,
        resourceType: draft.type,
        externalUrl: draft.url,
        description: draft.description,
        status: 'active',
      );
    }, '練習資料を保存しました');
  }

  Future<void> _archiveResource(StageCrewResource item) async {
    await _run(() async {
      await widget.repository.saveResource(
        crewId: widget.crew.crewId,
        resourceId: item.resourceId,
        title: item.title,
        resourceType: item.resourceType,
        externalUrl: item.externalUrl ?? '',
        description: item.description,
        status: 'archived',
      );
    }, '練習資料をアーカイブしました');
  }

  Future<void> _openResource(StageCrewResource item) async {
    final uri = item.safeExternalUri;
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('安全なHTTPSリンクではありません。')));
      return;
    }
    if (!await _confirm('${uri.host} を開きますか？', 'STAGEの外部サイトへ移動します。')) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('外部ページを開けませんでした。')));
    }
  }

  Future<void> _selectTarget() async {
    try {
      final events = await StageEventDiscoveryService().fetchPublishedEvents();
      if (!mounted) return;
      final selected = await showDialog<StageEvent>(
        context: context,
        builder: (_) => _EventPicker(events: events),
      );
      if (selected == null) return;
      await _run(() async {
        await widget.repository.setTargetEvent(
          crewId: widget.crew.crewId,
          eventId: selected.eventId,
        );
      }, '目標イベントを更新しました');
    } catch (error, stackTrace) {
      debugPrint('STAGE Crew target-event load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('イベントを読み込めませんでした。')));
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('続ける'),
            ),
          ],
        ),
      ) ??
      false;
}

class _CrewHero extends StatelessWidget {
  const _CrewHero({required this.home});
  final StageCrewHome home;
  @override
  Widget build(BuildContext context) => StageCard(
    gradient: StageDesignTokens.heroGradient,
    borderColor: Colors.transparent,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StageStatusBadge(label: home.isAdmin ? '管理中' : '参加中'),
        const SizedBox(height: StageDesignTokens.space12),
        Text(
          home.crewName,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: Colors.white),
        ),
        if (home.crewBio != null) ...[
          const SizedBox(height: StageDesignTokens.space8),
          Text(home.crewBio!, style: const TextStyle(color: Colors.white)),
        ],
      ],
    ),
  );
}

class _HomeEntry extends StatelessWidget {
  const _HomeEntry({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.detail,
  });
  final IconData icon;
  final String title;
  final String value;
  final String? detail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: StageDesignTokens.space12),
    child: StageCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: StageDesignTokens.purple),
          const SizedBox(width: StageDesignTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: StageDesignTokens.space4),
                Text(value),
                if (detail != null) ...[
                  const SizedBox(height: StageDesignTokens.space4),
                  Text(detail!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    ),
  );
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.snapshot});
  final StageCrewActivitySnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      if (snapshot.practices.isNotEmpty)
        '練習: ${snapshot.practices.first.title}',
      if (snapshot.polls.isNotEmpty) '日程調整: ${snapshot.polls.first.title}',
      if (snapshot.announcements.isNotEmpty)
        'お知らせ: ${snapshot.announcements.first.title}',
      if (snapshot.resources.isNotEmpty)
        '資料: ${snapshot.resources.first.title}',
    ];
    return StageCard(
      child: labels.isEmpty
          ? const Text('最近のクルー活動はありません')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: labels
                  .map(
                    (label) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: StageDesignTokens.space4,
                      ),
                      child: Text(label),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.item,
    required this.isAdmin,
    required this.onAttendance,
    required this.onEdit,
    required this.onComplete,
    required this.onCancel,
  });
  final StageCrewPractice item;
  final bool isAdmin;
  final ValueChanged<String> onAttendance;
  final VoidCallback onEdit;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: StageDesignTokens.space12),
    child: StageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StageStatusBadge(label: _statusLabel(item.status)),
            ],
          ),
          const SizedBox(height: StageDesignTokens.space8),
          Text(_dateTime(item.startsAt)),
          if (item.locationName != null) Text(item.locationName!),
          if (item.description != null) Text(item.description!),
          const SizedBox(height: StageDesignTokens.space8),
          Text(
            '参加 ${item.attendingCount} ・ 未定 ${item.maybeCount} ・ 不参加 ${item.notAttendingCount}',
          ),
          if (item.acceptsAttendance) ...[
            const SizedBox(height: StageDesignTokens.space8),
            Wrap(
              spacing: 8,
              children: [
                _ChoiceButton(
                  label: '参加',
                  selected: item.myAttendance == 'attending',
                  onTap: () => onAttendance('attending'),
                ),
                _ChoiceButton(
                  label: '未定',
                  selected: item.myAttendance == 'maybe',
                  onTap: () => onAttendance('maybe'),
                ),
                _ChoiceButton(
                  label: '不参加',
                  selected: item.myAttendance == 'not_attending',
                  onTap: () => onAttendance('not_attending'),
                ),
              ],
            ),
          ],
          if (isAdmin && item.status == 'scheduled') ...[
            const Divider(),
            Wrap(
              spacing: 8,
              children: [
                TextButton(onPressed: onEdit, child: const Text('編集')),
                TextButton(onPressed: onComplete, child: const Text('完了')),
                TextButton(onPressed: onCancel, child: const Text('中止')),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
  );
}

class _PollCard extends StatefulWidget {
  const _PollCard({
    required this.poll,
    required this.isAdmin,
    required this.onRespond,
    required this.onFinalize,
    required this.onCancel,
  });
  final StageCrewPoll poll;
  final bool isAdmin;
  final ValueChanged<Map<String, String>> onRespond;
  final ValueChanged<String> onFinalize;
  final VoidCallback onCancel;
  @override
  State<_PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<_PollCard> {
  late final Map<String, String> _responses = {
    for (final o in widget.poll.options)
      if (o.myResponse != null) o.optionId: o.myResponse!,
  };
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: StageDesignTokens.space12),
    child: StageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.poll.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StageStatusBadge(label: _statusLabel(widget.poll.status)),
            ],
          ),
          ...widget.poll.options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_dateTime(option.startsAt)),
                  Text(
                    '○ ${option.availableCount}　△ ${option.maybeCount}　× ${option.unavailableCount}',
                  ),
                  if (widget.poll.status == 'open')
                    Wrap(
                      spacing: 6,
                      children: [
                        _ChoiceButton(
                          label: '○',
                          selected: _responses[option.optionId] == 'available',
                          onTap: () => setState(
                            () => _responses[option.optionId] = 'available',
                          ),
                        ),
                        _ChoiceButton(
                          label: '△',
                          selected: _responses[option.optionId] == 'maybe',
                          onTap: () => setState(
                            () => _responses[option.optionId] = 'maybe',
                          ),
                        ),
                        _ChoiceButton(
                          label: '×',
                          selected:
                              _responses[option.optionId] == 'unavailable',
                          onTap: () => setState(
                            () => _responses[option.optionId] = 'unavailable',
                          ),
                        ),
                        if (widget.isAdmin)
                          TextButton(
                            onPressed: () => widget.onFinalize(option.optionId),
                            child: const Text('この日程で確定'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (widget.poll.status == 'open')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton(
                onPressed: _responses.isEmpty
                    ? null
                    : () => widget.onRespond(_responses),
                child: const Text('回答を送信'),
              ),
            ),
          if (widget.isAdmin && widget.poll.status == 'open')
            TextButton(
              onPressed: widget.onCancel,
              child: const Text('日程調整を中止'),
            ),
        ],
      ),
    ),
  );
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.item,
    required this.isAdmin,
    required this.onOpen,
    required this.onEdit,
    required this.onArchive,
  });
  final StageCrewAnnouncement item;
  final bool isAdmin;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: StageCard(
      key: ValueKey('stage-crew-announcement-card-${item.announcementId}'),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StageStatusBadge(label: _statusLabel(item.status)),
            ],
          ),
          if (item.body != null) ...[
            const SizedBox(height: 8),
            Text(item.body!),
          ],
          if (item.authorDisplayName != null)
            Text(
              '投稿: ${item.authorDisplayName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (isAdmin) ...[
            const Divider(),
            Wrap(
              spacing: 8,
              children: [
                TextButton(onPressed: onEdit, child: const Text('編集')),
                if (item.status != 'archived')
                  TextButton(onPressed: onArchive, child: const Text('アーカイブ')),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.item,
    required this.isAdmin,
    required this.onOpen,
    required this.onEdit,
    required this.onArchive,
  });
  final StageCrewResource item;
  final bool isAdmin;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: StageCard(
      onTap: item.status == 'active' ? onOpen : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StageStatusBadge(label: _statusLabel(item.status)),
            ],
          ),
          Text(_resourceType(item.resourceType)),
          if (item.safeExternalUri != null) Text(item.safeExternalUri!.host),
          if (item.description != null) Text(item.description!),
          if (isAdmin) ...[
            const Divider(),
            Wrap(
              spacing: 8,
              children: [
                TextButton(onPressed: onEdit, child: const Text('編集')),
                if (item.status != 'archived')
                  TextButton(onPressed: onArchive, child: const Text('アーカイブ')),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class _TargetCard extends StatelessWidget {
  const _TargetCard(this.target);
  final StageCrewTarget target;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: StageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  target.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StageStatusBadge(label: _statusLabel(target.status)),
            ],
          ),
          if (target.startsAt != null) Text(_dateTime(target.startsAt!)),
          if (target.venueName != null) Text(target.venueName!),
        ],
      ),
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: StageCard(
      color: StageDesignTokens.surfaceMuted,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.lock_outline),
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: StageCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: StageDesignTokens.error,
              ),
              const SizedBox(height: 8),
              Text(message),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('再試行')),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _PracticeDraft = ({
  String title,
  DateTime startsAt,
  DateTime endsAt,
  String? location,
  String? description,
});

class _PracticeDialog extends StatefulWidget {
  const _PracticeDialog({this.initial});
  final StageCrewPractice? initial;
  @override
  State<_PracticeDialog> createState() => _PracticeDialogState();
}

class _PracticeDialogState extends State<_PracticeDialog> {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _location = TextEditingController(
    text: widget.initial?.locationName,
  );
  late final _description = TextEditingController(
    text: widget.initial?.description,
  );
  late DateTime _start =
      widget.initial?.startsAt ?? DateTime.now().add(const Duration(days: 7));
  late DateTime _end =
      widget.initial?.endsAt ?? _start.add(const Duration(hours: 2));
  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? '練習予定を作成' : '練習予定を編集'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'タイトル'),
          ),
          TextField(
            controller: _location,
            decoration: const InputDecoration(labelText: '場所名・集合メモ'),
          ),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '内容'),
          ),
          ListTile(
            title: const Text('開始'),
            subtitle: Text(_dateTime(_start)),
            onTap: () => _pick(true),
          ),
          ListTile(
            title: const Text('終了'),
            subtitle: Text(_dateTime(_end)),
            onTap: () => _pick(false),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('キャンセル'),
      ),
      FilledButton(onPressed: _save, child: const Text('保存')),
    ],
  );
  Future<void> _pick(bool start) async {
    final current = start ? _start : _end;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: current,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (start) {
        _start = value;
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(hours: 2));
        }
      } else {
        _end = value;
      }
    });
  }

  void _save() {
    if (_title.text.trim().isEmpty || !_end.isAfter(_start)) return;
    Navigator.pop<_PracticeDraft>(context, (
      title: _title.text.trim(),
      startsAt: _start,
      endsAt: _end,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
    ));
  }
}

typedef _PollDraft = ({
  String title,
  List<({DateTime startsAt, DateTime endsAt})> options,
});

class _PollDialog extends StatefulWidget {
  const _PollDialog();
  @override
  State<_PollDialog> createState() => _PollDialogState();
}

class _PollDialogState extends State<_PollDialog> {
  final _title = TextEditingController();
  late final List<DateTime> _starts = List.generate(
    3,
    (i) => DateTime.now().add(Duration(days: 7 + i, hours: 2)),
  );
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('日程調整を作成'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'タイトル・目的'),
          ),
          ...List.generate(
            3,
            (i) => ListTile(
              title: Text('候補 ${i + 1}'),
              subtitle: Text(_dateTime(_starts[i])),
              onTap: () => _pick(i),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('キャンセル'),
      ),
      FilledButton(onPressed: _save, child: const Text('公開')),
    ],
  );
  Future<void> _pick(int i) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: _starts[i],
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_starts[i]),
    );
    if (time != null) {
      setState(
        () => _starts[i] = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    Navigator.pop<_PollDraft>(context, (
      title: _title.text.trim(),
      options: _starts
          .map((s) => (startsAt: s, endsAt: s.add(const Duration(hours: 2))))
          .toList(),
    ));
  }
}

typedef _TextDraft = ({String title, String body});

class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.title, this.initialTitle, this.initialBody});
  final String title;
  final String? initialTitle;
  final String? initialBody;
  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late final _body = TextEditingController(text: widget.initialBody);
  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'タイトル'),
          ),
          TextField(
            controller: _body,
            maxLines: 5,
            decoration: const InputDecoration(labelText: '本文'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('キャンセル'),
      ),
      FilledButton(
        onPressed: () {
          if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
          Navigator.pop<_TextDraft>(context, (
            title: _title.text.trim(),
            body: _body.text.trim(),
          ));
        },
        child: const Text('保存'),
      ),
    ],
  );
}

typedef _ResourceDraft = ({
  String title,
  String type,
  String url,
  String? description,
});

class _ResourceDialog extends StatefulWidget {
  const _ResourceDialog({this.initial});
  final StageCrewResource? initial;
  @override
  State<_ResourceDialog> createState() => _ResourceDialogState();
}

class _ResourceDialogState extends State<_ResourceDialog> {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _url = TextEditingController(text: widget.initial?.externalUrl);
  late final _description = TextEditingController(
    text: widget.initial?.description,
  );
  final _urlFocus = FocusNode();
  String? _urlError;
  late String _type = widget.initial?.resourceType ?? 'practice_video';
  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _description.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('stage-crew-resource-dialog'),
    title: const Text('練習資料'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('stage-crew-resource-title'),
            controller: _title,
            decoration: const InputDecoration(labelText: 'タイトル'),
          ),
          DropdownButtonFormField<String>(
            initialValue: _type,
            items: const [
              DropdownMenuItem(value: 'choreography', child: Text('振付参考')),
              DropdownMenuItem(value: 'practice_video', child: Text('練習動画')),
              DropdownMenuItem(value: 'music', child: Text('音楽')),
              DropdownMenuItem(value: 'document', child: Text('ドキュメント')),
              DropdownMenuItem(value: 'other', child: Text('その他')),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          TextField(
            key: const ValueKey('stage-crew-resource-url'),
            controller: _url,
            focusNode: _urlFocus,
            decoration: InputDecoration(
              labelText: 'HTTPS URL',
              errorText: _urlError,
            ),
            onChanged: (_) {
              if (_urlError == null) return;
              setState(() {
                _urlError = parseStageCrewResourceHttpsUri(_url.text) == null
                    ? stageCrewResourceUrlErrorMessage
                    : null;
              });
            },
          ),
          TextField(
            key: const ValueKey('stage-crew-resource-description'),
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '説明'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('キャンセル'),
      ),
      FilledButton(
        key: const ValueKey('stage-crew-resource-save'),
        onPressed: _save,
        child: const Text('保存'),
      ),
    ],
  );
  void _save() {
    final uri = parseStageCrewResourceHttpsUri(_url.text);
    if (uri == null) {
      setState(() => _urlError = stageCrewResourceUrlErrorMessage);
      _urlFocus.requestFocus();
      return;
    }
    if (_title.text.trim().isEmpty) {
      return;
    }
    Navigator.pop<_ResourceDraft>(context, (
      title: _title.text.trim(),
      type: _type,
      url: uri.toString(),
      description: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
    ));
  }
}

class _EventPicker extends StatelessWidget {
  const _EventPicker({required this.events});
  final List<StageEvent> events;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('目標イベントを選択'),
    content: SizedBox(
      width: 360,
      child: events.isEmpty
          ? const Text('選択できる公開イベントがありません')
          : ListView(
              shrinkWrap: true,
              children: events
                  .map(
                    (event) => ListTile(
                      title: Text(event.title),
                      subtitle: Text(_dateTime(event.startsAt)),
                      onTap: () => Navigator.pop(context, event),
                    ),
                  )
                  .toList(),
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('閉じる'),
      ),
    ],
  );
}

String _sectionTitle(_CrewSection section) => switch (section) {
  _CrewSection.practices => '練習予定',
  _CrewSection.polls => '日程調整',
  _CrewSection.announcements => 'お知らせ',
  _CrewSection.resources => '練習資料',
  _CrewSection.history => '活動履歴',
};
IconData _sectionIcon(_CrewSection section) => switch (section) {
  _CrewSection.practices => Icons.event_available_outlined,
  _CrewSection.polls => Icons.how_to_vote_outlined,
  _CrewSection.announcements => Icons.campaign_outlined,
  _CrewSection.resources => Icons.folder_open_outlined,
  _CrewSection.history => Icons.history_rounded,
};
String _statusLabel(String status) => switch (status) {
  'scheduled' => '予定',
  'cancelled' => '中止',
  'completed' => '完了',
  'open' => '受付中',
  'finalized' => '確定',
  'published' => '公開中',
  'draft' => '下書き',
  'active' => '利用中',
  'archived' => '履歴',
  _ => status,
};
String _attendanceLabel(String? value) => switch (value) {
  'attending' => '参加',
  'maybe' => '未定',
  'not_attending' => '不参加',
  _ => '出欠未回答',
};
String _resourceType(String value) => switch (value) {
  'choreography' => '振付参考',
  'practice_video' => '練習動画',
  'music' => '音楽',
  'document' => 'ドキュメント',
  _ => 'その他',
};
String _dateTime(DateTime value) =>
    '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

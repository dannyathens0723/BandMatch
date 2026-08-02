import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/stage_crew_management.dart';
import '../models/stage_my_crew.dart';
import '../services/stage_crew_management_service.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';

class StageCrewEditorScreen extends StatefulWidget {
  const StageCrewEditorScreen({
    required this.repository,
    super.key,
    this.initialCrew,
  });

  final StageCrewManagementRepository repository;
  final StageManagedCrew? initialCrew;

  @override
  State<StageCrewEditorScreen> createState() => _StageCrewEditorScreenState();
}

class _StageCrewEditorScreenState extends State<StageCrewEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late Future<StageCrewFormOptions> _options;
  final Set<String> _genreIds = {};
  String? _areaId;
  String? _frequency;
  bool _saving = false;

  bool get _editing => widget.initialCrew != null;

  @override
  void initState() {
    super.initState();
    final crew = widget.initialCrew;
    _name = TextEditingController(text: crew?.name ?? '');
    _bio = TextEditingController(text: crew?.bio ?? '');
    _genreIds.addAll(crew?.danceGenreIds ?? const []);
    _areaId = crew?.areaId;
    _frequency = crew?.activityFrequency;
    _options = widget.repository.fetchFormOptions();
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StageMobilePageFrame(
      child: Scaffold(
        key: const ValueKey('stage-crew-editor-screen'),
        appBar: AppBar(title: Text(_editing ? 'クルーを編集' : 'クルーを作成')),
        body: FutureBuilder<StageCrewFormOptions>(
          future: _options,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _LoadError(onRetry: _retryOptions);
            }
            final options = snapshot.data!;
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(StageDesignTokens.space16),
                children: [
                  const _FormIntro(
                    title: 'あなたのクルーを形にしよう',
                    text: '活動内容とダンスジャンルを登録します。',
                  ),
                  const SizedBox(height: StageDesignTokens.space16),
                  TextFormField(
                    key: const ValueKey('stage-crew-name'),
                    controller: _name,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: 'クルー名 *'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'クルー名を入力してください'
                        : null,
                  ),
                  const SizedBox(height: StageDesignTokens.space12),
                  TextFormField(
                    key: const ValueKey('stage-crew-bio'),
                    controller: _bio,
                    maxLength: 1000,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: '紹介文'),
                  ),
                  const SizedBox(height: StageDesignTokens.space16),
                  const _FieldLabel('ダンスジャンル *'),
                  const SizedBox(height: StageDesignTokens.space8),
                  _OptionChips(
                    options: options.genres,
                    selectedIds: _genreIds,
                    onChanged: (id, selected) => setState(() {
                      selected ? _genreIds.add(id) : _genreIds.remove(id);
                    }),
                  ),
                  if (_genreIds.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: StageDesignTokens.space8),
                      child: Text(
                        '1つ以上選択してください',
                        key: ValueKey('stage-crew-genre-validation'),
                        style: TextStyle(color: StageDesignTokens.error),
                      ),
                    ),
                  const SizedBox(height: StageDesignTokens.space16),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('stage-crew-frequency'),
                    initialValue: _frequency,
                    decoration: const InputDecoration(labelText: '活動頻度'),
                    items: const [
                      DropdownMenuItem(
                        value: 'monthly_1_2',
                        child: Text('月1〜2回'),
                      ),
                      DropdownMenuItem(
                        value: 'weekly_1_2',
                        child: Text('週1〜2回'),
                      ),
                      DropdownMenuItem(value: 'daily', child: Text('ほぼ毎日')),
                    ],
                    onChanged: (value) => _frequency = value,
                  ),
                  if (options.areas.isNotEmpty) ...[
                    const SizedBox(height: StageDesignTokens.space16),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('stage-crew-area'),
                      initialValue: _areaId,
                      decoration: const InputDecoration(labelText: '活動エリア（任意）'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('指定しない'),
                        ),
                        ...options.areas.map(
                          (area) => DropdownMenuItem(
                            value: area.id,
                            child: Text(area.name),
                          ),
                        ),
                      ],
                      onChanged: (value) => _areaId = value,
                    ),
                  ],
                  const SizedBox(height: StageDesignTokens.space24),
                  StagePrimaryButton(
                    label: _saving ? '保存中…' : '入力内容を確認',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _saving ? null : () => _confirm(options),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _retryOptions() => setState(() {
    _options = widget.repository.fetchFormOptions();
  });

  Future<void> _confirm(StageCrewFormOptions options) async {
    if (!_formKey.currentState!.validate() || _genreIds.isEmpty) {
      setState(() {});
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmationDialog(
        title: _editing ? '変更内容を確認' : 'クルー作成を確認',
        rows: {
          'クルー名': _name.text.trim(),
          'ジャンル': options.genres
              .where((item) => _genreIds.contains(item.id))
              .map((item) => item.name)
              .join('・'),
          '活動頻度': _frequencyLabel(_frequency),
          '活動エリア':
              options.areas
                  .where((item) => item.id == _areaId)
                  .map((item) => item.name)
                  .firstOrNull ??
              '指定なし',
        },
        actionLabel: _editing ? '保存する' : '作成する',
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      if (_editing) {
        await widget.repository.updateCrew(
          crewId: widget.initialCrew!.crewId,
          name: _name.text,
          bio: _bio.text,
          activityFrequency: _frequency,
          genreIds: _genreIds.toList(growable: false),
          areaId: _areaId,
        );
      } else {
        await widget.repository.createCrew(
          name: _name.text,
          bio: _bio.text,
          activityFrequency: _frequency,
          genreIds: _genreIds.toList(growable: false),
          areaId: _areaId,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      _log('Crew save', error, stackTrace);
      if (mounted) {
        _showError(context, 'クルーを保存できませんでした。時間をおいて再度お試しください。');
        setState(() => _saving = false);
      }
    }
  }
}

class StageManagedCrewScreen extends StatefulWidget {
  const StageManagedCrewScreen({
    required this.crew,
    required this.repository,
    super.key,
  });

  final StageMyCrew crew;
  final StageCrewManagementRepository repository;

  @override
  State<StageManagedCrewScreen> createState() => _StageManagedCrewScreenState();
}

class _StageManagedCrewScreenState extends State<StageManagedCrewScreen> {
  _ManagedCrewData? _data;
  Object? _loadError;
  bool _loading = true;
  int _loadEpoch = 0;

  @override
  void initState() {
    super.initState();
    _reload(showLoading: false);
  }

  Future<void> _reload({bool showLoading = true}) async {
    final epoch = ++_loadEpoch;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        widget.repository.fetchManagedCrew(widget.crew.crewId),
        widget.repository.fetchRecruitments(widget.crew.crewId),
      ]);
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _data = _ManagedCrewData(
          crew: results[0] as StageManagedCrew,
          recruitments: results[1] as List<StageManagedRecruitment>,
        );
        _loadError = null;
        _loading = false;
      });
    } catch (error, stackTrace) {
      _log('Managed Crew refresh', error, stackTrace);
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_loading) {
      body = const Center(
        key: ValueKey('stage-managed-crew-loading'),
        child: CircularProgressIndicator(),
      );
    } else if (_loadError != null) {
      body = _LoadError(
        key: const ValueKey('stage-managed-crew-error'),
        onRetry: () => _reload(),
      );
    } else {
      final data = _data!;
      body = ListView(
        padding: const EdgeInsets.all(StageDesignTokens.space16),
        children: [
          StageCard(
            gradient: StageDesignTokens.heroGradient,
            borderColor: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StageStatusBadge(label: '管理者'),
                const SizedBox(height: StageDesignTokens.space12),
                Text(
                  data.crew.name,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                if (data.crew.bio != null) ...[
                  const SizedBox(height: StageDesignTokens.space8),
                  Text(
                    data.crew.bio!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: StageDesignTokens.space12),
          Wrap(
            spacing: StageDesignTokens.space8,
            runSpacing: StageDesignTokens.space8,
            children: [
              ...data.crew.danceGenreNames.map(StageTag.new),
              if (data.crew.areaName != null) StageTag(data.crew.areaName!),
            ],
          ),
          const SizedBox(height: StageDesignTokens.space16),
          Row(
            children: [
              Expanded(
                child: StageOutlinedButton(
                  label: 'クルーを編集',
                  icon: Icons.edit_outlined,
                  onPressed: () => _editCrew(data.crew),
                ),
              ),
              const SizedBox(width: StageDesignTokens.space8),
              Expanded(
                child: StagePrimaryButton(
                  label: '募集を作成',
                  icon: Icons.add_rounded,
                  onPressed: () => _createRecruitment(data.crew),
                ),
              ),
            ],
          ),
          StageSectionHeader(
            title: '募集投稿',
            actionLabel: '更新',
            onAction: () => _reload(),
          ),
          if (data.recruitments.isEmpty)
            const StageEmptyState(
              key: ValueKey('stage-managed-recruitment-empty'),
              icon: Icons.campaign_outlined,
              title: '募集投稿はまだありません',
              message: '募集を作成すると、クルーを探している人に表示されます。',
            )
          else
            ...data.recruitments.map(
              (post) => Padding(
                padding: const EdgeInsets.only(
                  bottom: StageDesignTokens.space12,
                ),
                child: _ManagedRecruitmentCard(
                  post: post,
                  onTap: () => _openRecruitment(post),
                ),
              ),
            ),
        ],
      );
    }
    return StageMobilePageFrame(
      child: Scaffold(
        key: const ValueKey('stage-managed-crew-screen'),
        appBar: AppBar(title: const Text('管理中のクルー')),
        body: body,
      ),
    );
  }

  Future<void> _editCrew(StageManagedCrew crew) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StageCrewEditorScreen(
          repository: widget.repository,
          initialCrew: crew,
        ),
      ),
    );
    if (changed == true && mounted) await _reload();
  }

  Future<void> _createRecruitment(StageManagedCrew crew) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StageRecruitmentEditorScreen(
          crew: crew,
          repository: widget.repository,
        ),
      ),
    );
    if (changed == true && mounted) await _reload();
  }

  Future<void> _openRecruitment(StageManagedRecruitment post) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StageRecruitmentManagementScreen(
          post: post,
          repository: widget.repository,
        ),
      ),
    );
    if (changed == true && mounted) await _reload();
  }
}

class StageRecruitmentEditorScreen extends StatefulWidget {
  const StageRecruitmentEditorScreen({
    required this.crew,
    required this.repository,
    super.key,
    this.initialPost,
  });

  final StageManagedCrew crew;
  final StageCrewManagementRepository repository;
  final StageManagedRecruitment? initialPost;

  @override
  State<StageRecruitmentEditorScreen> createState() =>
      _StageRecruitmentEditorScreenState();
}

class _StageRecruitmentEditorScreenState
    extends State<StageRecruitmentEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _body;
  late Future<StageCrewFormOptions> _options;
  final Set<String> _genreIds = {};
  String? _areaId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialPost?.title ?? '');
    _body = TextEditingController(text: widget.initialPost?.body ?? '');
    _genreIds.addAll(
      widget.initialPost?.danceGenreIds ?? widget.crew.danceGenreIds,
    );
    _areaId = widget.initialPost?.areaId ?? widget.crew.areaId;
    _options = widget.repository.fetchFormOptions();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialPost != null;
    return StageMobilePageFrame(
      child: Scaffold(
        key: const ValueKey('stage-recruitment-editor-screen'),
        appBar: AppBar(title: Text(editing ? '募集を編集' : '募集を作成')),
        body: FutureBuilder<StageCrewFormOptions>(
          future: _options,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _LoadError(
                onRetry: () => setState(
                  () => _options = widget.repository.fetchFormOptions(),
                ),
              );
            }
            final options = snapshot.data!;
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(StageDesignTokens.space16),
                children: [
                  _FormIntro(
                    title: widget.crew.name,
                    text: '新しい仲間に伝わる募集内容を作成します。',
                  ),
                  const SizedBox(height: StageDesignTokens.space16),
                  TextFormField(
                    key: const ValueKey('stage-recruitment-title'),
                    controller: _title,
                    maxLength: 80,
                    decoration: const InputDecoration(labelText: '募集タイトル *'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '募集タイトルを入力してください'
                        : null,
                  ),
                  const SizedBox(height: StageDesignTokens.space12),
                  TextFormField(
                    key: const ValueKey('stage-recruitment-body'),
                    controller: _body,
                    maxLength: 2000,
                    maxLines: 7,
                    decoration: const InputDecoration(labelText: '募集内容 *'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '募集内容を入力してください'
                        : null,
                  ),
                  const _FieldLabel('ダンスジャンル *'),
                  const SizedBox(height: StageDesignTokens.space8),
                  _OptionChips(
                    options: options.genres,
                    selectedIds: _genreIds,
                    onChanged: (id, selected) => setState(() {
                      selected ? _genreIds.add(id) : _genreIds.remove(id);
                    }),
                  ),
                  if (options.areas.isNotEmpty) ...[
                    const SizedBox(height: StageDesignTokens.space16),
                    DropdownButtonFormField<String>(
                      initialValue: _areaId,
                      decoration: const InputDecoration(labelText: '活動エリア（任意）'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('指定しない'),
                        ),
                        ...options.areas.map(
                          (area) => DropdownMenuItem(
                            value: area.id,
                            child: Text(area.name),
                          ),
                        ),
                      ],
                      onChanged: (value) => _areaId = value,
                    ),
                  ],
                  const SizedBox(height: StageDesignTokens.space24),
                  StagePrimaryButton(
                    label: _saving ? '公開中…' : '入力内容を確認',
                    onPressed: _saving ? null : () => _confirm(options),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirm(StageCrewFormOptions options) async {
    if (!_formKey.currentState!.validate() || _genreIds.isEmpty) {
      setState(() {});
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmationDialog(
        title: widget.initialPost == null ? '募集公開を確認' : '募集変更を確認',
        rows: {
          'タイトル': _title.text.trim(),
          'ジャンル': options.genres
              .where((item) => _genreIds.contains(item.id))
              .map((item) => item.name)
              .join('・'),
        },
        actionLabel: widget.initialPost == null ? '公開する' : '保存する',
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      if (widget.initialPost == null) {
        await widget.repository.createRecruitment(
          crewId: widget.crew.crewId,
          title: _title.text,
          body: _body.text,
          genreIds: _genreIds.toList(growable: false),
          areaId: _areaId,
        );
      } else {
        await widget.repository.updateRecruitment(
          postId: widget.initialPost!.postId,
          title: _title.text,
          body: _body.text,
          genreIds: _genreIds.toList(growable: false),
          areaId: _areaId,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      _log('Recruitment save', error, stackTrace);
      if (mounted) {
        _showError(context, '募集を保存できませんでした。時間をおいて再度お試しください。');
        setState(() => _saving = false);
      }
    }
  }
}

class StageRecruitmentManagementScreen extends StatefulWidget {
  const StageRecruitmentManagementScreen({
    required this.post,
    required this.repository,
    super.key,
  });

  final StageManagedRecruitment post;
  final StageCrewManagementRepository repository;

  @override
  State<StageRecruitmentManagementScreen> createState() =>
      _StageRecruitmentManagementScreenState();
}

class _StageRecruitmentManagementScreenState
    extends State<StageRecruitmentManagementScreen> {
  late StageManagedRecruitment _post = widget.post;
  bool _changingStatus = false;
  bool _changed = false;

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_changed || result == true);
      },
      child: StageMobilePageFrame(
        child: Scaffold(
          key: const ValueKey('stage-recruitment-management-screen'),
          appBar: AppBar(title: const Text('募集管理')),
          body: ListView(
            padding: const EdgeInsets.all(StageDesignTokens.space16),
            children: [
              StageCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StageStatusBadge(
                      label: _post.isOpen ? '募集中' : '募集終了',
                      color: _post.isOpen
                          ? StageDesignTokens.success
                          : StageDesignTokens.textMuted,
                    ),
                    const SizedBox(height: StageDesignTokens.space12),
                    Text(
                      _post.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: StageDesignTokens.space8),
                    Text(_post.body),
                    const SizedBox(height: StageDesignTokens.space12),
                    Wrap(
                      spacing: StageDesignTokens.space8,
                      children: _post.danceGenreNames
                          .map(StageTag.new)
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: StageDesignTokens.space16),
              StagePrimaryButton(
                key: const ValueKey('stage-open-applicants'),
                label: '応募者一覧（${_post.pendingApplicationCount}）',
                icon: Icons.people_outline_rounded,
                onPressed: _openApplicants,
              ),
              const SizedBox(height: StageDesignTokens.space8),
              StageOutlinedButton(
                label: '募集内容を編集',
                icon: Icons.edit_outlined,
                onPressed: _edit,
              ),
              const SizedBox(height: StageDesignTokens.space8),
              StageOutlinedButton(
                label: _changingStatus
                    ? '更新中…'
                    : (_post.isOpen ? '募集を終了' : '募集を再開'),
                icon: _post.isOpen ? Icons.stop_circle_outlined : Icons.refresh,
                onPressed: _changingStatus ? null : _toggleStatus,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<StageManagedCrew> _crew() =>
      widget.repository.fetchManagedCrew(_post.crewId);

  Future<void> _edit() async {
    final crew = await _crew();
    if (!mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StageRecruitmentEditorScreen(
          crew: crew,
          repository: widget.repository,
          initialPost: _post,
        ),
      ),
    );
    if (changed == true) {
      _changed = true;
      await _refreshPost();
    }
  }

  Future<void> _refreshPost() async {
    final posts = await widget.repository.fetchRecruitments(_post.crewId);
    final refreshed = posts.where((item) => item.postId == _post.postId).first;
    if (mounted) setState(() => _post = refreshed);
  }

  Future<void> _toggleStatus() async {
    setState(() => _changingStatus = true);
    try {
      await widget.repository.setRecruitmentStatus(
        _post.postId,
        _post.isOpen ? 'closed' : 'open',
      );
      _changed = true;
      await _refreshPost();
    } catch (error, stackTrace) {
      _log('Recruitment status', error, stackTrace);
      if (mounted) _showError(context, '募集状態を更新できませんでした。');
    } finally {
      if (mounted) setState(() => _changingStatus = false);
    }
  }

  Future<void> _openApplicants() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StageRecruitmentApplicantsScreen(
          post: _post,
          repository: widget.repository,
        ),
      ),
    );
    _changed = true;
    await _refreshPost();
  }
}

class StageRecruitmentApplicantsScreen extends StatefulWidget {
  const StageRecruitmentApplicantsScreen({
    required this.post,
    required this.repository,
    super.key,
  });

  final StageManagedRecruitment post;
  final StageCrewManagementRepository repository;

  @override
  State<StageRecruitmentApplicantsScreen> createState() =>
      _StageRecruitmentApplicantsScreenState();
}

class _StageRecruitmentApplicantsScreenState
    extends State<StageRecruitmentApplicantsScreen> {
  late Future<List<StageRecruitmentApplicant>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchApplicants(widget.post.postId);
  }

  void _reload() => setState(() {
    _future = widget.repository.fetchApplicants(widget.post.postId);
  });

  @override
  Widget build(BuildContext context) {
    return StageMobilePageFrame(
      child: Scaffold(
        key: const ValueKey('stage-recruitment-applicants-screen'),
        appBar: AppBar(title: const Text('応募者一覧')),
        body: FutureBuilder<List<StageRecruitmentApplicant>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return _LoadError(onRetry: _reload);
            final applicants = snapshot.data!;
            if (applicants.isEmpty) {
              return const StageEmptyState(
                icon: Icons.person_search_outlined,
                title: '応募者はまだいません',
                message: '応募が届くと、ここからプロフィールとメッセージを確認できます。',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(StageDesignTokens.space16),
              itemCount: applicants.length,
              itemBuilder: (context, index) {
                final applicant = applicants[index];
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: StageDesignTokens.space12,
                  ),
                  child: StageCard(
                    key: ValueKey('stage-applicant-${applicant.applicationId}'),
                    onTap: () => _open(applicant),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: applicant.avatarUrl == null
                              ? null
                              : NetworkImage(applicant.avatarUrl!),
                          child: applicant.avatarUrl == null
                              ? const Icon(Icons.person_outline)
                              : null,
                        ),
                        const SizedBox(width: StageDesignTokens.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                applicant.displayName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(applicant.performanceRoleNames.join('・')),
                            ],
                          ),
                        ),
                        StageStatusBadge(
                          label: _applicationStatusLabel(
                            applicant.applicationStatus,
                          ),
                          color: _applicationStatusColor(
                            applicant.applicationStatus,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _open(StageRecruitmentApplicant applicant) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StageRecruitmentApplicantDetailScreen(
          applicant: applicant,
          repository: widget.repository,
        ),
      ),
    );
    _reload();
  }
}

class StageRecruitmentApplicantDetailScreen extends StatefulWidget {
  const StageRecruitmentApplicantDetailScreen({
    required this.applicant,
    required this.repository,
    super.key,
  });

  final StageRecruitmentApplicant applicant;
  final StageCrewManagementRepository repository;

  @override
  State<StageRecruitmentApplicantDetailScreen> createState() =>
      _StageRecruitmentApplicantDetailScreenState();
}

class _StageRecruitmentApplicantDetailScreenState
    extends State<StageRecruitmentApplicantDetailScreen> {
  late StageRecruitmentApplicant _applicant = widget.applicant;
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    return StageMobilePageFrame(
      child: Scaffold(
        key: const ValueKey('stage-applicant-detail-screen'),
        appBar: AppBar(title: const Text('応募者詳細')),
        body: ListView(
          padding: const EdgeInsets.all(StageDesignTokens.space16),
          children: [
            StageCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _applicant.displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: StageDesignTokens.space8),
                  Wrap(
                    spacing: StageDesignTokens.space8,
                    runSpacing: StageDesignTokens.space8,
                    children: [
                      ..._applicant.danceGenreNames.map(StageTag.new),
                      ..._applicant.performanceRoleNames.map(StageTag.new),
                    ],
                  ),
                  const SizedBox(height: StageDesignTokens.space16),
                  const _FieldLabel('応募メッセージ'),
                  const SizedBox(height: StageDesignTokens.space8),
                  Text(_applicant.applicationNote ?? 'メッセージはありません'),
                ],
              ),
            ),
            const SizedBox(height: StageDesignTokens.space16),
            if (_applicant.isPending) ...[
              StagePrimaryButton(
                key: const ValueKey('stage-accept-application'),
                label: _processing ? '処理中…' : '承認する',
                icon: Icons.check_circle_outline,
                onPressed: _processing ? null : () => _decide('accepted'),
              ),
              const SizedBox(height: StageDesignTokens.space8),
              StageOutlinedButton(
                key: const ValueKey('stage-reject-application'),
                label: '見送る',
                icon: Icons.close_rounded,
                onPressed: _processing ? null : () => _decide('rejected'),
              ),
            ] else
              StageCard(
                color: StageDesignTokens.surfaceMuted,
                child: Text(
                  'この応募は${_applicationStatusLabel(_applicant.applicationStatus)}です。',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(String decision) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(decision == 'accepted' ? '応募を承認しますか？' : '応募を見送りますか？'),
        content: Text(
          decision == 'accepted'
              ? '承認すると、このユーザーがクルーメンバーになります。'
              : '応募履歴は見送りとして保存されます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _processing = true);
    try {
      final result = await widget.repository.decideApplication(
        _applicant.applicationId,
        decision,
      );
      if (mounted) {
        setState(() {
          _applicant = StageRecruitmentApplicant(
            applicationId: _applicant.applicationId,
            postId: _applicant.postId,
            crewId: _applicant.crewId,
            applicantUserId: _applicant.applicantUserId,
            displayName: _applicant.displayName,
            avatarUrl: _applicant.avatarUrl,
            experienceLevel: _applicant.experienceLevel,
            danceGenreNames: _applicant.danceGenreNames,
            performanceRoleNames: _applicant.performanceRoleNames,
            primaryPerformanceRoleName: _applicant.primaryPerformanceRoleName,
            applicationNote: _applicant.applicationNote,
            applicationStatus: result.applicationStatus,
            appliedAt: _applicant.appliedAt,
            respondedAt: DateTime.now(),
          );
          _processing = false;
        });
      }
    } catch (error, stackTrace) {
      _log('Application decision', error, stackTrace);
      if (mounted) {
        _showError(context, '応募を処理できませんでした。最新状態を確認して再度お試しください。');
        setState(() => _processing = false);
      }
    }
  }
}

class _ManagedCrewData {
  const _ManagedCrewData({required this.crew, required this.recruitments});
  final StageManagedCrew crew;
  final List<StageManagedRecruitment> recruitments;
}

class _ManagedRecruitmentCard extends StatelessWidget {
  const _ManagedRecruitmentCard({required this.post, required this.onTap});
  final StageManagedRecruitment post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => StageCard(
    key: ValueKey('stage-managed-recruitment-${post.postId}'),
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                post.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            StageStatusBadge(
              label: post.isOpen ? '募集中' : '終了',
              color: post.isOpen
                  ? StageDesignTokens.success
                  : StageDesignTokens.textMuted,
            ),
          ],
        ),
        const SizedBox(height: StageDesignTokens.space8),
        Text('確認中の応募 ${post.pendingApplicationCount}件'),
      ],
    ),
  );
}

class _OptionChips extends StatelessWidget {
  const _OptionChips({
    required this.options,
    required this.selectedIds,
    required this.onChanged,
  });
  final List<StageCrewOption> options;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: StageDesignTokens.space8,
    runSpacing: StageDesignTokens.space8,
    children: options
        .map(
          (option) => FilterChip(
            key: ValueKey('stage-option-${option.id}'),
            label: Text(option.name),
            selected: selectedIds.contains(option.id),
            onSelected: (selected) => onChanged(option.id, selected),
          ),
        )
        .toList(growable: false),
  );
}

class _FormIntro extends StatelessWidget {
  const _FormIntro({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => StageCard(
    gradient: StageDesignTokens.heroGradient,
    borderColor: Colors.transparent,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: StageDesignTokens.space4),
        Text(text, style: const TextStyle(color: Colors.white)),
      ],
    ),
  );
}

class _ConfirmationDialog extends StatelessWidget {
  const _ConfirmationDialog({
    required this.title,
    required this.rows,
    required this.actionLabel,
  });
  final String title;
  final Map<String, String> rows;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('stage-confirmation-dialog'),
    title: Text(title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows.entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: StageDesignTokens.space8),
              child: Text('${entry.key}: ${entry.value}'),
            ),
          )
          .toList(growable: false),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('戻って修正'),
      ),
      FilledButton(
        key: const ValueKey('stage-confirm-submit'),
        onPressed: () => Navigator.pop(context, true),
        child: Text(actionLabel),
      ),
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleMedium);
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry, super.key});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(StageDesignTokens.space24),
      child: StageCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('情報を読み込めませんでした。時間をおいて再度お試しください。'),
            const SizedBox(height: StageDesignTokens.space12),
            OutlinedButton(onPressed: onRetry, child: const Text('再試行')),
          ],
        ),
      ),
    ),
  );
}

String _frequencyLabel(String? value) => switch (value) {
  'monthly_1_2' => '月1〜2回',
  'weekly_1_2' => '週1〜2回',
  'daily' => 'ほぼ毎日',
  _ => '未設定',
};

String _applicationStatusLabel(String value) => switch (value) {
  'pending' => '確認中',
  'accepted' => '承認済み',
  'rejected' => '見送り',
  _ => '確認中',
};

Color _applicationStatusColor(String value) => switch (value) {
  'accepted' => StageDesignTokens.success,
  'rejected' => StageDesignTokens.textMuted,
  _ => StageDesignTokens.purple,
};

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void _log(String operation, Object error, StackTrace stackTrace) {
  if (!kDebugMode) return;
  debugPrint('STAGE $operation failed: $error');
  debugPrintStack(stackTrace: stackTrace);
}

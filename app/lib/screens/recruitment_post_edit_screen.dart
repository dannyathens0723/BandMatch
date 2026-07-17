import 'package:flutter/material.dart';

import '../models/master_data_item.dart';
import '../models/my_group_profile.dart';
import '../models/recruitment_post.dart';
import '../services/master_data_service.dart';
import '../services/recruitment_post_service.dart';

class RecruitmentPostEditScreen extends StatefulWidget {
  const RecruitmentPostEditScreen({super.key, required this.group, this.post});

  final MyGroupProfile group;
  final RecruitmentPost? post;

  @override
  State<RecruitmentPostEditScreen> createState() =>
      _RecruitmentPostEditScreenState();
}

class _RecruitmentPostEditScreenState extends State<RecruitmentPostEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _service = RecruitmentPostService();
  final _partIds = <String>{};
  final _genreIds = <String>{};
  final _areaIds = <String>{};
  late Future<MasterData> _masterData;
  String _status = 'open';
  bool _isSaving = false;

  bool get _isEditing => widget.post != null;

  @override
  void initState() {
    super.initState();
    final post = widget.post;
    if (post != null) {
      _titleController.text = post.title;
      _bodyController.text = post.body;
      _status = post.status;
      _partIds.addAll(post.wantedPartIds);
      _genreIds.addAll(post.genreIds);
      _areaIds.addAll(post.areaIds);
    } else {
      _partIds.addAll(widget.group.recruitingPartIds);
      _genreIds.addAll(widget.group.genreIds);
      _areaIds.addAll(widget.group.areaIds);
    }
    _masterData = MasterDataService().fetchActiveMasterData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save(MasterData masterData) async {
    if (_isSaving) return;

    final isValid =
        _formKey.currentState!.validate() &&
        _partIds.isNotEmpty &&
        _genreIds.isNotEmpty &&
        (masterData.areas.isEmpty || _areaIds.isNotEmpty);

    if (!isValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未入力の必須項目があります')));
      return;
    }

    setState(() => _isSaving = true);
    final data = RecruitmentPostEditData(
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      status: _status,
      wantedPartIds: Set<String>.from(_partIds),
      genreIds: Set<String>.from(_genreIds),
      areaIds: Set<String>.from(_areaIds),
    );

    try {
      final post = widget.post;
      if (post == null) {
        await _service.createPost(widget.group.id, data);
        if (!mounted) return;
        Navigator.of(context).pop('created');
      } else {
        await _service.updatePost(post.id, data);
        if (!mounted) return;
        Navigator.of(context).pop('updated');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('募集投稿を保存できませんでした。時間をおいて再度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '募集投稿を編集' : '募集を作成')),
      body: SafeArea(
        top: false,
        child: FutureBuilder<MasterData>(
          future: _masterData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _RecruitmentPostEditLoadError(
                onRetry: () => setState(
                  () =>
                      _masterData = MasterDataService().fetchActiveMasterData(),
                ),
              );
            }

            final masterData = snapshot.requireData;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Form(
                    key: _formKey,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.group.name,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isEditing ? '募集投稿を編集' : '新しい募集投稿を作成',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _titleController,
                              enabled: !_isSaving,
                              maxLength: 80,
                              decoration: const InputDecoration(
                                labelText: 'タイトル',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final title = value?.trim() ?? '';
                                if (title.isEmpty) {
                                  return 'タイトルを入力してください。';
                                }
                                if (title.length > 80) {
                                  return 'タイトルは80文字以内で入力してください。';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _bodyController,
                              enabled: !_isSaving,
                              maxLength: 2000,
                              minLines: 6,
                              maxLines: 12,
                              decoration: const InputDecoration(
                                labelText: '募集内容',
                                alignLabelWithHint: true,
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final body = value?.trim() ?? '';
                                if (body.isEmpty) {
                                  return '募集内容を入力してください。';
                                }
                                if (body.length > 2000) {
                                  return '募集内容は2000文字以内で入力してください。';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _status,
                              decoration: const InputDecoration(
                                labelText: 'ステータス',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'draft',
                                  child: Text('下書き'),
                                ),
                                DropdownMenuItem(
                                  value: 'open',
                                  child: Text('公開中'),
                                ),
                                DropdownMenuItem(
                                  value: 'closed',
                                  child: Text('終了'),
                                ),
                              ],
                              onChanged: _isSaving
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      setState(() => _status = value);
                                    },
                            ),
                            const SizedBox(height: 24),
                            _MasterDataChips(
                              title: '募集パート',
                              hint: '1つ以上選択してください',
                              items: masterData.parts,
                              selectedIds: _partIds,
                              enabled: !_isSaving,
                              onChanged: () => setState(() {}),
                            ),
                            const SizedBox(height: 24),
                            _MasterDataChips(
                              title: 'ジャンル',
                              hint: '1つ以上選択してください',
                              items: masterData.genres,
                              selectedIds: _genreIds,
                              enabled: !_isSaving,
                              onChanged: () => setState(() {}),
                            ),
                            if (masterData.areas.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              _MasterDataChips(
                                title: '活動エリア',
                                hint: '1つ以上選択してください',
                                items: masterData.areas,
                                selectedIds: _areaIds,
                                enabled: !_isSaving,
                                onChanged: () => setState(() {}),
                              ),
                            ],
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _isSaving
                                    ? null
                                    : () => _save(masterData),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(_isEditing ? '変更を保存' : '募集を作成'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _MasterDataChips extends StatelessWidget {
  const _MasterDataChips({
    required this.title,
    required this.hint,
    required this.items,
    required this.selectedIds,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String hint;
  final List<MasterDataItem> items;
  final Set<String> selectedIds;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(hint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            return FilterChip(
              label: Text(item.name),
              selected: selectedIds.contains(item.id),
              onSelected: !enabled
                  ? null
                  : (selected) {
                      if (selected) {
                        selectedIds.add(item.id);
                      } else {
                        selectedIds.remove(item.id);
                      }
                      onChanged();
                    },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _RecruitmentPostEditLoadError extends StatelessWidget {
  const _RecruitmentPostEditLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 44),
              const SizedBox(height: 16),
              const Text('募集投稿に必要なデータを読み込めませんでした。'),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
            ],
          ),
        ),
      ),
    );
  }
}

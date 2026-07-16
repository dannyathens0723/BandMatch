import 'package:flutter/material.dart';

import '../models/master_data_item.dart';
import '../models/my_group_profile.dart';
import '../services/group_profile_service.dart';
import '../services/master_data_service.dart';

class GroupEditScreen extends StatefulWidget {
  const GroupEditScreen({super.key, this.group});

  final MyGroupProfile? group;

  @override
  State<GroupEditScreen> createState() => _GroupEditScreenState();
}

class _GroupEditScreenState extends State<GroupEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _service = GroupProfileService();
  final _genreIds = <String>{};
  final _partIds = <String>{};
  final _areaIds = <String>{};
  late Future<MasterData> _masterData;
  bool _isSaving = false;

  bool get _isEditing => widget.group != null;

  @override
  void initState() {
    super.initState();
    final group = widget.group;
    if (group != null) {
      _nameController.text = group.name;
      _bioController.text = group.bio ?? '';
      _genreIds.addAll(group.genreIds);
      _partIds.addAll(group.recruitingPartIds);
      _areaIds.addAll(group.areaIds);
    }
    _masterData = MasterDataService().fetchActiveMasterData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save(MasterData masterData) async {
    if (_isSaving) return;

    final isValid =
        _formKey.currentState!.validate() &&
        _genreIds.isNotEmpty &&
        _partIds.isNotEmpty &&
        (masterData.areas.isEmpty || _areaIds.isNotEmpty);

    if (!isValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未入力の必須項目があります')));
      return;
    }

    setState(() => _isSaving = true);
    final data = GroupEditData(
      name: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      genreIds: Set<String>.from(_genreIds),
      recruitingPartIds: Set<String>.from(_partIds),
      areaIds: Set<String>.from(_areaIds),
    );

    try {
      final group = widget.group;
      if (group == null) {
        await _service.createGroup(data);
        if (!mounted) return;
        Navigator.of(context).pop('created');
      } else {
        await _service.updateGroup(group.id, data);
        if (!mounted) return;
        Navigator.of(context).pop('updated');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('グループを保存できませんでした。時間をおいて再度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'グループを編集' : 'グループを作成')),
      body: SafeArea(
        top: false,
        child: FutureBuilder<MasterData>(
          future: _masterData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _GroupEditLoadError(
                onRetry: () {
                  setState(
                    () => _masterData = MasterDataService()
                        .fetchActiveMasterData(),
                  );
                },
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
                              _isEditing ? 'グループを編集' : '新しいグループを作成',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            const Text('バンドや一緒に活動するメンバー募集の基本情報を設定します。'),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _nameController,
                              enabled: !_isSaving,
                              maxLength: 60,
                              decoration: const InputDecoration(
                                labelText: 'グループ名',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final name = value?.trim() ?? '';
                                if (name.isEmpty) {
                                  return 'グループ名を入力してください。';
                                }
                                if (name.length > 60) {
                                  return 'グループ名は60文字以内で入力してください。';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _bioController,
                              enabled: !_isSaving,
                              maxLength: 1000,
                              minLines: 4,
                              maxLines: 8,
                              decoration: const InputDecoration(
                                labelText: '紹介文',
                                alignLabelWithHint: true,
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final bio = value?.trim() ?? '';
                                if (bio.isEmpty) {
                                  return '紹介文を入力してください。';
                                }
                                if (bio.length > 1000) {
                                  return '紹介文は1000文字以内で入力してください。';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            if (masterData.areas.isNotEmpty) ...[
                              _MasterDataChips(
                                title: '活動エリア',
                                hint: '1つ以上選択してください',
                                items: masterData.areas,
                                selectedIds: _areaIds,
                                enabled: !_isSaving,
                                onChanged: () => setState(() {}),
                              ),
                              const SizedBox(height: 24),
                            ],
                            _MasterDataChips(
                              title: 'ジャンル',
                              hint: '1つ以上選択してください',
                              items: masterData.genres,
                              selectedIds: _genreIds,
                              enabled: !_isSaving,
                              onChanged: () => setState(() {}),
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
                                    : Text(_isEditing ? '変更を保存' : 'グループを作成'),
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

class _GroupEditLoadError extends StatelessWidget {
  const _GroupEditLoadError({required this.onRetry});

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
              const Text('グループ編集に必要なデータを読み込めませんでした。'),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/editable_profile.dart';
import '../models/master_data_item.dart';
import '../services/master_data_service.dart';
import '../services/profile_avatar_service.dart';
import '../services/profile_service.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _avatarService = ProfileAvatarService();
  final _profileService = ProfileService();
  final _partIds = <String>{};
  final _genreIds = <String>{};
  final _areaIds = <String>{};
  final _purposes = <String>{};
  late Future<MasterData> _masterData;
  String? _avatarUrl;
  String? _experienceLevel;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _masterData = _loadInitialData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<MasterData> _loadInitialData() async {
    final results = await Future.wait([
      MasterDataService().fetchActiveMasterData(),
      _profileService.fetchEditableProfile(),
    ]);
    final profile = results[1] as EditableProfile;
    _displayNameController.text = profile.displayName;
    _avatarUrl = profile.avatarUrl;
    _experienceLevel = profile.experienceLevel;
    _partIds
      ..clear()
      ..addAll(profile.partIds);
    _genreIds
      ..clear()
      ..addAll(profile.genreIds);
    _areaIds
      ..clear()
      ..addAll(profile.areaIds);
    _purposes
      ..clear()
      ..addAll(profile.purposes);
    return results[0] as MasterData;
  }

  Future<void> _save(MasterData masterData) async {
    if (_isSaving) return;

    final isValid =
        _formKey.currentState!.validate() &&
        _experienceLevel != null &&
        _purposes.isNotEmpty &&
        _partIds.isNotEmpty &&
        _genreIds.isNotEmpty &&
        (masterData.areas.isEmpty || _areaIds.isNotEmpty);
    if (!isValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未入力の必須項目があります。')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _profileService.updateCurrentProfile(
        ProfileEditData(
          displayName: _displayNameController.text.trim(),
          experienceLevel: _experienceLevel!,
          purposes: Set<String>.from(_purposes),
          partIds: Set<String>.from(_partIds),
          genreIds: Set<String>.from(_genreIds),
          areaIds: Set<String>.from(_areaIds),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プロフィールを更新できませんでした。時間をおいて再度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadAvatar() async {
    if (_isUploadingAvatar) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final result = await _avatarService.pickAndUploadAvatar();
      if (!mounted) return;
      setState(() => _avatarUrl = result.avatarUrl);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('プロフィール画像を更新しました')));
    } on ProfileAvatarUploadException catch (error) {
      if (!mounted ||
          error.reason == ProfileAvatarUploadFailureReason.canceled) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_avatarUploadErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  String _avatarUploadErrorMessage(ProfileAvatarUploadException error) {
    return switch (error.reason) {
      ProfileAvatarUploadFailureReason.unsupportedPlatform =>
        'この環境では画像選択を利用できません。',
      ProfileAvatarUploadFailureReason.unsupportedType =>
        'JPEG、PNG、WebP の画像を選択してください。',
      ProfileAvatarUploadFailureReason.fileTooLarge =>
        'プロフィール画像は5MB以下のファイルを選択してください。',
      ProfileAvatarUploadFailureReason.uploadFailed =>
        'プロフィール画像を更新できませんでした。時間をおいて再度お試しください。',
      ProfileAvatarUploadFailureReason.canceled => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール編集')),
      body: SafeArea(
        top: false,
        child: FutureBuilder<MasterData>(
          future: _masterData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ProfileEditLoadError(
                onRetry: () => setState(() => _masterData = _loadInitialData()),
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
                              'プロフィールを編集',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '公開する音楽プロフィールを更新できます。',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 24),
                            _AvatarUploadSection(
                              avatarUrl: _avatarUrl,
                              displayName: _displayNameController.text.trim(),
                              isUploading: _isUploadingAvatar,
                              onUpload: _uploadAvatar,
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _displayNameController,
                              enabled: !_isSaving,
                              maxLength: 30,
                              decoration: const InputDecoration(
                                labelText: '表示名',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final name = value?.trim() ?? '';
                                if (name.isEmpty) {
                                  return '表示名を入力してください。';
                                }
                                if (name.length > 30) {
                                  return '表示名は30文字以内で入力してください。';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _experienceLevel,
                              decoration: const InputDecoration(
                                labelText: '経験レベル',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'beginner_new',
                                  child: Text('未経験・始めたばかり'),
                                ),
                                DropdownMenuItem(
                                  value: 'beginner',
                                  child: Text('初心者'),
                                ),
                                DropdownMenuItem(
                                  value: 'experienced',
                                  child: Text('経験者'),
                                ),
                                DropdownMenuItem(
                                  value: 'pro_oriented',
                                  child: Text('プロ志向'),
                                ),
                              ],
                              onChanged: _isSaving
                                  ? null
                                  : (value) => setState(
                                      () => _experienceLevel = value,
                                    ),
                            ),
                            const SizedBox(height: 28),
                            _ChoiceChips(
                              title: '利用目的',
                              hint: '1つ以上選択してください',
                              selectedValues: _purposes,
                              choices: const {
                                'recruit': 'メンバーを募集したい',
                                'join': 'バンドに参加したい',
                                'practice': '一緒に練習したい',
                              },
                              enabled: !_isSaving,
                              onChanged: () => setState(() {}),
                            ),
                            const SizedBox(height: 24),
                            _MasterDataChips(
                              title: '担当パート',
                              hint: '1つ以上選択してください',
                              items: masterData.parts,
                              selectedIds: _partIds,
                              enabled: !_isSaving,
                              onChanged: () => setState(() {}),
                            ),
                            const SizedBox(height: 24),
                            _MasterDataChips(
                              title: '好きな音楽ジャンル',
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
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('変更を保存'),
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

class _AvatarUploadSection extends StatelessWidget {
  const _AvatarUploadSection({
    required this.avatarUrl,
    required this.displayName,
    required this.isUploading,
    required this.onUpload,
  });

  final String? avatarUrl;
  final String displayName;
  final bool isUploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final fallbackName = displayName.isEmpty ? 'B' : displayName;

    return Row(
      children: [
        _ProfileAvatarPreview(avatarUrl: avatarUrl, displayName: fallbackName),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('プロフィール画像', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'JPEG、PNG、WebP / 5MBまで',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isUploading ? null : onUpload,
                icon: isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined),
                label: Text(isUploading ? 'アップロード中' : '画像を変更'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatarPreview extends StatelessWidget {
  const _ProfileAvatarPreview({
    required this.avatarUrl,
    required this.displayName,
  });

  final String? avatarUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return CircleAvatar(
        radius: 38,
        child: Text(displayName.characters.first),
      );
    }

    return ClipOval(
      child: Image.network(
        avatarUrl!,
        width: 76,
        height: 76,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            CircleAvatar(radius: 38, child: Text(displayName.characters.first)),
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

class _ChoiceChips extends StatelessWidget {
  const _ChoiceChips({
    required this.title,
    required this.hint,
    required this.selectedValues,
    required this.choices,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String hint;
  final Set<String> selectedValues;
  final Map<String, String> choices;
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
          children: choices.entries.map((choice) {
            return FilterChip(
              label: Text(choice.value),
              selected: selectedValues.contains(choice.key),
              onSelected: !enabled
                  ? null
                  : (selected) {
                      if (selected) {
                        selectedValues.add(choice.key);
                      } else {
                        selectedValues.remove(choice.key);
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

class _ProfileEditLoadError extends StatelessWidget {
  const _ProfileEditLoadError({required this.onRetry});

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
              const Text('プロフィールを読み込めませんでした'),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
            ],
          ),
        ),
      ),
    );
  }
}

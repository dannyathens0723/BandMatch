import 'package:flutter/material.dart';

import '../models/stage_user_profile.dart';
import '../screens/stage_profile_taxonomy_selection_screen.dart';
import '../services/stage_profile_service.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';

class StageProfileEditScreen extends StatefulWidget {
  const StageProfileEditScreen({
    super.key,
    this.taxonomyBuilder,
    this.repository,
  });

  final WidgetBuilder? taxonomyBuilder;
  final StageProfileRepository? repository;

  @override
  State<StageProfileEditScreen> createState() => _StageProfileEditScreenState();
}

class _StageProfileEditScreenState extends State<StageProfileEditScreen> {
  late final StageProfileRepository _repository;
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  List<StageActivityArea> _areas = const [];
  Object? _loadError;
  bool _loading = true;
  bool _saving = false;
  bool _updated = false;
  String? _experienceLevel;
  String? _activityFrequency;
  String? _areaId;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? StageProfileService();
    _load();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_updated || result == true);
      },
      child: StageMobilePageFrame(
        child: Scaffold(
          key: const ValueKey('stage-profile-edit-screen'),
          appBar: AppBar(title: const Text('プロフィール編集')),
          body: StagePageContent(
            children: [
              _TaxonomyEntry(onPressed: _openTaxonomy),
              const SizedBox(height: StageDesignTokens.space12),
              if (_loading)
                const Center(
                  key: ValueKey('stage-profile-edit-loading'),
                  child: Padding(
                    padding: EdgeInsets.all(StageDesignTokens.space24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_loadError != null)
                StageCard(
                  key: const ValueKey('stage-profile-edit-error'),
                  child: Column(
                    children: [
                      const Text('プロフィール情報を読み込めませんでした。'),
                      const SizedBox(height: StageDesignTokens.space12),
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              else ...[
                TextField(
                  key: const ValueKey('stage-profile-display-name'),
                  controller: _displayNameController,
                  maxLength: 30,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: '表示名 *'),
                ),
                const SizedBox(height: StageDesignTokens.space12),
                TextField(
                  key: const ValueKey('stage-profile-bio'),
                  controller: _bioController,
                  maxLength: 1000,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: '自己紹介'),
                ),
                const SizedBox(height: StageDesignTokens.space12),
                DropdownButtonFormField<String?>(
                  key: const ValueKey('stage-profile-experience'),
                  initialValue: _experienceLevel,
                  decoration: const InputDecoration(labelText: 'ダンス経験'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('未設定')),
                    DropdownMenuItem(
                      value: 'beginner_new',
                      child: Text('これから始めたい'),
                    ),
                    DropdownMenuItem(value: 'beginner', child: Text('初心者')),
                    DropdownMenuItem(value: 'experienced', child: Text('経験あり')),
                    DropdownMenuItem(
                      value: 'pro_oriented',
                      child: Text('プロ志向'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _experienceLevel = value),
                ),
                const SizedBox(height: StageDesignTokens.space12),
                DropdownButtonFormField<String?>(
                  key: const ValueKey('stage-profile-frequency'),
                  initialValue: _activityFrequency,
                  decoration: const InputDecoration(labelText: '活動頻度'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('未設定')),
                    DropdownMenuItem(
                      value: 'monthly_1_2',
                      child: Text('月1〜2回'),
                    ),
                    DropdownMenuItem(value: 'weekly_1_2', child: Text('週1〜2回')),
                    DropdownMenuItem(value: 'daily', child: Text('週3回以上')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _activityFrequency = value),
                ),
                const SizedBox(height: StageDesignTokens.space12),
                DropdownButtonFormField<String?>(
                  key: const ValueKey('stage-profile-area'),
                  initialValue: _areaId,
                  decoration: const InputDecoration(labelText: '主な活動エリア'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('未設定')),
                    ..._areas.map(
                      (area) => DropdownMenuItem(
                        value: area.id,
                        child: Text(area.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _areaId = value),
                ),
                const SizedBox(height: StageDesignTokens.space24),
                StagePrimaryButton(
                  key: const ValueKey('stage-profile-save'),
                  label: _saving ? '保存しています…' : 'プロフィールを保存',
                  icon: Icons.save_outlined,
                  onPressed: _saving ? null : _save,
                ),
                const SizedBox(height: StageDesignTokens.space8),
                StageOutlinedButton(
                  key: const ValueKey('stage-profile-cancel'),
                  label: 'キャンセル',
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(_updated),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final results = await Future.wait([
        _repository.fetchMyProfile(),
        _repository.fetchActivePublicAreas(),
      ]);
      if (!mounted) return;
      final profile = results[0] as StageUserProfile;
      final areas = results[1] as List<StageActivityArea>;
      setState(() {
        _areas = areas;
        _displayNameController.text = profile.displayName;
        _bioController.text = profile.bio ?? '';
        _experienceLevel = profile.experienceLevel;
        _activityFrequency = profile.activityFrequency;
        _areaId = profile.areaId;
        _loading = false;
      });
    } on Object catch (error, stackTrace) {
      debugPrint('STAGE profile edit load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _openTaxonomy() async {
    final builder = widget.taxonomyBuilder;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: builder ?? (_) => StageProfileTaxonomySelectionScreen(),
      ),
    );
    if (updated == true && mounted) {
      _updated = true;
      await _load();
    }
  }

  Future<void> _save() async {
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      _showMessage('表示名を入力してください。');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _repository.updateMyProfile(
        displayName: displayName,
        bio: _bioController.text,
        experienceLevel: _experienceLevel,
        activityFrequency: _activityFrequency,
        areaId: _areaId,
      );
      if (!mounted) return;
      _updated = true;
      Navigator.of(context).pop(true);
    } on Object catch (error, stackTrace) {
      debugPrint('STAGE profile update failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showMessage('プロフィールを更新できませんでした。時間をおいて再度お試しください。');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TaxonomyEntry extends StatelessWidget {
  const _TaxonomyEntry({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                color: StageDesignTokens.purple,
              ),
              const SizedBox(width: StageDesignTokens.space12),
              Expanded(
                child: Text(
                  'STAGE設定',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: StageDesignTokens.space8),
          const Text('ダンスジャンル、役割、メインの役割を設定します。'),
          const SizedBox(height: StageDesignTokens.space16),
          StagePrimaryButton(
            key: const ValueKey('stage-profile-edit-taxonomy'),
            label: 'STAGE設定を編集',
            icon: Icons.tune,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

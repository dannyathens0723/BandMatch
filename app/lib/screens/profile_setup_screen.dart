import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/master_data_item.dart';
import '../models/profile_setup_data.dart';
import '../services/master_data_service.dart';
import '../services/profile_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.authUser,
    required this.onSaved,
  });

  final User authUser;
  final VoidCallback onSaved;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _profileService = ProfileService();
  late final Future<MasterData> _masterData;
  DateTime? _birthDate;
  String? _purpose;
  String? _experienceLevel;
  final Set<String> _partIds = {};
  final Set<String> _genreIds = {};
  final Set<String> _areaIds = {};
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _masterData = MasterDataService().fetchActiveMasterData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _chooseBirthDate() async {
    final today = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(today.year - 20),
      firstDate: DateTime(1920),
      lastDate: today,
      helpText: '生年月日を選択',
    );
    if (selected != null && mounted) setState(() => _birthDate = selected);
  }

  Future<void> _save(MasterData masterData) async {
    final hasAreas = masterData.areas.isNotEmpty;
    final isValid =
        _formKey.currentState!.validate() &&
        _birthDate != null &&
        _purpose != null &&
        _experienceLevel != null &&
        _partIds.isNotEmpty &&
        _genreIds.isNotEmpty &&
        (!hasAreas || _areaIds.isNotEmpty);
    if (!isValid) {
      setState(() => _error = '未入力の必須項目があります。');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await _profileService.saveProfile(
        ProfileSetupData(
          authUser: widget.authUser,
          displayName: _displayNameController.text.trim(),
          birthDate: _birthDate!,
          purpose: _purpose!,
          partIds: _partIds,
          experienceLevel: _experienceLevel!,
          genreIds: _genreIds,
          areaIds: _areaIds,
        ),
      );
      if (mounted) widget.onSaved();
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = '保存できませんでした: ${error.message}');
    } catch (error) {
      if (mounted) setState(() => _error = '保存できませんでした: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プロフィールを設定')),
      body: FutureBuilder<MasterData>(
        future: _masterData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('マスターデータを読み込めませんでした: ${snapshot.error}'));
          }

          final masterData = snapshot.requireData;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                child: Form(
                  key: _formKey,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'あなたについて教えてください',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.authUser.email ?? '',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _displayNameController,
                            maxLength: 30,
                            decoration: const InputDecoration(
                              labelText: '表示名',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? '表示名を入力してください。'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _DateField(date: _birthDate, onTap: _chooseBirthDate),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _purpose,
                            decoration: const InputDecoration(
                              labelText: '利用目的',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'recruit',
                                child: Text('メンバーを募集したい'),
                              ),
                              DropdownMenuItem(
                                value: 'join',
                                child: Text('バンドに参加したい'),
                              ),
                              DropdownMenuItem(
                                value: 'practice',
                                child: Text('一緒に練習したい'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _purpose = value),
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
                            onChanged: (value) =>
                                setState(() => _experienceLevel = value),
                          ),
                          const SizedBox(height: 28),
                          _SelectionChips(
                            title: '担当パート',
                            hint: '1つ以上選択してください',
                            items: masterData.parts,
                            selectedIds: _partIds,
                            onChanged: () => setState(() {}),
                          ),
                          const SizedBox(height: 24),
                          _SelectionChips(
                            title: '好きな音楽ジャンル',
                            hint: '1つ以上選択してください',
                            items: masterData.genres,
                            selectedIds: _genreIds,
                            onChanged: () => setState(() {}),
                          ),
                          const SizedBox(height: 24),
                          if (masterData.areas.isEmpty)
                            const Text('エリア情報はまだ登録されていません。エリアはあとから設定できます。')
                          else
                            _SelectionChips(
                              title: '活動エリア',
                              hint: '1つ以上選択してください',
                              items: masterData.areas,
                              selectedIds: _areaIds,
                              onChanged: () => setState(() {}),
                            ),
                          if (_error case final error?) ...[
                            const SizedBox(height: 20),
                            Text(
                              error,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
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
                                  : const Text('プロフィールを保存してはじめる'),
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
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});

  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = date == null
        ? '選択してください'
        : '${date!.year}年${date!.month}月${date!.day}日';
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.cake_outlined),
      label: Align(alignment: Alignment.centerLeft, child: Text('生年月日: $text')),
    );
  }
}

class _SelectionChips extends StatelessWidget {
  const _SelectionChips({
    required this.title,
    required this.hint,
    required this.items,
    required this.selectedIds,
    required this.onChanged,
  });

  final String title;
  final String hint;
  final List<MasterDataItem> items;
  final Set<String> selectedIds;
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
            final isSelected = selectedIds.contains(item.id);
            return FilterChip(
              label: Text(item.name),
              selected: isSelected,
              onSelected: (selected) {
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

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stage_user_profile.dart';
import '../services/stage_profile_service.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';
import 'stage_profile_edit_screen.dart';

class StageAuthenticatedMyPageScreen extends StatefulWidget {
  const StageAuthenticatedMyPageScreen({
    super.key,
    this.email,
    this.profileEditBuilder,
    this.signOut,
    this.profileRepository,
    this.onOpenCrewArea,
    this.refreshToken = 0,
  });

  final String? email;
  final WidgetBuilder? profileEditBuilder;
  final Future<void> Function()? signOut;
  final StageProfileRepository? profileRepository;
  final VoidCallback? onOpenCrewArea;
  final int refreshToken;

  @override
  State<StageAuthenticatedMyPageScreen> createState() =>
      _StageAuthenticatedMyPageScreenState();
}

class _StageAuthenticatedMyPageScreenState
    extends State<StageAuthenticatedMyPageScreen> {
  late final StageProfileRepository _repository;
  StageUserProfile? _profile;
  Object? _loadError;
  bool _loading = true;
  bool _isSigningOut = false;
  int _requestId = 0;

  String? get _email =>
      widget.email ?? Supabase.instance.client.auth.currentUser?.email;

  @override
  void initState() {
    super.initState();
    _repository = widget.profileRepository ?? StageProfileService();
    _loadProfile(showLoading: false);
  }

  @override
  void didUpdateWidget(covariant StageAuthenticatedMyPageScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadProfile(showLoading: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _email;
    final profile = _profile;
    return StagePageContent(
      key: const PageStorageKey('stage-auth-my-page'),
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        StageCard(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: StageDesignTokens.surfaceMuted,
                    foregroundImage:
                        profile?.avatarUrl == null ||
                            profile!.avatarUrl!.isEmpty
                        ? null
                        : NetworkImage(profile.avatarUrl!),
                    child: profile?.avatarUrl == null
                        ? const Icon(
                            Icons.person_outline,
                            color: StageDesignTokens.purple,
                            size: 30,
                          )
                        : null,
                  ),
                  const SizedBox(width: StageDesignTokens.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.displayName ?? 'STAGEプロフィール',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (profile != null) ...[
                          const SizedBox(height: StageDesignTokens.space4),
                          Text(
                            '${profile.primaryPerformanceRoleName ?? '役割未設定'}'
                            '${profile.areaName == null ? '' : ' ・ ${profile.areaName}'}',
                          ),
                          const SizedBox(height: StageDesignTokens.space8),
                          LinearProgressIndicator(
                            value: profile.profileCompleteness / 100,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          const SizedBox(height: StageDesignTokens.space4),
                          Text(
                            'プロフィール完成度 ${profile.profileCompleteness}%',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ] else if (email != null && email.isNotEmpty)
                          Text(
                            email,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (profile != null) ...[
                const SizedBox(height: StageDesignTokens.space16),
                if (profile.bio != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(profile.bio!),
                  ),
                if (profile.danceGenreNames.isNotEmpty ||
                    profile.performanceRoleNames.isNotEmpty) ...[
                  const SizedBox(height: StageDesignTokens.space12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...profile.danceGenreNames.map(StageTag.new),
                        ...profile.performanceRoleNames.map(
                          (name) => StageTag(
                            name,
                            color: const Color(0xFFFFE8EF),
                            foregroundColor: StageDesignTokens.pink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: StageDesignTokens.space16),
              StageOutlinedButton(
                key: const ValueKey('stage-my-page-profile-edit'),
                label: 'プロフィール編集',
                icon: Icons.edit_outlined,
                onPressed: _openProfileEdit,
              ),
            ],
          ),
        ),
        if (_loadError != null)
          StageCard(
            key: const ValueKey('stage-my-page-profile-error'),
            color: StageDesignTokens.surfaceMuted,
            borderColor: StageDesignTokens.surfaceMuted,
            child: Row(
              children: [
                const Expanded(child: Text('プロフィール概要を読み込めませんでした。')),
                TextButton(onPressed: _loadProfile, child: const Text('再試行')),
              ],
            ),
          ),
        const StageSectionHeader(title: '活動'),
        StageCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _StageMyPageRow(
                key: const ValueKey('stage-my-page-my-crews'),
                icon: Icons.groups_outlined,
                label: '管理中・参加中のクルー',
                onTap: _openCrewArea,
              ),
              const Divider(height: 1, indent: 48),
              _StageMyPageRow(
                key: const ValueKey('stage-my-page-applications'),
                icon: Icons.send_outlined,
                label: '応募状況を確認',
                onTap: _openCrewArea,
              ),
            ],
          ),
        ),
        const StageSectionHeader(title: 'アカウント・設定'),
        StageCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _StageMyPageRow(
                icon: Icons.notifications_none,
                label: '通知設定',
                onTap: () => _showComingSoon('通知設定'),
              ),
              const Divider(height: 1, indent: 48),
              _StageMyPageRow(
                icon: Icons.block_outlined,
                label: 'ブロックしたユーザー',
                onTap: () => _showComingSoon('ブロック管理'),
              ),
            ],
          ),
        ),
        const SizedBox(height: StageDesignTokens.space16),
        TextButton.icon(
          key: const ValueKey('stage-my-page-sign-out'),
          onPressed: _isSigningOut ? null : _signOut,
          icon: _isSigningOut
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout, size: 18),
          label: Text(_isSigningOut ? 'ログアウトしています…' : 'ログアウト'),
          style: TextButton.styleFrom(
            foregroundColor: StageDesignTokens.error,
            minimumSize: const Size(double.infinity, 46),
          ),
        ),
      ],
    );
  }

  Future<void> _loadProfile({bool showLoading = true}) async {
    final requestId = ++_requestId;
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final profile = await _repository.fetchMyProfile();
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _profile = profile;
        _loadError = null;
        _loading = false;
      });
    } on Object catch (error, stackTrace) {
      debugPrint('STAGE My Page profile failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _openProfileEdit() async {
    final builder = widget.profileEditBuilder;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder:
            builder ?? (_) => StageProfileEditScreen(repository: _repository),
      ),
    );
    if (updated == true) await _loadProfile();
  }

  void _openCrewArea() {
    final callback = widget.onOpenCrewArea;
    if (callback != null) {
      callback();
    } else {
      _showComingSoon('マイクルー');
    }
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      final callback = widget.signOut;
      if (callback != null) {
        await callback();
      } else {
        await Supabase.instance.client.auth.signOut();
      }
    } on AuthException catch (error, stackTrace) {
      debugPrint('STAGE sign out failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ログアウトできませんでした。もう一度お試しください。')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$titleは現在準備中です。')));
  }
}

class _StageMyPageRow extends StatelessWidget {
  const _StageMyPageRow({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: StageDesignTokens.textSecondary),
        title: Text(label),
        trailing: const Icon(
          Icons.chevron_right,
          color: StageDesignTokens.textMuted,
        ),
        onTap: onTap,
      ),
    );
  }
}

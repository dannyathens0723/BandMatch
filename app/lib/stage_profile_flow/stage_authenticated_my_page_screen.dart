import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';
import 'stage_profile_edit_screen.dart';

class StageAuthenticatedMyPageScreen extends StatefulWidget {
  const StageAuthenticatedMyPageScreen({
    super.key,
    this.email,
    this.profileEditBuilder,
    this.signOut,
  });

  final String? email;
  final WidgetBuilder? profileEditBuilder;
  final Future<void> Function()? signOut;

  @override
  State<StageAuthenticatedMyPageScreen> createState() =>
      _StageAuthenticatedMyPageScreenState();
}

class _StageAuthenticatedMyPageScreenState
    extends State<StageAuthenticatedMyPageScreen> {
  bool _isSigningOut = false;

  String? get _email =>
      widget.email ?? Supabase.instance.client.auth.currentUser?.email;

  Future<void> _openProfileEdit() async {
    final builder = widget.profileEditBuilder;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: builder ?? (_) => const StageProfileEditScreen(),
      ),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$titleは次のMVPステップで実装します。')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _email;
    return StagePageContent(
      key: const PageStorageKey('stage-auth-my-page'),
      children: [
        StageCard(
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      gradient: StageDesignTokens.brandGradient,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: StageDesignTokens.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STAGEプロフィール',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (email != null && email.isNotEmpty) ...[
                          const SizedBox(height: StageDesignTokens.space4),
                          Text(
                            email,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
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
        const StageSectionHeader(title: '活動'),
        StageCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _StageMyPageRow(
                icon: Icons.groups_outlined,
                label: '管理中・参加中のクルー',
                onTap: () => _showComingSoon('クルー管理'),
              ),
              const Divider(height: 1, indent: 48),
              _StageMyPageRow(
                icon: Icons.send_outlined,
                label: '応募中の募集',
                onTap: () => _showComingSoon('応募管理'),
              ),
              const Divider(height: 1, indent: 48),
              _StageMyPageRow(
                icon: Icons.history,
                label: '過去の活動',
                onTap: () => _showComingSoon('活動履歴'),
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
}

class _StageMyPageRow extends StatelessWidget {
  const _StageMyPageRow({
    required this.icon,
    required this.label,
    required this.onTap,
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

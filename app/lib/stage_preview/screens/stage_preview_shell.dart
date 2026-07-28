import 'package:flutter/material.dart';

import '../theme/stage_design_tokens.dart';
import '../widgets/stage_shell_chrome.dart';
import 'stage_crew_screen.dart';
import 'stage_home_screen.dart';
import 'stage_my_page_screen.dart';
import 'stage_stage_screen.dart';
import 'stage_studio_screen.dart';

class StagePreviewShell extends StatefulWidget {
  const StagePreviewShell({
    super.key,
    this.initialTabIndex = 0,
    this.initialHomeHasCrew = false,
  });

  final int initialTabIndex;
  final bool initialHomeHasCrew;

  @override
  State<StagePreviewShell> createState() => _StagePreviewShellState();
}

class _StagePreviewShellState extends State<StagePreviewShell> {
  late int _currentIndex;
  late bool _homeHasCrew;

  static const _titles = ['ホーム', 'クルー', 'ステージ', 'スタジオ', 'マイページ'];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex.clamp(0, 4);
    _homeHasCrew = widget.initialHomeHasCrew;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: StageDesignTokens.charcoal,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: StageDesignTokens.maxContentWidth,
          ),
          child: ColoredBox(
            color: StageDesignTokens.page,
            child: SafeArea(
              child: Scaffold(
                body: Column(
                  children: [
                    StageAppHeader(
                      title: _titles[_currentIndex],
                      isHome: _currentIndex == 0,
                      onLogoTap: _toggleHomeState,
                      onNotifications: () => _showPlaceholder(
                        icon: Icons.notifications_none_rounded,
                        title: '通知',
                        message: '通知一覧は次の実装ステップで接続します。',
                      ),
                      onMessages: () => _showPlaceholder(
                        icon: Icons.mail_outline_rounded,
                        title: 'メッセージ',
                        message: 'このプレビューでは実データに接続しません。',
                      ),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _currentIndex,
                        children: [
                          StageHomeScreen(hasCrew: _homeHasCrew),
                          const StageCrewScreen(),
                          const StageStageScreen(),
                          const StageStudioScreen(),
                          const StageMyPageScreen(),
                        ],
                      ),
                    ),
                    StageBottomNavigation(
                      currentIndex: _currentIndex,
                      onSelected: (index) {
                        if (index == _currentIndex) return;
                        setState(() => _currentIndex = index);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleHomeState() {
    if (_currentIndex != 0) return;
    setState(() => _homeHasCrew = !_homeHasCrew);
  }

  void _showPlaceholder({
    required IconData icon,
    required String title,
    required String message,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      backgroundColor: StageDesignTokens.surface,
      constraints: const BoxConstraints(
        maxWidth: StageDesignTokens.maxContentWidth,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(StageDesignTokens.radius20),
        ),
      ),
      builder: (context) => StagePreviewPlaceholderSheet(
        icon: icon,
        title: title,
        message: message,
      ),
    );
  }
}

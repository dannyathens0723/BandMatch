import 'package:flutter/material.dart';

import '../stage_preview/navigation/stage_tab.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';
import '../stage_preview/widgets/stage_shell_chrome.dart';
import 'stage_authenticated_home_screen.dart';
import 'stage_authenticated_my_page_screen.dart';

class StageAuthenticatedShell extends StatefulWidget {
  const StageAuthenticatedShell({super.key, this.myPageBuilder});

  final WidgetBuilder? myPageBuilder;

  @override
  State<StageAuthenticatedShell> createState() =>
      _StageAuthenticatedShellState();
}

class _StageAuthenticatedShellState extends State<StageAuthenticatedShell> {
  static const _navigationOrder = [
    StageTab.home,
    StageTab.crew,
    StageTab.stage,
    StageTab.studio,
    StageTab.myPage,
  ];

  StageTab _currentTab = StageTab.home;

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
                key: const ValueKey('stage-authenticated-shell'),
                body: Column(
                  children: [
                    StageAppHeader(
                      title: _currentTab.label,
                      isHome: _currentTab == StageTab.home,
                      onLogoTap: () => _selectTab(StageTab.home),
                      onNotifications: () => _openPlaceholder(
                        title: '通知',
                        icon: Icons.notifications_none_rounded,
                      ),
                      onMessages: () => _openPlaceholder(
                        title: 'メッセージ',
                        icon: Icons.mail_outline_rounded,
                      ),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _navigationOrder.indexOf(_currentTab),
                        children: [
                          StageAuthenticatedHomeScreen(
                            onSelectTab: _selectTab,
                          ),
                          const StageMvpAreaScreen(
                            key: PageStorageKey('stage-auth-crew'),
                            icon: Icons.groups_outlined,
                            title: 'クルー',
                            description: '仲間を探し、参加中のクルーを管理する場所です。',
                          ),
                          const StageMvpAreaScreen(
                            key: PageStorageKey('stage-auth-stage'),
                            icon: Icons.mic_none_outlined,
                            title: 'ステージ',
                            description: 'イベントやレッスンの情報を探す場所です。',
                          ),
                          const StageMvpAreaScreen(
                            key: PageStorageKey('stage-auth-studio'),
                            icon: Icons.location_on_outlined,
                            title: 'スタジオ',
                            description: '練習場所を探し、候補を比較する場所です。',
                          ),
                          widget.myPageBuilder?.call(context) ??
                              const StageAuthenticatedMyPageScreen(),
                        ],
                      ),
                    ),
                    StageBottomNavigation(
                      currentTab: _currentTab,
                      tabs: _navigationOrder,
                      onSelected: _selectTab,
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

  void _selectTab(StageTab tab) {
    if (tab == _currentTab) return;
    setState(() => _currentTab = tab);
  }

  void _openPlaceholder({required String title, required IconData icon}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _StageGlobalPlaceholderScreen(
          title: title,
          icon: icon,
        ),
      ),
    );
  }
}

class StageMvpAreaScreen extends StatelessWidget {
  const StageMvpAreaScreen({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return StagePageContent(
      children: [
        const SizedBox(height: StageDesignTokens.space12),
        StageCard(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  gradient: StageDesignTokens.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(height: StageDesignTokens.space16),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: StageDesignTokens.space8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: StageDesignTokens.textSecondary,
                ),
              ),
              const SizedBox(height: StageDesignTokens.space16),
              const StageTag('MVPで順次公開'),
            ],
          ),
        ),
      ],
    );
  }
}

class _StageGlobalPlaceholderScreen extends StatelessWidget {
  const _StageGlobalPlaceholderScreen({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StageMvpAreaScreen(
        icon: icon,
        title: title,
        description: 'この機能はSTAGE MVPの次のステップで接続します。',
      ),
    );
  }
}

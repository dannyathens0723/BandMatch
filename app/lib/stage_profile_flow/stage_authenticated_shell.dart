import 'package:flutter/material.dart';

import '../stage_preview/navigation/stage_tab.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';
import '../stage_preview/widgets/stage_shell_chrome.dart';
import 'stage_authenticated_home_screen.dart';
import 'stage_authenticated_my_page_screen.dart';
import 'stage_crew_discovery_screen.dart';
import 'stage_event_discovery_screen.dart';
import 'stage_studio_discovery_screen.dart';

class StageAuthenticatedShell extends StatefulWidget {
  const StageAuthenticatedShell({
    super.key,
    this.crewBuilder,
    this.stageBuilder,
    this.studioBuilder,
    this.myPageBuilder,
  });

  final WidgetBuilder? crewBuilder;
  final WidgetBuilder? stageBuilder;
  final WidgetBuilder? studioBuilder;
  final WidgetBuilder? myPageBuilder;

  @override
  State<StageAuthenticatedShell> createState() =>
      _StageAuthenticatedShellState();
}

class _StageAuthenticatedShellState extends State<StageAuthenticatedShell> {
  static const _navigationOrder = [
    StageTab.crew,
    StageTab.stage,
    StageTab.home,
    StageTab.studio,
    StageTab.myPage,
  ];

  StageTab _currentTab = StageTab.home;
  final Set<StageTab> _visitedTabs = {StageTab.home};

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
                        children: _navigationOrder
                            .map((tab) => _buildTabBody(context, tab))
                            .toList(growable: false),
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

  Widget _buildTabBody(BuildContext context, StageTab tab) {
    return switch (tab) {
      StageTab.crew =>
        _visitedTabs.contains(StageTab.crew)
            ? widget.crewBuilder?.call(context) ??
                  const StageCrewDiscoveryScreen()
            : const SizedBox.shrink(),
      StageTab.stage =>
        _visitedTabs.contains(StageTab.stage)
            ? widget.stageBuilder?.call(context) ??
                  const StageEventDiscoveryScreen()
            : const SizedBox.shrink(),
      StageTab.home => StageAuthenticatedHomeScreen(onSelectTab: _selectTab),
      StageTab.studio =>
        _visitedTabs.contains(StageTab.studio)
            ? widget.studioBuilder?.call(context) ??
                  const StageStudioDiscoveryScreen()
            : const SizedBox.shrink(),
      StageTab.myPage =>
        widget.myPageBuilder?.call(context) ??
            const StageAuthenticatedMyPageScreen(),
    };
  }

  void _selectTab(StageTab tab) {
    if (tab == _currentTab) return;
    setState(() {
      _visitedTabs.add(tab);
      _currentTab = tab;
    });
  }

  void _openPlaceholder({required String title, required IconData icon}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _StageGlobalPlaceholderScreen(title: title, icon: icon),
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

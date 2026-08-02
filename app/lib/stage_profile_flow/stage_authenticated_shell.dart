import 'package:flutter/material.dart';

import '../stage_preview/navigation/stage_tab.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';
import '../stage_preview/widgets/stage_shell_chrome.dart';
import '../services/stage_my_crew_service.dart';
import 'stage_activity_center_screen.dart';
import 'stage_authenticated_home_screen.dart';
import 'stage_authenticated_my_page_screen.dart';
import 'stage_crew_discovery_screen.dart';
import 'stage_crew_home_screen.dart';
import 'stage_event_discovery_screen.dart';
import 'stage_studio_discovery_screen.dart';

class StageAuthenticatedShell extends StatefulWidget {
  const StageAuthenticatedShell({
    super.key,
    this.crewBuilder,
    this.homeBuilder,
    this.stageBuilder,
    this.studioBuilder,
    this.myPageBuilder,
  });

  final WidgetBuilder? crewBuilder;
  final WidgetBuilder? homeBuilder;
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
  final StageCrewDiscoveryController _crewController =
      StageCrewDiscoveryController();
  int _refreshToken = 0;

  @override
  void dispose() {
    _crewController.dispose();
    super.dispose();
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
                key: const ValueKey('stage-authenticated-shell'),
                body: Column(
                  children: [
                    StageAppHeader(
                      title: _currentTab.label,
                      isHome: _currentTab == StageTab.home,
                      onLogoTap: () => _selectTab(StageTab.home),
                      showNotificationBadge: false,
                      onNotifications: _openActivityCenter,
                      onMessages: _showMessagesComingSoon,
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
                  StageCrewDiscoveryScreen(controller: _crewController)
            : const SizedBox.shrink(),
      StageTab.stage =>
        _visitedTabs.contains(StageTab.stage)
            ? widget.stageBuilder?.call(context) ??
                  const StageEventDiscoveryScreen()
            : const SizedBox.shrink(),
      StageTab.home =>
        widget.homeBuilder?.call(context) ??
            StageAuthenticatedHomeScreen(
              onSelectTab: _selectTab,
              refreshToken: _refreshToken,
              onOpenMyCrew: _openMyCrew,
              onOpenCrew: _openCrewFromActivity,
            ),
      StageTab.studio =>
        _visitedTabs.contains(StageTab.studio)
            ? widget.studioBuilder?.call(context) ??
                  const StageStudioDiscoveryScreen()
            : const SizedBox.shrink(),
      StageTab.myPage =>
        widget.myPageBuilder?.call(context) ??
            StageAuthenticatedMyPageScreen(
              refreshToken: _refreshToken,
              onOpenCrewArea: _openMyCrew,
            ),
    };
  }

  void _selectTab(StageTab tab) {
    if (tab == _currentTab) {
      if (tab == StageTab.home || tab == StageTab.myPage) {
        setState(() => _refreshToken++);
      }
      return;
    }
    setState(() {
      _visitedTabs.add(tab);
      _currentTab = tab;
      if (tab == StageTab.home || tab == StageTab.myPage) _refreshToken++;
    });
  }

  Future<void> _openActivityCenter() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => StageActivityCenterScreen(
          onOpenCrewArea: _openMyCrew,
          onOpenCrew: _openCrewFromActivity,
        ),
      ),
    );
    if (mounted) setState(() => _refreshToken++);
  }

  void _showMessagesComingSoon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('メッセージ機能は現在準備中です。')));
  }

  void _openMyCrew() {
    _crewController.showMyCrew();
    _selectTab(StageTab.crew);
  }

  Future<void> _openCrewFromActivity(String crewId) async {
    try {
      final overview = await StageMyCrewService().fetchMyCrewOverview();
      if (!mounted) return;
      final matching = overview.crews.where((item) => item.crewId == crewId);
      final crew = matching.isEmpty ? null : matching.first;
      if (crew == null) {
        _openMyCrew();
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => StageCrewHomeScreen(
            initialCrew: crew,
            availableCrews: overview.crews,
          ),
        ),
      );
      if (mounted) setState(() => _refreshToken++);
    } catch (error, stackTrace) {
      debugPrint('STAGE Crew activity navigation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) _openMyCrew();
    }
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

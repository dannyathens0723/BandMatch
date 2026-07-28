import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/stage_preview_router.dart';
import '../navigation/stage_tab.dart';
import '../theme/stage_design_tokens.dart';
import '../widgets/stage_shell_chrome.dart';

class StagePreviewShell extends StatelessWidget {
  const StagePreviewShell({
    required this.navigationShell,
    required this.homeController,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final StageHomePreviewController homeController;

  StageTab get currentTab {
    return StageTab.fromBranchIndex(navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = currentTab;
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
                      title: selectedTab.label,
                      isHome: selectedTab == StageTab.home,
                      onLogoTap: homeController.toggle,
                      onNotifications: () {
                        context.push(StageRoutes.notifications);
                      },
                      onMessages: () {
                        context.push(StageRoutes.messages);
                      },
                    ),
                    Expanded(child: navigationShell),
                    StageBottomNavigation(
                      currentTab: selectedTab,
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
    navigationShell.goBranch(
      tab.branchIndex,
      initialLocation: tab == currentTab,
    );
  }
}

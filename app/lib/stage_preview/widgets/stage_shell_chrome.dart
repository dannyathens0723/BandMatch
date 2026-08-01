import 'package:flutter/material.dart';

import '../navigation/stage_tab.dart';
import '../theme/stage_design_tokens.dart';
import 'stage_common.dart';

class StageAppHeader extends StatelessWidget {
  const StageAppHeader({
    required this.title,
    required this.onNotifications,
    required this.onMessages,
    super.key,
    this.isHome = false,
    this.onLogoTap,
  });

  final String title;
  final bool isHome;
  final VoidCallback? onLogoTap;
  final VoidCallback onNotifications;
  final VoidCallback onMessages;

  @override
  Widget build(BuildContext context) {
    final titleWidget = isHome
        ? Semantics(
            button: true,
            label: 'ホーム表示状態を切り替え',
            child: Tooltip(
              message: 'タップして未所属／所属ホームを切り替え',
              child: InkWell(
                key: const ValueKey('stage-home-state-toggle'),
                onTap: onLogoTap,
                borderRadius: BorderRadius.circular(StageDesignTokens.radius8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                  child: Text(
                    'STAGE',
                    style: TextStyle(
                      color: StageDesignTokens.charcoal,
                      fontSize: 20,
                      height: 1,
                      letterSpacing: 2.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          )
        : Text(
            title,
            key: const ValueKey('stage-page-title'),
            style: Theme.of(context).textTheme.titleLarge,
          );

    return Container(
      height: StageDesignTokens.headerHeight,
      padding: const EdgeInsets.only(left: 16, right: 6),
      decoration: const BoxDecoration(
        color: StageDesignTokens.surface,
        border: Border(
          bottom: BorderSide(color: StageDesignTokens.border, width: 0.7),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: titleWidget),
          ),
          StageNotificationBadge(
            child: IconButton(
              key: const ValueKey('stage-notification-action'),
              tooltip: '通知',
              onPressed: onNotifications,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          IconButton(
            key: const ValueKey('stage-message-action'),
            tooltip: 'メッセージ',
            onPressed: onMessages,
            icon: const Icon(Icons.mail_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class StageBottomNavigation extends StatelessWidget {
  const StageBottomNavigation({
    required this.currentTab,
    required this.onSelected,
    super.key,
    this.tabs = StageTab.values,
  });

  final StageTab currentTab;
  final ValueChanged<StageTab> onSelected;
  final List<StageTab> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: StageDesignTokens.bottomNavigationHeight,
      decoration: const BoxDecoration(
        color: StageDesignTokens.surface,
        border: Border(
          top: BorderSide(color: StageDesignTokens.border, width: 0.7),
        ),
      ),
      child: Row(
        children: tabs.map((tab) {
          final selected = tab == currentTab;
          final color = selected
              ? StageDesignTokens.purple
              : StageDesignTokens.textMuted;
          return Expanded(
            child: Semantics(
              selected: selected,
              button: true,
              label: tab.label,
              child: InkWell(
                key: ValueKey('stage-tab-${tab.name}'),
                onTap: () => onSelected(tab),
                child: Padding(
                  padding: const EdgeInsets.only(top: 7, bottom: 5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? tab.selectedIcon : tab.icon,
                        size: 22,
                        color: color,
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          tab.label,
                          maxLines: 1,
                          style: TextStyle(
                            color: color,
                            fontSize: 9.5,
                            height: 1,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

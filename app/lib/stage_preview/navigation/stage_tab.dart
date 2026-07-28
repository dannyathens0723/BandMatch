import 'package:flutter/material.dart';

enum StageTab {
  crew(
    label: 'クルー',
    path: StageRoutes.crew,
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
  ),
  stage(
    label: 'ステージ',
    path: StageRoutes.stage,
    icon: Icons.mic_none_outlined,
    selectedIcon: Icons.mic_rounded,
  ),
  home(
    label: 'ホーム',
    path: StageRoutes.home,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  studio(
    label: 'スタジオ',
    path: StageRoutes.studio,
    icon: Icons.location_on_outlined,
    selectedIcon: Icons.location_on_rounded,
  ),
  myPage(
    label: 'マイページ',
    path: StageRoutes.myPage,
    icon: Icons.sentiment_satisfied_alt_outlined,
    selectedIcon: Icons.sentiment_satisfied_alt_rounded,
  );

  const StageTab({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;

  int get branchIndex => index;

  static StageTab fromBranchIndex(int index) {
    assert(index >= 0 && index < StageTab.values.length);
    return StageTab.values[index];
  }
}

abstract final class StageRoutes {
  static const crew = '/crew';
  static const crewSampleRecruitment = '/crew/recruitments/sample';
  static const stage = '/stage';
  static const stageSampleEvent = '/stage/events/sample';
  static const home = '/home';
  static const studio = '/studio';
  static const myPage = '/me';
  static const notifications = '/notifications';
  static const messages = '/messages';
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/stage_crew_screen.dart';
import '../screens/stage_home_screen.dart';
import '../screens/stage_my_page_screen.dart';
import '../screens/stage_preview_shell.dart';
import '../screens/stage_route_placeholder_screen.dart';
import '../screens/stage_stage_screen.dart';
import '../screens/stage_studio_screen.dart';
import 'stage_tab.dart';

class StageHomePreviewController extends ChangeNotifier {
  StageHomePreviewController({bool initialHasCrew = false})
    : _hasCrew = initialHasCrew;

  bool _hasCrew;

  bool get hasCrew => _hasCrew;

  void toggle() {
    _hasCrew = !_hasCrew;
    notifyListeners();
  }
}

class StagePreviewRouter {
  StagePreviewRouter._({required this.router, required this.homeController});

  factory StagePreviewRouter.create({
    String initialLocation = StageRoutes.home,
    bool initialHomeHasCrew = false,
  }) {
    // The preview uses imperative pushes for detail/global overlays so the
    // visible Web URL follows the top route and browser Back can restore the
    // underlying stateful branch.
    GoRouter.optionURLReflectsImperativeAPIs = true;

    final homeController = StageHomePreviewController(
      initialHasCrew: initialHomeHasCrew,
    );
    final rootNavigatorKey = GlobalKey<NavigatorState>(
      debugLabel: 'stage-preview-root',
    );

    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return StagePreviewShell(
              navigationShell: navigationShell,
              homeController: homeController,
            );
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: StageRoutes.crew,
                  builder: (context, state) => StageCrewScreen(
                    onSampleRecruitmentTap: () {
                      context.push(StageRoutes.crewSampleRecruitment);
                    },
                  ),
                  routes: [
                    GoRoute(
                      path: 'recruitments/sample',
                      builder: (context, state) =>
                          const StageNestedPlaceholderScreen(
                            icon: Icons.groups_outlined,
                            eyebrow: 'クルー',
                            title: '募集詳細プレビュー',
                            message: '募集詳細と応募機能は次の実装ステップで接続します。',
                          ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: StageRoutes.stage,
                  builder: (context, state) => StageStageScreen(
                    onSampleEventTap: () {
                      context.push(StageRoutes.stageSampleEvent);
                    },
                  ),
                  routes: [
                    GoRoute(
                      path: 'events/sample',
                      builder: (context, state) =>
                          const StageNestedPlaceholderScreen(
                            icon: Icons.local_activity_outlined,
                            eyebrow: 'ステージ',
                            title: 'イベント詳細プレビュー',
                            message: 'イベント詳細と外部リンクは今後の実装範囲です。',
                          ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              initialLocation: StageRoutes.home,
              routes: [
                GoRoute(
                  path: StageRoutes.home,
                  builder: (context, state) {
                    return ListenableBuilder(
                      listenable: homeController,
                      builder: (context, child) {
                        return StageHomeScreen(hasCrew: homeController.hasCrew);
                      },
                    );
                  },
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: StageRoutes.studio,
                  builder: (context, state) => const StageStudioScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: StageRoutes.myPage,
                  builder: (context, state) => const StageMyPageScreen(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: StageRoutes.notifications,
          builder: (context, state) => const StageGlobalPlaceholderScreen(
            icon: Icons.notifications_none_rounded,
            title: '通知',
            message: '通知一覧は次の実装ステップで接続します。',
          ),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: StageRoutes.messages,
          builder: (context, state) => const StageGlobalPlaceholderScreen(
            icon: Icons.mail_outline_rounded,
            title: 'メッセージ',
            message: 'このプレビューでは実データに接続しません。',
          ),
        ),
      ],
      errorBuilder: (context, state) =>
          StageUnavailableScreen(requestedLocation: state.uri.toString()),
    );

    return StagePreviewRouter._(router: router, homeController: homeController);
  }

  final GoRouter router;
  final StageHomePreviewController homeController;

  void dispose() {
    router.dispose();
    homeController.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/stage_tab.dart';
import '../theme/stage_design_tokens.dart';
import '../widgets/stage_common.dart';

class StageNestedPlaceholderScreen extends StatelessWidget {
  const StageNestedPlaceholderScreen({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return StagePageContent(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton.filledTonal(
            key: const ValueKey('stage-nested-back'),
            tooltip: '戻る',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        const SizedBox(height: StageDesignTokens.space16),
        StageCard(
          showShadow: true,
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: StageDesignTokens.brandGradient,
                  borderRadius: BorderRadius.circular(
                    StageDesignTokens.radius20,
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 34),
              ),
              const SizedBox(height: StageDesignTokens.space16),
              Text(
                eyebrow,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: StageDesignTokens.purple,
                ),
              ),
              const SizedBox(height: StageDesignTokens.space8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: StageDesignTokens.space8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: StageDesignTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StageGlobalPlaceholderScreen extends StatelessWidget {
  const StageGlobalPlaceholderScreen({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _StageStandalonePage(
      title: title,
      child: StageEmptyState(icon: icon, title: title, message: message),
    );
  }
}

class StageUnavailableScreen extends StatelessWidget {
  const StageUnavailableScreen({required this.requestedLocation, super.key});

  final String requestedLocation;

  @override
  Widget build(BuildContext context) {
    return _StageStandalonePage(
      title: 'STAGE',
      showBack: false,
      child: Column(
        children: [
          const StageEmptyState(
            icon: Icons.search_off_rounded,
            title: 'ページを表示できません',
            message: 'URLを確認するか、ホームへ戻ってください。',
          ),
          const SizedBox(height: StageDesignTokens.space12),
          Text(
            requestedLocation,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: StageDesignTokens.space20),
          StagePrimaryButton(
            label: 'ホームへ戻る',
            icon: Icons.home_outlined,
            onPressed: () => context.go(StageRoutes.home),
          ),
        ],
      ),
    );
  }
}

class _StageStandalonePage extends StatelessWidget {
  const _StageStandalonePage({
    required this.title,
    required this.child,
    this.showBack = true,
  });

  final String title;
  final Widget child;
  final bool showBack;

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
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  leading: showBack
                      ? IconButton(
                          key: const ValueKey('stage-global-back'),
                          tooltip: '戻る',
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(StageRoutes.home);
                            }
                          },
                          icon: const Icon(Icons.arrow_back_rounded),
                        )
                      : null,
                  title: Text(title),
                ),
                body: StagePageContent(children: [child]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/stage_preview_data.dart';
import '../theme/stage_design_tokens.dart';

class StagePageContent extends StatelessWidget {
  const StagePageContent({
    required this.children,
    super.key,
    this.controller,
    this.topPadding = StageDesignTokens.space16,
  });

  final List<Widget> children;
  final ScrollController? controller;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = StageDesignTokens.horizontalPadding(
          constraints.maxWidth,
        );
        return ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(
            horizontal,
            topPadding,
            horizontal,
            StageDesignTokens.space32,
          ),
          children: children,
        );
      },
    );
  }
}

class StageCard extends StatelessWidget {
  const StageCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(StageDesignTokens.space16),
    this.color = StageDesignTokens.surface,
    this.borderColor = StageDesignTokens.border,
    this.gradient,
    this.onTap,
    this.radius = StageDesignTokens.radius16,
    this.showShadow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final double radius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: gradient == null ? color : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor),
      boxShadow: showShadow ? StageDesignTokens.cardShadow : null,
    );
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: decoration,
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class StageSectionHeader extends StatelessWidget {
  const StageSectionHeader({
    required this.title,
    super.key,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: StageDesignTokens.space8,
        bottom: StageDesignTokens.space12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction ?? () {},
              style: TextButton.styleFrom(
                foregroundColor: StageDesignTokens.purple,
                padding: const EdgeInsets.symmetric(
                  horizontal: StageDesignTokens.space8,
                ),
                minimumSize: const Size(0, 40),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class StagePrimaryButton extends StatelessWidget {
  const StagePrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.light = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          backgroundColor: light
              ? StageDesignTokens.surface
              : StageDesignTokens.purple,
          foregroundColor: light
              ? StageDesignTokens.purple
              : StageDesignTokens.surface,
          disabledBackgroundColor: StageDesignTokens.border,
          disabledForegroundColor: StageDesignTokens.textMuted,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

class StageOutlinedButton extends StatelessWidget {
  const StageOutlinedButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: StageDesignTokens.purple,
          side: const BorderSide(color: StageDesignTokens.purple),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

class StageTag extends StatelessWidget {
  const StageTag(
    this.label, {
    super.key,
    this.selected = false,
    this.color,
    this.foregroundColor,
  });

  final String label;
  final bool selected;
  final Color? color;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final background =
        color ??
        (selected
            ? StageDesignTokens.charcoal
            : StageDesignTokens.surfaceMuted);
    final foreground =
        foregroundColor ??
        (selected
            ? StageDesignTokens.surface
            : StageDesignTokens.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StageDesignTokens.space12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(StageDesignTokens.radiusPill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: foreground),
      ),
    );
  }
}

class StageStatusBadge extends StatelessWidget {
  const StageStatusBadge({
    required this.label,
    super.key,
    this.color = StageDesignTokens.pink,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(StageDesignTokens.radiusPill),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: Colors.white, fontSize: 10),
      ),
    );
  }
}

class StageNotificationBadge extends StatelessWidget {
  const StageNotificationBadge({
    required this.child,
    super.key,
    this.show = true,
  });

  final Widget child;
  final bool show;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (show)
          const Positioned(
            right: 7,
            top: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: StageDesignTokens.pink,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: Colors.white, width: 1.5),
                ),
              ),
              child: SizedBox(width: 8, height: 8),
            ),
          ),
      ],
    );
  }
}

class StageRecruitmentCard extends StatelessWidget {
  const StageRecruitmentCard({
    required this.data,
    super.key,
    this.compact = false,
    this.onTap,
  });

  final StageRecruitmentPreview data;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      onTap: onTap,
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 46 : 54,
                height: compact ? 46 : 54,
                decoration: BoxDecoration(
                  gradient: StageDesignTokens.brandGradient,
                  borderRadius: BorderRadius.circular(
                    StageDesignTokens.radius12,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.badge != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: StageStatusBadge(label: data.badge!),
                      ),
                    Text(
                      data.title,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.crewName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StageTag(data.genre),
              StageTag(data.area),
              StageTag(data.experience),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.group_outlined,
                size: 16,
                color: StageDesignTokens.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(data.remaining),
              const Spacer(),
              Text(
                data.deadline,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: StageDesignTokens.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StageEventCard extends StatelessWidget {
  const StageEventCard({required this.data, super.key, this.onTap});

  final StageEventPreview data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 58,
                decoration: BoxDecoration(
                  color: StageDesignTokens.charcoal,
                  borderRadius: BorderRadius.circular(
                    StageDesignTokens.radius12,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.local_activity_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.badge != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: StageStatusBadge(
                          label: data.badge!,
                          color: StageDesignTokens.success,
                        ),
                      ),
                    Text(
                      data.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StageTag(data.category),
              StageTag(data.date),
              StageTag(data.place),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 15,
                color: StageDesignTokens.textMuted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${data.source} ・ ${data.verifiedAt}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StageLessonCard extends StatelessWidget {
  const StageLessonCard({required this.data, super.key});

  final StageLessonPreview data;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: StageDesignTokens.surfaceMuted,
            child: Text(
              data.instructor.characters.first,
              style: const TextStyle(
                color: StageDesignTokens.purple,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.instructor} ・ ${data.schedule}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StageTag(data.level),
                    StageTag(
                      data.trustLabel,
                      color: const Color(0xFFE8F7F0),
                      foregroundColor: StageDesignTokens.success,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StageStudioCard extends StatelessWidget {
  const StageStudioCard({required this.data, super.key});

  final StageStudioPreview data;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: StageDesignTokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(
                    StageDesignTokens.radius12,
                  ),
                ),
                child: const Icon(
                  Icons.surround_sound_outlined,
                  color: StageDesignTokens.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.station,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StageStudioMetric(
                  icon: Icons.payments_outlined,
                  label: data.price,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StageStudioMetric(
                  icon: Icons.groups_outlined,
                  label: data.capacity,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: data.facilities.map(StageTag.new).toList(),
          ),
        ],
      ),
    );
  }
}

class _StageStudioMetric extends StatelessWidget {
  const _StageStudioMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: StageDesignTokens.textSecondary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class StageEmptyState extends StatelessWidget {
  const StageEmptyState({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.auto_awesome_outlined,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return StageCard(
      color: StageDesignTokens.surfaceMuted,
      borderColor: StageDesignTokens.surfaceMuted,
      child: Column(
        children: [
          Icon(icon, color: StageDesignTokens.purple, size: 32),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class StageSearchField extends StatelessWidget {
  const StageSearchField({required this.hint, super.key, this.onTap});

  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(StageDesignTokens.radius12),
        child: Ink(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(StageDesignTokens.radius12),
            border: Border.all(color: StageDesignTokens.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search,
                size: 20,
                color: StageDesignTokens.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hint,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: StageDesignTokens.textMuted,
                  ),
                ),
              ),
              const Icon(
                Icons.tune,
                size: 20,
                color: StageDesignTokens.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StageSegmentedControl extends StatelessWidget {
  const StageSegmentedControl({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: StageDesignTokens.surface,
        borderRadius: BorderRadius.circular(StageDesignTokens.radius12),
        border: Border.all(color: StageDesignTokens.border),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = index == selectedIndex;
          return Expanded(
            child: Semantics(
              selected: selected,
              button: true,
              child: InkWell(
                key: ValueKey('stage-segment-$index'),
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(StageDesignTokens.radius8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? StageDesignTokens.charcoal
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      StageDesignTokens.radius8,
                    ),
                  ),
                  child: Text(
                    labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected
                          ? StageDesignTokens.surface
                          : StageDesignTokens.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

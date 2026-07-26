import 'package:flutter/material.dart';

class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.count,
    required this.semanticLabel,
    required this.child,
  });

  final int count;
  final String semanticLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;

    final label = count >= 100 ? '99+' : count.toString();
    return Semantics(
      label: '$semanticLabel: $count',
      child: Badge(
        backgroundColor: const Color(0xFFFFC629),
        textColor: Colors.black,
        label: Text(label),
        child: child,
      ),
    );
  }
}

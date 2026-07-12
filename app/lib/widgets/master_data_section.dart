import 'package:flutter/material.dart';

import '../models/master_data_item.dart';

class MasterDataSection extends StatelessWidget {
  const MasterDataSection({
    super.key,
    required this.title,
    required this.description,
    required this.items,
    required this.icon,
  });

  final String title;
  final String description;
  final List<MasterDataItem> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.onSurface),
                const SizedBox(width: 10),
                Text(title, style: theme.textTheme.titleLarge),
                const Spacer(),
                Text('${items.length}件', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 6),
            Text(description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((item) => Chip(label: Text(item.name))).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

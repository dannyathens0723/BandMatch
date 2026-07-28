import 'package:flutter/material.dart';

import '../models/stage_preview_data.dart';
import '../theme/stage_design_tokens.dart';
import '../widgets/stage_common.dart';

class StageStudioScreen extends StatelessWidget {
  const StageStudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StagePageContent(
      key: const PageStorageKey('stage-studio-scroll'),
      children: [
        const StageSearchField(hint: '駅名・エリア・スタジオ名'),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: const [
              StageTag('新宿', selected: true),
              SizedBox(width: 8),
              StageTag('〜¥2,500'),
              SizedBox(width: 8),
              StageTag('8人以上'),
              SizedBox(width: 8),
              StageTag('駅徒歩5分'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _StageMapPlaceholder(),
        const SizedBox(height: 14),
        const StageCard(
          gradient: StageDesignTokens.heroGradient,
          borderColor: Colors.transparent,
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'クルーに合うスタジオを探す',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '人数・場所・予算から候補を比較',
                      style: TextStyle(color: Color(0xFFF6F1FF), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
        const StageSectionHeader(title: '新宿周辺のスタジオ', actionLabel: '並び替え'),
        ...StagePreviewData.studios.expand(
          (item) => [StageStudioCard(data: item), const SizedBox(height: 12)],
        ),
        StageOutlinedButton(
          label: 'スタジオを一覧で見る',
          icon: Icons.format_list_bulleted,
          onPressed: () {},
        ),
      ],
    );
  }
}

class _StageMapPlaceholder extends StatelessWidget {
  const _StageMapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 176,
      decoration: BoxDecoration(
        color: const Color(0xFFE9E7EF),
        borderRadius: BorderRadius.circular(StageDesignTokens.radius16),
        border: Border.all(color: StageDesignTokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _StageMapPainter())),
          const Positioned(
            top: 24,
            left: 38,
            child: _MapPriceBubble(label: '¥1,900'),
          ),
          const Positioned(
            top: 60,
            right: 34,
            child: _MapPriceBubble(label: '¥2,800', active: true),
          ),
          const Positioned(
            bottom: 30,
            left: 112,
            child: _MapPriceBubble(label: '¥2,200'),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.map_outlined, size: 17),
              label: const Text('地図から探す'),
              style: FilledButton.styleFrom(
                backgroundColor: StageDesignTokens.charcoal,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke;
    final minor = Paint()
      ..color = const Color(0xFFD6D3DE)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(-10, size.height * 0.3),
      Offset(size.width + 10, size.height * 0.7),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.23, -10),
      Offset(size.width * 0.65, size.height + 10),
      road,
    );
    canvas.drawLine(
      Offset(-10, size.height * 0.72),
      Offset(size.width + 10, size.height * 0.18),
      minor,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapPriceBubble extends StatelessWidget {
  const _MapPriceBubble({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: active ? StageDesignTokens.purple : Colors.white,
        borderRadius: BorderRadius.circular(StageDesignTokens.radiusPill),
        boxShadow: StageDesignTokens.cardShadow,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: active ? Colors.white : StageDesignTokens.textPrimary,
        ),
      ),
    );
  }
}

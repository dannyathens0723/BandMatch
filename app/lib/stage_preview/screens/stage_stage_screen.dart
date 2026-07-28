import 'package:flutter/material.dart';

import '../models/stage_preview_data.dart';
import '../theme/stage_design_tokens.dart';
import '../widgets/stage_common.dart';

class StageStageScreen extends StatelessWidget {
  const StageStageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StagePageContent(
      key: const PageStorageKey('stage-stage-scroll'),
      children: [
        const StageCard(
          color: StageDesignTokens.surfaceMuted,
          borderColor: StageDesignTokens.surfaceMuted,
          padding: EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: StageDesignTokens.purple,
                size: 20,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  '公式情報をもとに、開催状況と最終確認日を掲載しています。',
                  style: TextStyle(
                    color: StageDesignTokens.textSecondary,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const StageSectionHeader(title: 'イベント・大会', actionLabel: 'もっと見る'),
        ...StagePreviewData.events.expand(
          (item) => [StageEventCard(data: item), const SizedBox(height: 12)],
        ),
        const StageCard(
          gradient: StageDesignTokens.heroGradient,
          borderColor: Colors.transparent,
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.groups_outlined, color: Colors.white, size: 26),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'このイベントを目標に仲間を募集',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '出演クルーを作る・探す',
                      style: TextStyle(color: Color(0xFFF6F1FF), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: Colors.white),
            ],
          ),
        ),
        const StageSectionHeader(title: 'レッスン・ワークショップ', actionLabel: 'すべて見る'),
        ...StagePreviewData.lessons.expand(
          (item) => [StageLessonCard(data: item), const SizedBox(height: 12)],
        ),
      ],
    );
  }
}

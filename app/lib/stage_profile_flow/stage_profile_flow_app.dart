import 'package:flutter/material.dart';

import '../app.dart';
import '../config/app_config.dart';
import '../screens/stage_profile_taxonomy_selection_screen.dart';
import '../stage_preview/theme/stage_design_tokens.dart';

class StageProfileFlowApp extends StatelessWidget {
  const StageProfileFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STAGE プロフィール設定',
      debugShowCheckedModeBanner: false,
      theme: StageDesignTokens.theme,
      home: AppConfig.isSupabaseConfigured
          ? StageProfileTaxonomySelectionScreen()
          : const SupabaseConfigurationScreen(),
    );
  }
}

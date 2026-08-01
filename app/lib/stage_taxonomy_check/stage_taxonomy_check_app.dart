import 'package:flutter/material.dart';

import '../app.dart';
import '../config/app_config.dart';
import '../screens/stage_taxonomy_read_only_screen.dart';
import '../theme/app_theme.dart';

class StageTaxonomyCheckApp extends StatelessWidget {
  const StageTaxonomyCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STAGE データ接続確認',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AppConfig.isSupabaseConfigured
          ? const StageTaxonomyReadOnlyScreen()
          : const SupabaseConfigurationScreen(),
    );
  }
}

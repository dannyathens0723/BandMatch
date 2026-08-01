import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_launch_mode.dart';
import 'config/app_config.dart';
import 'config/stage_profile_flow_config.dart';
import 'config/stage_taxonomy_check_config.dart';
import 'stage_profile_flow/stage_profile_flow_app.dart';
import 'stage_preview/stage_preview_app.dart';
import 'stage_preview/stage_preview_config.dart';
import 'stage_taxonomy_check/stage_taxonomy_check_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final launchMode = resolveAppLaunchMode(
    stagePreviewEnabled: StagePreviewConfig.enabled,
    stageTaxonomyCheckEnabled: StageTaxonomyCheckConfig.enabled,
    stageProfileFlowEnabled: StageProfileFlowConfig.enabled,
  );

  if (launchMode == AppLaunchMode.stagePreview) {
    runApp(const StagePreviewApp());
    return;
  }

  if (AppConfig.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }

  switch (launchMode) {
    case AppLaunchMode.stageTaxonomyCheck:
      runApp(const StageTaxonomyCheckApp());
    case AppLaunchMode.stageProfileFlow:
      runApp(const StageProfileFlowApp());
    case AppLaunchMode.bandMatch:
      runApp(const BandMatchApp());
    case AppLaunchMode.stagePreview:
      throw StateError('STAGE Preview should have returned before this point.');
  }
}

import 'package:flutter/material.dart';

import 'screens/stage_preview_shell.dart';
import 'theme/stage_design_tokens.dart';

class StagePreviewApp extends StatelessWidget {
  const StagePreviewApp({
    super.key,
    this.initialTabIndex = 0,
    this.initialHomeHasCrew = false,
  });

  final int initialTabIndex;
  final bool initialHomeHasCrew;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STAGE Preview',
      debugShowCheckedModeBanner: false,
      theme: StageDesignTokens.theme,
      home: StagePreviewShell(
        initialTabIndex: initialTabIndex,
        initialHomeHasCrew: initialHomeHasCrew,
      ),
    );
  }
}

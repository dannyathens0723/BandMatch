import 'package:flutter/material.dart';

import 'navigation/stage_preview_router.dart';
import 'navigation/stage_tab.dart';
import 'theme/stage_design_tokens.dart';

class StagePreviewApp extends StatefulWidget {
  const StagePreviewApp({
    super.key,
    this.initialLocation = StageRoutes.home,
    this.initialHomeHasCrew = false,
    this.previewRouter,
  });

  final String initialLocation;
  final bool initialHomeHasCrew;
  final StagePreviewRouter? previewRouter;

  @override
  State<StagePreviewApp> createState() => _StagePreviewAppState();
}

class _StagePreviewAppState extends State<StagePreviewApp> {
  late final StagePreviewRouter _previewRouter;
  late final bool _ownsRouter;

  @override
  void initState() {
    super.initState();
    _ownsRouter = widget.previewRouter == null;
    _previewRouter =
        widget.previewRouter ??
        StagePreviewRouter.create(
          initialLocation: widget.initialLocation,
          initialHomeHasCrew: widget.initialHomeHasCrew,
        );
  }

  @override
  void dispose() {
    if (_ownsRouter) {
      _previewRouter.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'STAGE Preview',
      debugShowCheckedModeBanner: false,
      theme: StageDesignTokens.theme,
      routerConfig: _previewRouter.router,
    );
  }
}

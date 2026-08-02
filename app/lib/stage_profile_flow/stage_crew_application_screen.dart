import 'package:flutter/material.dart';

import '../models/recruitment_application.dart';
import '../models/stage_crew_recruitment.dart';
import '../stage_preview/theme/stage_design_tokens.dart';
import '../stage_preview/widgets/stage_common.dart';
import 'stage_crew_detail_screen.dart';

class StageCrewApplicationScreen extends StatefulWidget {
  const StageCrewApplicationScreen({
    required this.recruitment,
    required this.submitApplication,
    super.key,
  });

  final StageCrewRecruitment recruitment;
  final StageCrewApplicationSubmitter submitApplication;

  @override
  State<StageCrewApplicationScreen> createState() =>
      _StageCrewApplicationScreenState();
}

class _StageCrewApplicationScreenState
    extends State<StageCrewApplicationScreen> {
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  String? _validationMessage;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StageMobilePageFrame(
      child: Scaffold(
        key: const ValueKey('stage-crew-application-screen'),
        appBar: AppBar(title: const Text('応募フォーム')),
        body: ListView(
          padding: const EdgeInsets.all(StageDesignTokens.space16),
          children: [
            StageCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recruitment.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: StageDesignTokens.space4),
                  Text(
                    widget.recruitment.crewName,
                    style: const TextStyle(
                      color: StageDesignTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: StageDesignTokens.space16),
            TextField(
              key: const ValueKey('stage-crew-application-message'),
              controller: _messageController,
              minLines: 5,
              maxLines: 8,
              maxLength: 500,
              onChanged: (_) {
                if (_validationMessage != null) {
                  setState(() => _validationMessage = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'メッセージ（任意）',
                hintText: '経験や参加したい理由を入力してください',
                errorText: _validationMessage,
                filled: true,
                fillColor: StageDesignTokens.surface,
              ),
            ),
            const SizedBox(height: StageDesignTokens.space16),
            FilledButton(
              key: const ValueKey('stage-crew-submit-application'),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('応募を送信する'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.length > 500) {
      setState(() => _validationMessage = '500文字以内で入力してください');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final RecruitmentApplicationState result = await widget.submitApplication(
        postId: widget.recruitment.postId,
        message: message,
      );
      if (!mounted) return;
      if (result.state != 'pending') {
        debugPrint(
          'STAGE Crew application returned unexpected state: ${result.state}',
        );
      }
      Navigator.of(context).pop(true);
    } on Object catch (error, stackTrace) {
      debugPrint('STAGE Crew application failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('応募を送信できませんでした。時間をおいて再度お試しください。')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

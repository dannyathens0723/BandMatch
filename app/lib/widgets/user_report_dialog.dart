import 'package:flutter/material.dart';

class UserReportDialog extends StatefulWidget {
  const UserReportDialog({super.key, required this.onSubmit});

  final Future<void> Function(String reason, String? note) onSubmit;

  @override
  State<UserReportDialog> createState() => _UserReportDialogState();
}

class _UserReportDialogState extends State<UserReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  String _reason = 'harassment';
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.onSubmit(_reason, _noteController.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = '通報を送信できませんでした。時間をおいて再度お試しください。');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ユーザーを通報'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _reason,
                  decoration: const InputDecoration(
                    labelText: '理由',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'harassment', child: Text('迷惑行為')),
                    DropdownMenuItem(
                      value: 'inappropriate_profile',
                      child: Text('不適切なプロフィール'),
                    ),
                    DropdownMenuItem(
                      value: 'impersonation',
                      child: Text('なりすまし'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('その他')),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _reason = value);
                          }
                        },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  enabled: !_isSubmitting,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: '詳細（任意）',
                    hintText: '状況をできるだけ具体的に入力してください',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().length > 1000) {
                      return '詳細は1000文字以内で入力してください。';
                    }
                    return null;
                  },
                ),
                if (_errorMessage case final errorMessage?) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('通報する'),
        ),
      ],
    );
  }
}

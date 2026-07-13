import 'package:flutter/material.dart';

class PasswordResetDialog extends StatefulWidget {
  const PasswordResetDialog({
    super.key,
    required this.initialEmail,
    required this.onSend,
  });

  final String initialEmail;
  final Future<bool> Function(String email) onSend;

  @override
  State<PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<PasswordResetDialog> {
  late final TextEditingController _emailController;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = '有効なメールアドレスを入力してください。');
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
    });
    final wasSent = await widget.onSend(email);
    if (!mounted) return;

    if (wasSent) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isSending = false;
      _error = 'リンクを送信できませんでした。時間をおいて再度お試しください。';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.lock_reset_outlined),
      title: const Text('パスワードを設定 / 再設定'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('設定リンクを送信するメールアドレスを入力してください。'),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                enabled: !_isSending,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'メールアドレス',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _send(),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 12),
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _isSending ? null : _send,
          child: _isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('設定リンクを送信'),
        ),
      ],
    );
  }
}

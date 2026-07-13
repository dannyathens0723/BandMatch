import 'package:flutter/material.dart';

import '../services/message_request_service.dart';

class MessageRequestSheet extends StatefulWidget {
  const MessageRequestSheet({
    super.key,
    required this.receiverName,
    required this.onSubmit,
  });

  final String receiverName;
  final Future<void> Function(String message) onSubmit;

  @override
  State<MessageRequestSheet> createState() => _MessageRequestSheetState();
}

class _MessageRequestSheetState extends State<MessageRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  bool _isSending = false;
  String? _error;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_messageController.text);
      if (mounted) Navigator.of(context).pop(true);
    } on MessageRequestRelationshipExists {
      if (mounted) {
        setState(() => _error = 'すでに保留中のメッセージリクエストがあります。');
      }
    } on ArgumentError catch (error) {
      if (mounted) setState(() => _error = error.message.toString());
    } catch (_) {
      if (mounted) {
        setState(() => _error = '送信できませんでした。時間をおいてもう一度お試しください。');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.receiverName}さんにメッセージを送る',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('リクエストが承認されると、メッセージをやり取りできます。'),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _messageController,
                  enabled: !_isSending,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'メッセージ',
                    hintText: '一緒に演奏してみたい理由などを伝えましょう。',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'メッセージを入力してください。'
                      : null,
                ),
                if (_error case final error?) ...[
                  const SizedBox(height: 8),
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSending ? null : _submit,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: const Text('リクエストを送信'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

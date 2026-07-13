import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'password_reset_dialog.dart';
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initialMessage});

  final String? initialMessage;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _usePasswordLogin = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validatedEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _message = '有効なメールアドレスを入力してください。');
      return null;
    }
    return email;
  }

  Future<void> _sendMagicLink() async {
    final email = _validatedEmail();
    if (email == null) return;

    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: Uri.base.origin,
      );
      if (mounted) {
        setState(() {
          _message = 'サインイン用リンクを送信しました。メールを確認してください。';
        });
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = '送信できませんでした: ${error.message}');
    } catch (_) {
      if (mounted) {
        setState(() => _message = '送信できませんでした。時間をおいて再度お試しください。');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _signInWithPassword() async {
    final email = _validatedEmail();
    if (email == null) return;
    if (_passwordController.text.length < 8) {
      setState(() => _message = 'パスワードは8文字以上で入力してください。');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _passwordController.text,
      );
    } on AuthException catch (_) {
      if (mounted) {
        setState(() {
          _message =
              'メールアドレスまたはパスワードが正しくありません。このメールアドレスはまだパスワードが設定されていない可能性があります。パスワード設定リンクを送信してください。';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'サインインできませんでした。時間をおいて再度お試しください。');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool> _sendPasswordReset(String email) async {
    setState(() {
      _isSubmitting = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: Uri.base.origin,
      );
      if (mounted) {
        setState(() {
          _message = 'パスワード設定リンクを送信しました。メールを確認してください。';
        });
      }
      return true;
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _message = '送信できませんでした: ${error.message}');
      }
      return false;
    } catch (_) {
      if (mounted) {
        setState(() => _message = '送信できませんでした。時間をおいて再度お試しください。');
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.music_note_rounded, size: 44),
                      const SizedBox(height: 20),
                      Text(
                        'BandMatchへようこそ',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text('メールリンクまたはパスワードでサインインできます。'),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _emailController,
                        enabled: !_isSubmitting,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'メールアドレス',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final linkButton = _LoginMethodButton(
                            label: 'メールリンク',
                            icon: Icons.mark_email_read_outlined,
                            isSelected: !_usePasswordLogin,
                            onPressed: _isSubmitting
                                ? null
                                : () => _selectLoginMethod(false),
                          );
                          final passwordButton = _LoginMethodButton(
                            label: 'パスワード',
                            icon: Icons.lock_outline,
                            isSelected: _usePasswordLogin,
                            onPressed: _isSubmitting
                                ? null
                                : () => _selectLoginMethod(true),
                          );

                          if (constraints.maxWidth < 300) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                linkButton,
                                const SizedBox(height: 10),
                                passwordButton,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: linkButton),
                              const SizedBox(width: 12),
                              Expanded(child: passwordButton),
                            ],
                          );
                        },
                      ),
                      if (_usePasswordLogin) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          enabled: !_isSubmitting,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: const InputDecoration(
                            labelText: 'パスワード',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _signInWithPassword(),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSubmitting
                              ? null
                              : _usePasswordLogin
                              ? _signInWithPassword
                              : _sendMagicLink,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  _usePasswordLogin
                                      ? 'パスワードでサインイン'
                                      : 'サインイン用リンクを送る',
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isSubmitting ? null : _showPasswordResetDialog,
                        child: const Text('パスワードを設定 / 再設定'),
                      ),
                      const Text(
                        '初めてパスワードを使うメールリンク登録アカウントにも、設定リンクを送信できます。',
                      ),
                      if (_message case final message?) ...[
                        const SizedBox(height: 16),
                        Text(
                          message,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectLoginMethod(bool usePasswordLogin) {
    setState(() {
      _usePasswordLogin = usePasswordLogin;
      _message = null;
    });
  }

  Future<void> _showPasswordResetDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => PasswordResetDialog(
        initialEmail: _emailController.text.trim(),
        onSend: _sendPasswordReset,
      ),
    );
  }
}

class _LoginMethodButton extends StatelessWidget {
  const _LoginMethodButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFFFFF3CA) : Colors.white,
          foregroundColor: const Color(0xFF3C3100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          side: BorderSide(
            color: isSelected ? const Color(0xFFFFC629) : const Color(0xFF9B9282),
            width: isSelected ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label, maxLines: 1),
      ),
    );
  }
}

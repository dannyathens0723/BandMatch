import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../stage_preview/theme/stage_design_tokens.dart';
import 'password_reset_dialog.dart';

enum AuthScreenPresentation { bandMatch, stage }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.initialMessage,
    this.presentation = AuthScreenPresentation.bandMatch,
  });

  final String? initialMessage;
  final AuthScreenPresentation presentation;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _usePasswordLogin = false;
  bool _showStageEmailControls = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
    _showStageEmailControls =
        widget.presentation == AuthScreenPresentation.stage &&
        widget.initialMessage != null;
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
    final isStage = widget.presentation == AuthScreenPresentation.stage;
    if (isStage) return _buildStageAuthScreen(context);

    final panelContent = Padding(
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
                presentation: widget.presentation,
                onPressed: _isSubmitting
                    ? null
                    : () => _selectLoginMethod(false),
              );
              final passwordButton = _LoginMethodButton(
                label: 'パスワード',
                icon: Icons.lock_outline,
                isSelected: _usePasswordLogin,
                presentation: widget.presentation,
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
                  : Text(_usePasswordLogin ? 'パスワードでサインイン' : 'サインイン用リンクを送る'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isSubmitting ? null : _showPasswordResetDialog,
            child: const Text('パスワードを設定 / 再設定'),
          ),
          const Text('初めてパスワードを使うメールリンク登録アカウントにも、設定リンクを送信できます。'),
          if (_message case final message?) ...[
            const SizedBox(height: 16),
            Text(message, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(child: panelContent),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageAuthScreen(BuildContext context) {
    return Scaffold(
      key: const ValueKey('stage-auth-wireframe'),
      backgroundColor: StageDesignTokens.charcoal,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final horizontalPadding = viewport.maxWidth <= 360
                ? StageDesignTokens.space16
                : StageDesignTokens.space24;
            return Stack(
              children: [
                const Positioned(
                  top: -120,
                  right: -100,
                  child: _StageAuthGlow(
                    color: StageDesignTokens.purple,
                    size: 290,
                  ),
                ),
                const Positioned(
                  bottom: -150,
                  left: -100,
                  child: _StageAuthGlow(
                    color: StageDesignTokens.pink,
                    size: 300,
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: StageDesignTokens.space24,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: StageDesignTokens.maxContentWidth,
                      ),
                      child: _showStageEmailControls
                          ? _buildStageEmailPanel(context)
                          : _buildStageProviderPanel(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStageProviderPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: StageDesignTokens.space32),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFB79CFF), StageDesignTokens.pink],
          ).createShader(bounds),
          child: const Text(
            'STAGE',
            key: ValueKey('stage-auth-wordmark'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              height: 1.1,
              letterSpacing: 5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: StageDesignTokens.space24),
        const Text(
          '誰もがステージの上で輝けるように。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            height: 1.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: StageDesignTokens.space12),
        const Text(
          'イベント・大会を目標に、仲間と出会い、\nクルーを組んで、ステージに立とう。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFC8C1D4),
            fontSize: 13,
            height: 1.65,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 72),
        _StageProviderButton(
          key: const ValueKey('stage-auth-line'),
          label: 'LINEで続ける',
          backgroundColor: const Color(0xFF06C755),
          foregroundColor: Colors.white,
          icon: const _StageProviderMonogram(label: 'L'),
          onPressed: _isSubmitting
              ? null
              : () => _showProviderUnavailable('LINE'),
        ),
        const SizedBox(height: 10),
        _StageProviderButton(
          key: const ValueKey('stage-auth-apple'),
          label: 'Appleで続ける',
          backgroundColor: Colors.white,
          foregroundColor: StageDesignTokens.charcoal,
          icon: const Icon(Icons.apple, size: 22),
          onPressed: _isSubmitting
              ? null
              : () => _showProviderUnavailable('Apple'),
        ),
        const SizedBox(height: 10),
        _StageProviderButton(
          key: const ValueKey('stage-auth-email-register'),
          label: 'メールアドレスで登録',
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          borderColor: const Color(0xFF3D3550),
          icon: const Icon(Icons.mail_outline_rounded, size: 21),
          onPressed: _isSubmitting
              ? null
              : () => _openStageEmailControls(usePasswordLogin: false),
        ),
        const SizedBox(height: StageDesignTokens.space8),
        TextButton(
          key: const ValueKey('stage-auth-existing-login'),
          onPressed: _isSubmitting
              ? null
              : () => _openStageEmailControls(usePasswordLogin: true),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFD8D1E5)),
          child: const Text(
            'ログイン（登録済みの方）',
            style: TextStyle(decoration: TextDecoration.underline),
          ),
        ),
        if (_message case final message?) ...[
          const SizedBox(height: StageDesignTokens.space8),
          _StageAuthMessage(message: message),
        ],
        const SizedBox(height: StageDesignTokens.space20),
        const Text(
          '続けることで利用規約・プライバシーポリシーに同意したものとみなされます。',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF91899F), fontSize: 10, height: 1.5),
        ),
        const SizedBox(height: StageDesignTokens.space8),
        const Text(
          '10代の方は保護者の方と確認のうえご利用ください（検討中）。',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF91899F), fontSize: 10, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildStageEmailPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('stage-auth-provider-back'),
            onPressed: _isSubmitting ? null : _closeStageEmailControls,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            label: const Text('ログイン方法に戻る'),
          ),
        ),
        const SizedBox(height: StageDesignTokens.space12),
        const Text(
          'STAGE',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            height: 1.1,
            letterSpacing: 4,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: StageDesignTokens.space24),
        DecoratedBox(
          decoration: BoxDecoration(
            color: StageDesignTokens.surface,
            borderRadius: BorderRadius.circular(StageDesignTokens.radius20),
            boxShadow: StageDesignTokens.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(StageDesignTokens.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _usePasswordLogin ? 'STAGEにログイン' : 'メールでSTAGEを始める',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: StageDesignTokens.space8),
                Text(
                  _usePasswordLogin
                      ? '登録済みのメールアドレスとパスワードを入力してください。'
                      : '安全なサインイン用リンクをメールでお送りします。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: StageDesignTokens.space24),
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
                const SizedBox(height: StageDesignTokens.space16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final linkButton = _LoginMethodButton(
                      label: 'メールリンク',
                      icon: Icons.mark_email_read_outlined,
                      isSelected: !_usePasswordLogin,
                      presentation: widget.presentation,
                      onPressed: _isSubmitting
                          ? null
                          : () => _selectLoginMethod(false),
                    );
                    final passwordButton = _LoginMethodButton(
                      label: 'パスワード',
                      icon: Icons.lock_outline,
                      isSelected: _usePasswordLogin,
                      presentation: widget.presentation,
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
                  const SizedBox(height: StageDesignTokens.space16),
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
                const SizedBox(height: StageDesignTokens.space16),
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
                            _usePasswordLogin ? 'パスワードでサインイン' : 'サインイン用リンクを送る',
                          ),
                  ),
                ),
                const SizedBox(height: StageDesignTokens.space8),
                TextButton(
                  onPressed: _isSubmitting ? null : _showPasswordResetDialog,
                  child: const Text('パスワードを設定 / 再設定'),
                ),
                const Text('初めてパスワードを使うメールリンク登録アカウントにも、設定リンクを送信できます。'),
                if (_message case final message?) ...[
                  const SizedBox(height: StageDesignTokens.space16),
                  Text(message, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openStageEmailControls({required bool usePasswordLogin}) {
    setState(() {
      _showStageEmailControls = true;
      _usePasswordLogin = usePasswordLogin;
      _message = null;
    });
  }

  void _closeStageEmailControls() {
    setState(() {
      _showStageEmailControls = false;
      _message = null;
    });
  }

  void _showProviderUnavailable(String provider) {
    setState(() => _message = '$providerログインは現在準備中です');
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

class _StageAuthGlow extends StatelessWidget {
  const _StageAuthGlow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.16), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _StageProviderButton extends StatelessWidget {
  const _StageProviderButton({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.onPressed,
    this.borderColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.45),
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.65),
          side: borderColor == null ? null : BorderSide(color: borderColor!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StageDesignTokens.radius12),
          ),
        ),
        icon: icon,
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _StageProviderMonogram extends StatelessWidget {
  const _StageProviderMonogram({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StageAuthMessage extends StatelessWidget {
  const _StageAuthMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(StageDesignTokens.radius12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StageDesignTokens.space12,
          vertical: StageDesignTokens.space8,
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _LoginMethodButton extends StatelessWidget {
  const _LoginMethodButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.presentation,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final AuthScreenPresentation presentation;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isStage = presentation == AuthScreenPresentation.stage;
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isStage
              ? isSelected
                    ? StageDesignTokens.surfaceMuted
                    : StageDesignTokens.surface
              : isSelected
              ? const Color(0xFFFFF3CA)
              : Colors.white,
          foregroundColor: isStage
              ? isSelected
                    ? StageDesignTokens.purple
                    : StageDesignTokens.textSecondary
              : const Color(0xFF3C3100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          side: BorderSide(
            color: isStage
                ? isSelected
                      ? StageDesignTokens.purple
                      : StageDesignTokens.border
                : isSelected
                ? const Color(0xFFFFC629)
                : const Color(0xFF9B9282),
            width: isSelected ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label, maxLines: 1),
      ),
    );
  }
}

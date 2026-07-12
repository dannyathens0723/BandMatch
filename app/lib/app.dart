import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'services/profile_service.dart';
import 'theme/app_theme.dart';

class BandMatchApp extends StatelessWidget {
  const BandMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BandMatch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AppConfig.isSupabaseConfigured
          ? const AuthGate()
          : const SupabaseConfigurationScreen(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _profileService = ProfileService();
  late final StreamSubscription<AuthState> _authSubscription;
  _GateState _state = _GateState.loading;
  User? _user;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => _resolveCurrentUser(),
    );
    _resolveCurrentUser();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _resolveCurrentUser() async {
    final requestId = ++_requestId;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _state = _GateState.auth);
      return;
    }

    setState(() {
      _state = _GateState.loading;
      _error = null;
    });
    try {
      final profile = await _profileService.fetchCurrentProfile(user.id);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _user = user;
        _state = profile == null ? _GateState.profileSetup : _GateState.home;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = '$error';
        _state = _GateState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _GateState.auth => const AuthScreen(),
      _GateState.profileSetup => ProfileSetupScreen(
        authUser: _user!,
        onSaved: _resolveCurrentUser,
      ),
      _GateState.home => const HomeScreen(),
      _GateState.error => _AuthGateError(
        error: _error!,
        onRetry: _resolveCurrentUser,
      ),
      _GateState.loading => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

enum _GateState { loading, auth, profileSetup, home, error }

class _AuthGateError extends StatelessWidget {
  const _AuthGateError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 16),
                const Text('アカウント状態を確認できません'),
                const SizedBox(height: 8),
                Text(error),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('再試行')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SupabaseConfigurationScreen extends StatelessWidget {
  const SupabaseConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.settings_ethernet_outlined, size: 40),
                  SizedBox(height: 16),
                  Text('Supabase の接続設定が必要です'),
                  SizedBox(height: 8),
                  Text(
                    'SUPABASE_URL と SUPABASE_ANON_KEY を --dart-define で指定して起動してください。',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'screens/home_screen.dart';
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
          ? const HomeScreen()
          : const SupabaseConfigurationScreen(),
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

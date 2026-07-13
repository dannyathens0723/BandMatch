import 'package:flutter_test/flutter_test.dart';

import 'package:app/app.dart';
import 'package:app/services/auth_callback.dart';

void main() {
  testWidgets('Supabase settings prompt is shown when no defines are set', (
    tester,
  ) async {
    await tester.pumpWidget(const BandMatchApp());

    expect(find.text('Supabase の接続設定が必要です'), findsOneWidget);
  });

  test('expired magic link is converted to a friendly auth message', () {
    final callback = AuthCallbackInfo.fromUri(
      Uri.parse(
        'http://localhost:3000/?error=access_denied&error_code=otp_expired',
      ),
    );

    expect(callback.hasAuthParameters, isTrue);
    expect(callback.authErrorMessage, contains('有効期限'));
  });

  test('password recovery callback is detected safely', () {
    final callback = AuthCallbackInfo.fromUri(
      Uri.parse('http://localhost:3000/?code=recovery-code&type=recovery'),
    );

    expect(callback.hasAuthParameters, isTrue);
    expect(callback.isPasswordRecovery, isTrue);
  });
}

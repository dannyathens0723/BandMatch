import 'package:flutter_test/flutter_test.dart';

import 'package:app/app.dart';

void main() {
  testWidgets('Supabase settings prompt is shown when no defines are set', (
    tester,
  ) async {
    await tester.pumpWidget(const BandMatchApp());

    expect(find.text('Supabase の接続設定が必要です'), findsOneWidget);
  });
}

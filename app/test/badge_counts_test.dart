import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/models/badge_counts.dart';
import 'package:app/widgets/count_badge.dart';

void main() {
  test('BadgeCounts parses safe non-negative counts', () {
    final counts = BadgeCounts.fromJson({
      'pending_message_request_count': 3,
      'pending_recruitment_application_count': '7',
      'unread_chat_message_count': 4,
    });

    expect(counts.pendingMessageRequestCount, 3);
    expect(counts.pendingRecruitmentApplicationCount, 7);
    expect(counts.unreadChatMessageCount, 4);
  });

  test('BadgeCounts treats a missing unread field as zero', () {
    final counts = BadgeCounts.fromJson({
      'pending_message_request_count': 1,
      'pending_recruitment_application_count': 2,
    });

    expect(counts.unreadChatMessageCount, 0);
  });

  testWidgets('CountBadge hides zero and caps large labels at 99+', (
    tester,
  ) async {
    Future<void> pumpBadge(int count) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountBadge(
              count: count,
              semanticLabel: '未対応',
              child: const Icon(Icons.mail_outline),
            ),
          ),
        ),
      );
    }

    await pumpBadge(0);
    expect(find.byType(Badge), findsNothing);

    await pumpBadge(5);
    expect(find.text('5'), findsOneWidget);

    await pumpBadge(100);
    expect(find.text('99+'), findsOneWidget);
  });
}

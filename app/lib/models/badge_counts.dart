class BadgeCounts {
  const BadgeCounts({
    required this.pendingMessageRequestCount,
    required this.pendingRecruitmentApplicationCount,
    required this.unreadChatMessageCount,
  });

  const BadgeCounts.empty()
    : pendingMessageRequestCount = 0,
      pendingRecruitmentApplicationCount = 0,
      unreadChatMessageCount = 0;

  final int pendingMessageRequestCount;
  final int pendingRecruitmentApplicationCount;
  final int unreadChatMessageCount;

  factory BadgeCounts.fromJson(Map<String, dynamic> json) {
    return BadgeCounts(
      pendingMessageRequestCount: _nonNegativeInt(
        json['pending_message_request_count'],
      ),
      pendingRecruitmentApplicationCount: _nonNegativeInt(
        json['pending_recruitment_application_count'],
      ),
      unreadChatMessageCount: _nonNegativeInt(
        json['unread_chat_message_count'],
      ),
    );
  }

  static int _nonNegativeInt(dynamic value) {
    final parsed = switch (value) {
      int count => count,
      num count => count.toInt(),
      String count => int.tryParse(count) ?? 0,
      _ => 0,
    };
    return parsed < 0 ? 0 : parsed;
  }
}

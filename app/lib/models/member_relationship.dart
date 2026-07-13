enum MemberRelationshipState {
  none,
  outgoingPending,
  incomingPending,
  accepted,
  roomExists,
  rejected,
}

class MemberRelationship {
  const MemberRelationship({
    required this.state,
    this.requestId,
    this.roomId,
  });

  final MemberRelationshipState state;
  final String? requestId;
  final String? roomId;

  factory MemberRelationship.fromJson(Map<String, dynamic> json) {
    return MemberRelationship(
      state: switch (json['state'] as String? ?? 'none') {
        'outgoing_pending' => MemberRelationshipState.outgoingPending,
        'incoming_pending' => MemberRelationshipState.incomingPending,
        'accepted' => MemberRelationshipState.accepted,
        'room_exists' => MemberRelationshipState.roomExists,
        'rejected' => MemberRelationshipState.rejected,
        _ => MemberRelationshipState.none,
      },
      requestId: json['request_id'] as String?,
      roomId: json['room_id'] as String?,
    );
  }
}

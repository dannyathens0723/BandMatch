enum UserSafetyState {
  none,
  blockedByMe,
  blockedMe,
  unavailable;

  bool get preventsInteraction => this != UserSafetyState.none;

  factory UserSafetyState.fromValue(String? value) {
    return switch (value) {
      'none' => UserSafetyState.none,
      'blocked_by_me' => UserSafetyState.blockedByMe,
      'blocked_me' => UserSafetyState.blockedMe,
      _ => UserSafetyState.unavailable,
    };
  }
}

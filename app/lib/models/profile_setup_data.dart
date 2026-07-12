import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  const UserProfile({required this.id});

  final String id;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(id: json['id'] as String);
  }
}

class ProfileSetupData {
  const ProfileSetupData({
    required this.authUser,
    required this.displayName,
    required this.birthDate,
    required this.purpose,
    required this.partIds,
    required this.experienceLevel,
    required this.genreIds,
    required this.areaIds,
  });

  final User authUser;
  final String displayName;
  final DateTime birthDate;
  final String purpose;
  final Set<String> partIds;
  final String experienceLevel;
  final Set<String> genreIds;
  final Set<String> areaIds;
}

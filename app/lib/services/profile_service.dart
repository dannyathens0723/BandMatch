import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_setup_data.dart';

class ProfileService {
  ProfileService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<UserProfile?> fetchCurrentProfile(String authUserId) async {
    final row = await _client
        .from('users')
        .select('id')
        .eq('auth_uid', authUserId)
        .maybeSingle();

    return row == null ? null : UserProfile.fromJson(row);
  }

  Future<void> saveProfile(ProfileSetupData data) async {
    final email = data.authUser.email;
    if (email == null || email.isEmpty) {
      throw StateError('認証済みメールアドレスを取得できませんでした。');
    }

    final existingProfile = await fetchCurrentProfile(data.authUser.id);
    final profileId = existingProfile?.id ?? data.authUser.id;
    final profileFields = {
      'display_name': data.displayName,
      'birth_date': _dateOnly(data.birthDate),
      'experience_level': data.experienceLevel,
    };

    if (existingProfile == null) {
      await _client.from('users').insert({
        'id': profileId,
        'auth_uid': data.authUser.id,
        'email': email,
        'phone_verified': false,
        'premium_boost': 1.0,
        'account_status': 'active',
        ...profileFields,
      });
    } else {
      await _client.from('users').update(profileFields).eq('id', profileId);
    }

    await Future.wait([
      _replaceRows('user_purposes', profileId, 'purpose', {data.purpose}),
      _replaceRows('user_parts', profileId, 'part_id', data.partIds),
      _replaceRows('user_genres', profileId, 'genre_id', data.genreIds),
      _replaceRows('user_areas', profileId, 'area_id', data.areaIds),
    ]);
  }

  Future<void> _replaceRows(
    String table,
    String profileId,
    String valueColumn,
    Set<String> values,
  ) async {
    await _client.from(table).delete().eq('user_id', profileId);
    if (values.isEmpty) return;

    await _client
        .from(table)
        .insert(
          values
              .map((value) => {'user_id': profileId, valueColumn: value})
              .toList(),
        );
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

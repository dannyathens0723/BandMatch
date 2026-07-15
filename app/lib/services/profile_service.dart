import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/editable_profile.dart';
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

  Future<EditableProfile> fetchEditableProfile() async {
    try {
      final profileId = await _fetchCurrentProfileId();
      final results = await Future.wait<dynamic>([
        _client
            .from('users')
            .select('id, display_name, avatar_url, experience_level')
            .eq('id', profileId)
            .single(),
        _client
            .from('user_purposes')
            .select('purpose')
            .eq('user_id', profileId),
        _client.from('user_parts').select('part_id').eq('user_id', profileId),
        _client.from('user_genres').select('genre_id').eq('user_id', profileId),
        _client.from('user_areas').select('area_id').eq('user_id', profileId),
      ]);

      final profile = results[0] as Map<String, dynamic>;
      return EditableProfile(
        id: profile['id'] as String,
        displayName: profile['display_name'] as String,
        avatarUrl: profile['avatar_url'] as String?,
        experienceLevel: profile['experience_level'] as String?,
        purposes: _stringValues(results[1], 'purpose'),
        partIds: _stringValues(results[2], 'part_id'),
        genreIds: _stringValues(results[3], 'genre_id'),
        areaIds: _stringValues(results[4], 'area_id'),
      );
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestError('Profile edit load failed', error, stackTrace);
      rethrow;
    }
  }

  Future<void> updateCurrentProfile(ProfileEditData data) async {
    try {
      final profileId = await _fetchCurrentProfileId();
      await _client
          .from('users')
          .update({
            'display_name': data.displayName.trim(),
            'experience_level': data.experienceLevel,
          })
          .eq('id', profileId);

      await Future.wait([
        _replaceRows('user_purposes', profileId, 'purpose', data.purposes),
        _replaceRows('user_parts', profileId, 'part_id', data.partIds),
        _replaceRows('user_genres', profileId, 'genre_id', data.genreIds),
        _replaceRows('user_areas', profileId, 'area_id', data.areaIds),
      ]);
    } on PostgrestException catch (error, stackTrace) {
      _logPostgrestError('Profile edit save failed', error, stackTrace);
      rethrow;
    }
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

  Future<String> _fetchCurrentProfileId() async {
    final profileId = await _client.rpc('current_user_id');
    if (profileId is! String || profileId.isEmpty) {
      throw StateError('プロフィールが見つかりません。');
    }
    return profileId;
  }

  Set<String> _stringValues(dynamic response, String column) {
    return (response as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)[column] as String)
        .toSet();
  }

  void _logPostgrestError(
    String prefix,
    PostgrestException error,
    StackTrace stackTrace,
  ) {
    debugPrint(
      '$prefix: message=${error.message}, code=${error.code}, '
      'details=${error.details}, hint=${error.hint}\n$stackTrace',
    );
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

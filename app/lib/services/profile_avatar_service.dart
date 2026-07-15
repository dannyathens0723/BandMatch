import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/picked_avatar_file.dart';
import 'avatar_file_picker.dart';

class ProfileAvatarUploadResult {
  const ProfileAvatarUploadResult({required this.avatarUrl});

  final String avatarUrl;
}

enum ProfileAvatarUploadFailureReason {
  canceled,
  unsupportedPlatform,
  unsupportedType,
  fileTooLarge,
  uploadFailed,
}

class ProfileAvatarUploadException implements Exception {
  const ProfileAvatarUploadException(this.reason, [this.message]);

  final ProfileAvatarUploadFailureReason reason;
  final String? message;

  @override
  String toString() => message ?? reason.name;
}

class ProfileAvatarService {
  ProfileAvatarService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const maxFileSizeBytes = 5 * 1024 * 1024;
  static const bucketName = 'avatars';

  final SupabaseClient _client;

  Future<ProfileAvatarUploadResult> pickAndUploadAvatar() async {
    try {
      final image = await pickAvatarFile();
      if (image == null) {
        throw const ProfileAvatarUploadException(
          ProfileAvatarUploadFailureReason.canceled,
        );
      }

      final fileInfo = _validateImage(image);
      final profileId = await _fetchCurrentProfileId();
      final objectPath =
          '$profileId/profile_${DateTime.now().millisecondsSinceEpoch}.${fileInfo.extension}';

      await _client.storage
          .from(bucketName)
          .uploadBinary(
            objectPath,
            image.bytes,
            fileOptions: FileOptions(
              contentType: fileInfo.mimeType,
              cacheControl: '3600',
              upsert: false,
            ),
          );

      final publicUrl = _client.storage
          .from(bucketName)
          .getPublicUrl(objectPath);
      final updatedUrl = await _client.rpc(
        'update_my_avatar_url',
        params: {'p_avatar_url': publicUrl},
      );

      return ProfileAvatarUploadResult(avatarUrl: updatedUrl as String);
    } on UnsupportedError catch (error, stackTrace) {
      debugPrint('Avatar picker is not supported on this platform: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const ProfileAvatarUploadException(
        ProfileAvatarUploadFailureReason.unsupportedPlatform,
      );
    } on ProfileAvatarUploadException {
      rethrow;
    } on StorageException catch (error, stackTrace) {
      _logStorageError(error, stackTrace);
      throw const ProfileAvatarUploadException(
        ProfileAvatarUploadFailureReason.uploadFailed,
      );
    } on PostgrestException catch (error, stackTrace) {
      debugPrint(
        'Avatar URL update failed: message=${error.message}, '
        'code=${error.code}, details=${error.details}, hint=${error.hint}',
      );
      debugPrintStack(stackTrace: stackTrace);
      throw const ProfileAvatarUploadException(
        ProfileAvatarUploadFailureReason.uploadFailed,
      );
    } catch (error, stackTrace) {
      debugPrint('Avatar upload failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw const ProfileAvatarUploadException(
        ProfileAvatarUploadFailureReason.uploadFailed,
      );
    }
  }

  _AvatarFileInfo _validateImage(PickedAvatarFile image) {
    if (image.bytes.length > maxFileSizeBytes) {
      throw const ProfileAvatarUploadException(
        ProfileAvatarUploadFailureReason.fileTooLarge,
      );
    }

    final extension = _extensionFromName(image.name);
    final mimeType = _mimeTypeForExtension(extension) ?? image.mimeType;
    final normalizedExtension = _extensionForMimeType(mimeType) ?? extension;
    final normalizedMimeType =
        _mimeTypeForExtension(normalizedExtension) ?? mimeType;

    if (normalizedExtension == null || normalizedMimeType == null) {
      throw const ProfileAvatarUploadException(
        ProfileAvatarUploadFailureReason.unsupportedType,
      );
    }

    return _AvatarFileInfo(
      extension: normalizedExtension,
      mimeType: normalizedMimeType,
    );
  }

  String? _extensionFromName(String name) {
    final lowerName = name.toLowerCase();
    final dotIndex = lowerName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == lowerName.length - 1) return null;
    final extension = lowerName.substring(dotIndex + 1);
    return switch (extension) {
      'jpg' || 'jpeg' => 'jpg',
      'png' => 'png',
      'webp' => 'webp',
      _ => null,
    };
  }

  String? _mimeTypeForExtension(String? extension) {
    return switch (extension) {
      'jpg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
  }

  String? _extensionForMimeType(String? mimeType) {
    return switch (mimeType?.toLowerCase()) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => null,
    };
  }

  Future<String> _fetchCurrentProfileId() async {
    final profileId = await _client.rpc('current_user_id');
    if (profileId is! String || profileId.isEmpty) {
      throw StateError('Profile was not found.');
    }
    return profileId;
  }

  void _logStorageError(StorageException error, StackTrace stackTrace) {
    debugPrint(
      'Avatar storage upload failed: message=${error.message}, '
      'statusCode=${error.statusCode}, error=${error.error}',
    );
    debugPrintStack(stackTrace: stackTrace);
  }
}

class _AvatarFileInfo {
  const _AvatarFileInfo({required this.extension, required this.mimeType});

  final String extension;
  final String mimeType;
}

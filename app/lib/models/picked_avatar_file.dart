import 'dart:typed_data';

class PickedAvatarFile {
  const PickedAvatarFile({
    required this.name,
    required this.bytes,
    this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final String? mimeType;
}

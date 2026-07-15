import '../models/picked_avatar_file.dart';
import 'avatar_file_picker_stub.dart'
    if (dart.library.js_interop) 'avatar_file_picker_web.dart'
    as impl;

Future<PickedAvatarFile?> pickAvatarFile() => impl.pickAvatarFile();

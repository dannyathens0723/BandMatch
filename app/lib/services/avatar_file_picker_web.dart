import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../models/picked_avatar_file.dart';

Future<PickedAvatarFile?> pickAvatarFile() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/jpeg,image/png,image/webp';

  final file = await _pickFile(input);
  if (file == null) return null;

  final bytes = (await file.arrayBuffer().toDart).toDart.asUint8List();
  final mimeType = file.type.trim().isEmpty ? null : file.type;

  return PickedAvatarFile(name: file.name, bytes: bytes, mimeType: mimeType);
}

Future<web.File?> _pickFile(web.HTMLInputElement input) {
  final completer = Completer<web.File?>();

  late final web.EventListener changeListener;
  late final web.EventListener cancelListener;

  void complete(web.File? file) {
    if (!completer.isCompleted) {
      completer.complete(file);
    }
    input.removeEventListener('change', changeListener);
    input.removeEventListener('cancel', cancelListener);
  }

  changeListener = ((web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      complete(null);
      return;
    }
    complete(files.item(0));
  }).toJS;

  cancelListener = ((web.Event _) {
    complete(null);
  }).toJS;

  input.addEventListener('change', changeListener);
  input.addEventListener('cancel', cancelListener);
  input.click();

  return completer.future;
}

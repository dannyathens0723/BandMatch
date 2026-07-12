import 'package:web/web.dart' as web;

void cleanAuthCallbackUrl(Uri uri) {
  final cleanUri = uri.replace(queryParameters: const {}, fragment: '');
  web.window.history.replaceState(null, '', cleanUri.toString());
}

import 'auth_url_cleaner_stub.dart'
    if (dart.library.js_interop) 'auth_url_cleaner_web.dart'
    as url_cleaner;

class AuthCallbackInfo {
  const AuthCallbackInfo({
    required this.hasAuthParameters,
    this.authErrorMessage,
  });

  final bool hasAuthParameters;
  final String? authErrorMessage;

  static const _authParameterNames = {
    'error',
    'error_code',
    'error_description',
    'code',
    'token',
    'access_token',
    'refresh_token',
  };

  factory AuthCallbackInfo.fromUri(Uri uri) {
    final parameters = <String, String>{...uri.queryParameters};
    if (uri.fragment.contains('=')) {
      try {
        parameters.addAll(Uri.splitQueryString(uri.fragment));
      } on FormatException {
        // A malformed callback fragment must not prevent the auth screen from
        // rendering. The query parameters can still be handled safely.
      }
    }

    final hasAuthParameters = parameters.keys.any(_authParameterNames.contains);
    final errorDescription = parameters['error_description'];
    final errorCode = parameters['error_code'];
    final hasError = parameters.containsKey('error') || errorCode != null;

    return AuthCallbackInfo(
      hasAuthParameters: hasAuthParameters,
      authErrorMessage: hasError
          ? _messageForError(errorCode, errorDescription)
          : null,
    );
  }

  static String _messageForError(String? code, String? description) {
    if (code == 'otp_expired' || description?.contains('expired') == true) {
      return 'サインイン用リンクの有効期限が切れています。新しいリンクを送信してください。';
    }
    return 'サインイン用リンクを確認できませんでした。新しいリンクを送信してください。';
  }
}

void cleanAuthCallbackUrl(Uri uri) {
  url_cleaner.cleanAuthCallbackUrl(uri);
}

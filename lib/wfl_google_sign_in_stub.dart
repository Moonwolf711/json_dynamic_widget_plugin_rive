/// Stub for Google Sign-In on unsupported platforms (Windows/Linux desktop)
/// The actual google_sign_in package doesn't work on Windows desktop,
/// so we provide stub classes that gracefully fail.

class GoogleSignIn {
  static final GoogleSignIn instance = GoogleSignIn._();
  GoogleSignIn._();

  Future<void> initialize() async {}

  Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      const Stream.empty();

  void attemptLightweightAuthentication() {}

  bool supportsAuthenticate() => false;

  Future<GoogleSignInAccount?> authenticate() async => null;

  Future<void> signOut() async {}
}

class GoogleSignInAccount {
  final GoogleSignInAuthorizationClient authorizationClient =
      GoogleSignInAuthorizationClient();
}

class GoogleSignInAuthorizationClient {
  Future<GoogleSignInAuthorization> authorizeScopes(List<String> scopes) async {
    throw UnsupportedError('Google Sign-In not supported on this platform');
  }
}

class GoogleSignInAuthorization {
  String get accessToken => '';
}

abstract class GoogleSignInAuthenticationEvent {}

class GoogleSignInAuthenticationEventSignIn extends GoogleSignInAuthenticationEvent {
  final GoogleSignInAccount user;
  GoogleSignInAuthenticationEventSignIn(this.user);
}

class GoogleSignInAuthenticationEventSignOut extends GoogleSignInAuthenticationEvent {}

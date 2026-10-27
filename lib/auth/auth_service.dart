/// The signed-in person.
class AuthUser {
  const AuthUser(this.uid, this.email, {this.hasPassword = true});

  final String uid;
  final String email;

  /// False for an account that signed in with Google only: the plugin signs
  /// in with email and password, so such an account must set one.
  final bool hasPassword;
}

/// A sign-in problem with a message fit to show to a person.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Everything the app asks of the account system. The app talks to this
/// interface only; Firebase sits behind one implementation and tests use a fake.
abstract class AuthService {
  /// The signed-in person, or null; emits again when it changes.
  Stream<AuthUser?> get user;

  Future<void> signIn(String email, String password, {required bool remember});
  Future<void> createAccount(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> sendPasswordReset(String email);

  /// Gives a Google account an email-and-password login too, for the plugin.
  Future<void> setPluginPassword(String password);

  Future<void> signOut();
}

/// One plain sentence for a Firebase error code.
String friendlyAuthError(String code) {
  switch (code) {
    case 'wrong-password':
    case 'invalid-credential':
    case 'user-not-found':
      return 'That email and password do not match. If you signed up with Google, use Sign in with Google, or Forgot password to add a password.';
    case 'email-already-in-use':
      return 'An account with this email already exists. Try signing in, or use Sign in with Google if that is how you joined.';
    case 'weak-password':
      return 'Choose a longer password (at least 6 characters).';
    case 'invalid-email':
      return 'That email address does not look right.';
    case 'network-request-failed':
      return 'No connection. Check your internet and try again.';
    case 'too-many-requests':
      return 'Too many tries. Wait a minute and try again.';
    case 'requires-recent-login':
      return 'For safety, sign out, sign in with Google again, then retry.';
    case 'popup-closed-by-user':
    case 'canceled':
      return 'Google sign-in was cancelled.';
    case 'cancelled-popup-request':
      return 'Another sign-in window was already open. Try once more.';
    case 'popup-blocked':
      return 'The browser blocked the Google window. Allow pop-ups for this site and try again.';
    case 'operation-not-allowed':
      return 'This sign-in method is switched off for the app. Ask the owner to turn it on.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'provider-already-linked':
      return 'This account already has a password. Use it in the plugin settings.';
    case 'credential-already-in-use':
      return 'That email already has a password login on another account.';
    case 'account-exists-with-different-credential':
      return 'This email is already used with another sign-in method.';
    default:
      return 'Something went wrong. Try again.';
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'auth_service.dart';

const rememberKey = 'remember';
const emailKey = 'email';

/// The Firebase implementation of [AuthService]. Every Firebase error is
/// turned into an [AuthFailure] with a plain sentence.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  bool _googleReady = false;

  AuthUser? _map(User? u) => u == null
      ? null
      : AuthUser(
          u.uid,
          u.email ?? '',
          hasPassword: u.providerData.any((p) => p.providerId == 'password'),
        );

  @override
  Stream<AuthUser?> get user => _auth.userChanges().map(_map);

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(friendlyAuthError(e.code));
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw AuthFailure(friendlyAuthError(''));
    }
  }

  @override
  Future<void> signIn(
    String email,
    String password, {
    required bool remember,
  }) => _guard(() async {
    // On the web the sign-in survives a closed tab only when "remember me"
    // is on; the phone app handles it at the next start (see main.dart).
    if (kIsWeb)
      await _auth.setPersistence(
        remember ? Persistence.LOCAL : Persistence.SESSION,
      );
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(rememberKey, remember);
    if (remember) {
      await prefs.setString(emailKey, email.trim());
    } else {
      await prefs.remove(emailKey);
    }
  });

  /// A new account or a Google sign-in clears an earlier "don't remember me",
  /// so the next app start does not sign the person out.
  Future<void> _rememberThisSignIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(rememberKey, true);
  }

  @override
  Future<void> createAccount(String email, String password) => _guard(() async {
    if (kIsWeb) await _auth.setPersistence(Persistence.LOCAL);
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _rememberThisSignIn();
  });

  @override
  Future<void> signInWithGoogle() => _guard(() async {
    if (kIsWeb) {
      await _auth.setPersistence(Persistence.LOCAL);
      await _auth.signInWithPopup(GoogleAuthProvider());
      await _rememberThisSignIn();
      return;
    }
    if (googleWebClientId.isEmpty) {
      throw const AuthFailure(
        'Google sign-in is not set up on this phone yet.',
      );
    }
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(serverClientId: googleWebClientId);
      _googleReady = true;
    }
    try {
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null)
        throw const AuthFailure(
          'Google did not return a sign-in token. Try again.',
        );
      await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      await _rememberThisSignIn();
    } on GoogleSignInException catch (e) {
      throw AuthFailure(
        friendlyAuthError(
          e.code == GoogleSignInExceptionCode.canceled ? 'canceled' : '',
        ),
      );
    }
  });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> setPluginPassword(String password) => _guard(() async {
    final u = _auth.currentUser;
    final email = u?.email;
    if (u == null || email == null) throw const AuthFailure('Sign in first.');
    await u.linkWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
    await u.reload();
  });

  @override
  Future<void> signOut() async {
    try {
      if (!kIsWeb && _googleReady) await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Signing out of Firebase below is what matters.
    }
    await _auth.signOut();
  }
}

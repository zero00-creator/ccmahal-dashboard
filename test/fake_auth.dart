import 'dart:async';

import 'package:ccmahal_dashboard/auth/auth_service.dart';

/// An [AuthService] for tests: records every call, can be told to fail the
/// next one with a Firebase error code, and can hold a call open.
class FakeAuthService implements AuthService {
  FakeAuthService({this.initialUser});

  final List<String> calls = [];
  final _controller = StreamController<AuthUser?>.broadcast();
  final AuthUser? initialUser;

  /// The Firebase code the next call fails with (then it is cleared).
  String? failWith;

  /// While set, every call waits for it.
  Completer<void>? hold;

  @override
  Stream<AuthUser?> get user async* {
    yield initialUser;
    yield* _controller.stream;
  }

  Future<void> _run(String call) async {
    calls.add(call);
    if (hold != null) await hold!.future;
    final code = failWith;
    if (code != null) {
      failWith = null;
      throw AuthFailure(friendlyAuthError(code));
    }
  }

  @override
  Future<void> signIn(
    String email,
    String password, {
    required bool remember,
  }) => _run('signIn:$email:$remember');

  @override
  Future<void> createAccount(String email, String password) =>
      _run('createAccount:$email');

  @override
  Future<void> signInWithGoogle() => _run('google');

  @override
  Future<void> sendPasswordReset(String email) => _run('reset:$email');

  @override
  Future<void> setPluginPassword(String password) => _run('setPluginPassword');

  @override
  Future<void> signOut() => _run('signOut');
}

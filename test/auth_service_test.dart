import 'package:ccmahal_dashboard/auth/auth_service.dart';
import 'package:ccmahal_dashboard/paths.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth.dart';

void main() {
  test('friendlyAuthError gives one plain sentence for each known code', () {
    const codes = [
      'wrong-password',
      'invalid-credential',
      'user-not-found',
      'email-already-in-use',
      'weak-password',
      'invalid-email',
      'network-request-failed',
      'too-many-requests',
      'requires-recent-login',
      'popup-closed-by-user',
      'account-exists-with-different-credential',
    ];
    final seen = <String>{};
    for (final c in codes) {
      final m = friendlyAuthError(c);
      expect(m, isNotEmpty, reason: c);
      expect(m, isNot(contains('firebase')), reason: c);
      expect(m, isNot(contains(c)), reason: c);
      seen.add(m);
    }
    expect(
      friendlyAuthError('wrong-password'),
      friendlyAuthError('invalid-credential'),
    );
    expect(seen.length, greaterThanOrEqualTo(codes.length - 2));
  });

  test(
    'sign-in and sign-up errors point a Google user to the right way in',
    () {
      for (final c in [
        'wrong-password',
        'invalid-credential',
        'user-not-found',
        'email-already-in-use',
      ]) {
        expect(friendlyAuthError(c), contains('Google'), reason: c);
      }
    },
  );

  test('every code a Google or password-link attempt can raise has its own sentence', () {
    final generic = friendlyAuthError('');
    for (final c in [
      'popup-blocked',
      'cancelled-popup-request',
      'operation-not-allowed',
      'user-disabled',
      'provider-already-linked',
      'credential-already-in-use',
    ]) {
      expect(friendlyAuthError(c), isNot(generic), reason: c);
    }
    expect(
      friendlyAuthError('requires-recent-login'),
      contains('sign in with Google again'),
    );
  });

  test('an unknown code gets the generic message', () {
    expect(
      friendlyAuthError('something-new'),
      'Something went wrong. Try again.',
    );
    expect(friendlyAuthError(''), 'Something went wrong. Try again.');
  });

  test('livePath builds users/<uid>/live', () {
    expect(livePath('abc123'), 'users/abc123/live');
  });

  test(
    'livePath refuses an empty uid or one with a character a key may not hold',
    () {
      for (final bad in ['', 'a/b', 'a.b', 'a#b', r'a$b', 'a[b', 'a]b']) {
        expect(() => livePath(bad), throwsArgumentError, reason: bad);
      }
    },
  );

  test('AuthUser has a password unless told otherwise', () {
    expect(const AuthUser('u', 'a@b.c').hasPassword, isTrue);
    expect(
      const AuthUser('u', 'a@b.c', hasPassword: false).hasPassword,
      isFalse,
    );
  });

  test(
    'FakeAuthService records calls and fails with the friendly message',
    () async {
      final auth = FakeAuthService();
      await auth.signIn('a@b.c', 'secret1', remember: true);
      expect(auth.calls, ['signIn:a@b.c:true']);
      auth.failWith = 'wrong-password';
      await expectLater(
        auth.signIn('a@b.c', 'x', remember: false),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message,
            'message',
            friendlyAuthError('wrong-password'),
          ),
        ),
      );
      await auth.signIn(
        'a@b.c',
        'secret1',
        remember: false,
      ); // the failure is used up
    },
  );
}

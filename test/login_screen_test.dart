import 'dart:async';
import 'dart:io';

import 'package:ccmahal_dashboard/auth/auth_service.dart';
import 'package:ccmahal_dashboard/auth/login_screen.dart';
import 'package:ccmahal_dashboard/auth/validators.dart';
import 'package:ccmahal_dashboard/sprites.dart';
import 'package:ccmahal_dashboard/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_auth.dart';

Widget app(FakeAuthService auth, {double width = 400, double height = 800}) {
  final sprites = SpriteSet.fromJson(
    File('assets/sprites.json').readAsStringSync(),
  );
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, height)),
      child: LoginScreen(
        auth: auth,
        sprites: sprites,
        now: DateTime(2026, 10, 26, 21, 41),
      ),
    ),
  );
}

/// The backdrop animates forever, so pump a fixed time instead of settling.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('validateEmail', () {
    expect(validateEmail(''), isNotNull);
    expect(validateEmail('   '), isNotNull);
    expect(validateEmail('no-at-sign'), isNotNull);
    expect(validateEmail('a@b'), isNotNull);
    expect(validateEmail('${'x' * 300}@example.com'), isNotNull);
    expect(validateEmail('me@example.com'), isNull);
    expect(validateEmail(' me@example.com '), isNull);
  });

  test('validatePassword needs 6 characters', () {
    expect(validatePassword(''), isNotNull);
    expect(validatePassword('12345'), isNotNull);
    expect(validatePassword('123456'), isNull);
  });

  test('validateConfirm needs the same password', () {
    expect(validateConfirm('secret1', 'secret2'), isNotNull);
    expect(validateConfirm('secret1', ''), isNotNull);
    expect(validateConfirm('secret1', 'secret1'), isNull);
  });

  testWidgets(
    'Sign in calls auth.signIn with remember on by default, and off when unticked',
    (tester) async {
      final auth = FakeAuthService();
      await tester.pumpWidget(app(auth));
      await settle(tester);
      await type(tester, 'email', 'me@example.com');
      await type(tester, 'password', 'secret1');
      await tapKey(tester, 'primary');
      expect(auth.calls, ['signIn:me@example.com:true']);
      await tapKey(tester, 'remember');
      await tapKey(tester, 'primary');
      expect(auth.calls.last, 'signIn:me@example.com:false');
    },
  );

  testWidgets('bad input never reaches auth and shows messages', (
    tester,
  ) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(app(auth));
    await settle(tester);
    await tapKey(tester, 'primary');
    expect(auth.calls, isEmpty);
    expect(find.textContaining('email'), findsWidgets);
  });

  testWidgets(
    'create-account mode shows the confirm field and rejects a mismatch without calling auth',
    (tester) async {
      final auth = FakeAuthService();
      await tester.pumpWidget(app(auth));
      await settle(tester);
      expect(find.byKey(const ValueKey('confirm')), findsNothing);
      await tapKey(tester, 'toggle-create');
      expect(find.byKey(const ValueKey('confirm')), findsOneWidget);
      await type(tester, 'email', 'new@example.com');
      await type(tester, 'password', 'secret1');
      await type(tester, 'confirm', 'secret2');
      await tapKey(tester, 'primary');
      expect(auth.calls, isEmpty);
      expect(find.textContaining('match'), findsOneWidget);
      await type(tester, 'confirm', 'secret1');
      await tapKey(tester, 'primary');
      expect(auth.calls, ['createAccount:new@example.com']);
    },
  );

  testWidgets('Sign in with Google calls auth.signInWithGoogle', (
    tester,
  ) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(app(auth));
    await settle(tester);
    await tapKey(tester, 'google');
    expect(auth.calls, ['google']);
  });

  testWidgets('Forgot password sends the reset email and says so', (
    tester,
  ) async {
    final auth = FakeAuthService();
    await tester.pumpWidget(app(auth));
    await settle(tester);
    await tapKey(tester, 'forgot');
    expect(find.byKey(const ValueKey('password')), findsNothing);
    await type(tester, 'email', 'me@example.com');
    await tapKey(tester, 'primary');
    expect(auth.calls, ['reset:me@example.com']);
    expect(find.byKey(const ValueKey('info')), findsOneWidget);
  });

  testWidgets('a failure message is shown and the buttons work again', (
    tester,
  ) async {
    final auth = FakeAuthService()..failWith = 'wrong-password';
    await tester.pumpWidget(app(auth));
    await settle(tester);
    await type(tester, 'email', 'me@example.com');
    await type(tester, 'password', 'secret1');
    await tapKey(tester, 'primary');
    expect(find.text(friendlyAuthError('wrong-password')), findsOneWidget);
    await tapKey(tester, 'primary');
    expect(auth.calls.length, 2);
  });

  testWidgets(
    'the buttons are disabled while a call runs, so a double tap sends one call',
    (tester) async {
      final auth = FakeAuthService()..hold = Completer<void>();
      await tester.pumpWidget(app(auth));
      await settle(tester);
      await type(tester, 'email', 'me@example.com');
      await type(tester, 'password', 'secret1');
      await tapKey(tester, 'primary');
      await tapKey(tester, 'primary');
      await tapKey(tester, 'google');
      expect(auth.calls, ['signIn:me@example.com:true']);
      auth.hold!.complete();
      await settle(tester);
    },
  );

  testWidgets('every button is at least 44 px high', (tester) async {
    await tester.pumpWidget(app(FakeAuthService()));
    await settle(tester);
    for (final k in ['primary', 'google', 'toggle-create', 'forgot']) {
      expect(
        tester.getSize(find.byKey(ValueKey(k))).height,
        greaterThanOrEqualTo(44),
        reason: k,
      );
    }
  });

  testWidgets(
    'the screen builds at 320 px width in every mode without overflow',
    (tester) async {
      await tester.pumpWidget(app(FakeAuthService(), width: 320, height: 640));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'toggle-create');
      expect(tester.takeException(), isNull);
      await tapKey(tester, 'back');
      await tapKey(tester, 'forgot');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the saved email is filled in', (tester) async {
    SharedPreferences.setMockInitialValues({'email': 'saved@example.com'});
    await tester.pumpWidget(app(FakeAuthService()));
    await settle(tester);
    expect(find.text('saved@example.com'), findsOneWidget);
  });

  testWidgets(
    'the card sits at the bottom of a phone-sized screen so the room shows above it',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(FakeAuthService()));
      await settle(tester);
      final card = tester.getRect(find.byKey(const ValueKey('login-card')));
      expect(card.bottom, greaterThan(800 * 0.85));
      expect(card.top, greaterThan(800 * 0.30));
    },
  );

  testWidgets(
    'the error text uses the glass error colour of the hour, readable at night',
    (tester) async {
      final auth = FakeAuthService()..failWith = 'wrong-password';
      await tester.pumpWidget(app(auth)); // the test clock is 21:41, night
      await settle(tester);
      await type(tester, 'email', 'me@example.com');
      await type(tester, 'password', 'secret1');
      await tapKey(tester, 'primary');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('error'))).style!.color,
        glassFor(0).error,
      );
    },
  );
}

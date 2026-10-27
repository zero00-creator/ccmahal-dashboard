import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../environment.dart';
import '../office/palette.dart';
import '../sprites.dart';
import '../theme/tokens.dart';
import '../ui/glass.dart';
import 'auth_service.dart';
import 'firebase_auth_service.dart' show emailKey;
import 'login_backdrop.dart';
import 'validators.dart';

enum _Mode { signIn, create, reset }

/// The title screen: the pixel office behind a glass card with sign in,
/// create account, Google and forgot password.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.auth,
    required this.sprites,
    this.now,
  });

  final AuthService auth;
  final SpriteSet sprites;

  /// The clock the room is lit by; the phone's own clock when null.
  final DateTime? now;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _remember = true;
  bool _busy = false;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final saved = p.getString(emailKey);
      if (mounted && saved != null && _email.text.isEmpty) {
        setState(() => _email.text = saved);
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _go(_Mode m) => setState(() {
    _mode = m;
    _emailError = _passwordError = _confirmError = _error = _info = null;
  });

  Future<void> _run(Future<void> Function() call, {String? success}) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await call();
      if (mounted && success != null) setState(() => _info = success);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = friendlyAuthError(''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    final email = _email.text.trim();
    setState(() {
      _emailError = validateEmail(email);
      _passwordError = _mode == _Mode.reset
          ? null
          : validatePassword(_password.text);
      _confirmError = _mode == _Mode.create
          ? validateConfirm(_password.text, _confirm.text)
          : null;
    });
    if (_emailError != null ||
        _passwordError != null ||
        _confirmError != null) {
      return;
    }
    switch (_mode) {
      case _Mode.signIn:
        _run(
          () => widget.auth.signIn(email, _password.text, remember: _remember),
        );
      case _Mode.create:
        _run(() => widget.auth.createAccount(email, _password.text));
      case _Mode.reset:
        _run(
          () => widget.auth.sendPasswordReset(email),
          success:
              'We sent an email to $email with a link to choose a new password.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final env = environmentAt(now);
    final style = glassFor(env.dayness);
    final primary = switch (_mode) {
      _Mode.signIn => 'Sign in',
      _Mode.create => 'Create account',
      _Mode.reset => 'Send reset email',
    };
    final big = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)),
    );
    final small = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size(minTap, minTap)),
      foregroundColor: WidgetStateProperty.all(style.inkMuted),
    );
    InputDecoration deco(String label, String? error) => InputDecoration(
      labelText: label,
      errorText: error,
      border: const OutlineInputBorder(),
      labelStyle: TextStyle(color: style.inkMuted),
      errorStyle: TextStyle(color: style.error, fontWeight: FontWeight.w600),
    );
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: LoginBackdrop(sprites: widget.sprites, now: now),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: const EdgeInsets.all(Space.x4),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: box.maxHeight - Space.x4 * 2,
                  ),
                  // The card sits at the bottom, so the room shows above it.
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: GlassPanel(
                        key: const ValueKey('login-card'),
                        style: style,
                        radius: Radii.sheet,
                        padding: const EdgeInsets.all(Space.x5),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'CCmahal',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w900,
                                fontSize: 38,
                                color: Palette.brass,
                                shadows: const [
                                  Shadow(
                                    color: Palette.brassDark,
                                    offset: Offset(3, 3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: Space.x1),
                            Text(
                              switch (_mode) {
                                _Mode.signIn =>
                                  'live office  ·  press sign in to start',
                                _Mode.create => 'new here? make your account',
                                _Mode.reset => 'we will email you a link',
                              },
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: style.inkMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: Space.x5),
                            TextField(
                              key: const ValueKey('email'),
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              style: TextStyle(color: style.ink),
                              decoration: deco('Email', _emailError),
                            ),
                            if (_mode != _Mode.reset) ...[
                              const SizedBox(height: Space.x3),
                              TextField(
                                key: const ValueKey('password'),
                                controller: _password,
                                obscureText: true,
                                autofillHints: [
                                  _mode == _Mode.create
                                      ? AutofillHints.newPassword
                                      : AutofillHints.password,
                                ],
                                style: TextStyle(color: style.ink),
                                onSubmitted: (_) => _busy ? null : _submit(),
                                decoration: deco('Password', _passwordError),
                              ),
                            ],
                            if (_mode == _Mode.create) ...[
                              const SizedBox(height: Space.x3),
                              TextField(
                                key: const ValueKey('confirm'),
                                controller: _confirm,
                                obscureText: true,
                                style: TextStyle(color: style.ink),
                                decoration: deco(
                                  'Confirm password',
                                  _confirmError,
                                ),
                              ),
                            ],
                            if (_mode == _Mode.signIn)
                              Row(
                                children: [
                                  Expanded(
                                    child: CheckboxListTile(
                                      key: const ValueKey('remember'),
                                      value: _remember,
                                      onChanged: _busy
                                          ? null
                                          : (v) => setState(
                                              () => _remember = v ?? true,
                                            ),
                                      title: Text(
                                        'Remember me',
                                        style: TextStyle(
                                          color: style.ink,
                                          fontSize: 14,
                                        ),
                                      ),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                    ),
                                  ),
                                  TextButton(
                                    key: const ValueKey('forgot'),
                                    style: small,
                                    onPressed: _busy
                                        ? null
                                        : () => _go(_Mode.reset),
                                    child: const Text('Forgot?'),
                                  ),
                                ],
                              )
                            else
                              const SizedBox(height: Space.x2),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: Space.x2,
                                ),
                                child: Text(
                                  _error!,
                                  key: const ValueKey('error'),
                                  style: TextStyle(
                                    color: style.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (_info != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: Space.x2,
                                ),
                                child: Text(
                                  _info!,
                                  key: const ValueKey('info'),
                                  style: TextStyle(color: style.ink),
                                ),
                              ),
                            FilledButton(
                              key: const ValueKey('primary'),
                              style: big,
                              onPressed: _busy ? null : _submit,
                              child: Text(_busy ? 'One moment…' : primary),
                            ),
                            if (_mode != _Mode.reset) ...[
                              const SizedBox(height: Space.x3),
                              OutlinedButton.icon(
                                key: const ValueKey('google'),
                                style: big,
                                onPressed: _busy
                                    ? null
                                    : () => _run(widget.auth.signInWithGoogle),
                                icon: const Icon(
                                  Icons.g_mobiledata_rounded,
                                  size: 28,
                                ),
                                label: const Text('Sign in with Google'),
                              ),
                            ],
                            const SizedBox(height: Space.x2),
                            if (_mode == _Mode.signIn)
                              TextButton(
                                key: const ValueKey('toggle-create'),
                                style: small,
                                onPressed: _busy
                                    ? null
                                    : () => _go(_Mode.create),
                                child: const Text('New here? Create account'),
                              )
                            else
                              TextButton(
                                key: const ValueKey('back'),
                                style: small,
                                onPressed: _busy
                                    ? null
                                    : () => _go(_Mode.signIn),
                                child: const Text('Back to sign in'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

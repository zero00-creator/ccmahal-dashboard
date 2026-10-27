import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../auth/validators.dart';
import '../theme/tokens.dart';
import '../update/update_controller.dart';
import '../update/update_ui.dart';
import 'glass.dart';

/// The Settings tab: who is signed in, sign out, and for a Google account the
/// password the plugin signs in with.
class SettingsTab extends StatefulWidget {
  const SettingsTab({
    super.key,
    required this.user,
    required this.style,
    required this.onSignOut,
    required this.onSetPluginPassword,
    this.appAsk = false,
    this.onAppAskChanged,
    this.appCmd = false,
    this.onAppCmdChanged,
    this.embedded = false,
    this.updates,
  });

  /// The in-app updater (Android only); null or unsupported hides its section.
  final UpdateController? updates;

  /// Inside a collapsible panel: no title and the list takes only the height
  /// it needs.
  final bool embedded;

  /// The "Send instructions from here" switch: this app may type into the running session.
  final bool appCmd;
  final ValueChanged<bool>? onAppCmdChanged;

  final AuthUser user;
  final GlassStyle style;
  final VoidCallback onSignOut;
  final Future<void> Function(String password) onSetPluginPassword;

  /// The "Ask me here" switch: dangerous permission questions from the PC come to this app.
  final bool appAsk;
  final ValueChanged<bool>? onAppAskChanged;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _done = false;

  Future<void> _askPassword() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _PasswordDialog(
        style: widget.style,
        onSave: widget.onSetPluginPassword,
      ),
    );
    if (saved == true && mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final embedded = widget.embedded;
    final u = widget.user;
    final buttonStyle = TextButton.styleFrom(
      minimumSize: const Size.fromHeight(minTap),
      foregroundColor: style.ink,
      alignment: Alignment.centerLeft,
    );
    return ListView(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.all(embedded ? Space.x3 : Space.x4),
      children: [
        if (!embedded) ...[
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: style.ink,
            ),
          ),
          const SizedBox(height: Space.x4),
        ],
        GlassPanel(
          style: style,
          padding: const EdgeInsets.all(Space.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Signed in as',
                style: TextStyle(fontSize: 12, color: style.inkMuted),
              ),
              const SizedBox(height: Space.x1),
              Text(
                u.email,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: style.ink,
                ),
              ),
              if (!u.hasPassword) ...[
                const SizedBox(height: Space.x3),
                Text(
                  'You signed in with Google. The plugin on your computer signs in with an email and a password, so set one for it.',
                  style: TextStyle(fontSize: 13, color: style.inkMuted),
                ),
                const SizedBox(height: Space.x2),
                FilledButton(
                  key: const ValueKey('set-plugin-password'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _askPassword,
                  child: const Text('Set a password for the plugin'),
                ),
              ],
              if (_done) ...[
                const SizedBox(height: Space.x2),
                Text(
                  'Password set. Use this email and that password in the mod settings.',
                  key: const ValueKey('password-done'),
                  style: TextStyle(fontSize: 13, color: style.ink),
                ),
              ],
              const SizedBox(height: Space.x2),
              TextButton.icon(
                key: const ValueKey('settings-sign-out'),
                style: buttonStyle,
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.x4),
        GlassPanel(
          style: style,
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x4,
            vertical: Space.x2,
          ),
          child: SwitchListTile(
            key: const ValueKey('app-ask'),
            contentPadding: EdgeInsets.zero,
            value: widget.appAsk,
            onChanged: widget.onAppAskChanged,
            title: Text(
              'Ask me here',
              style: TextStyle(fontWeight: FontWeight.w700, color: style.ink),
            ),
            subtitle: Text(
              'Dangerous permission questions from your computer pop up in this app. If nobody answers in 5 minutes the terminal asks.',
              style: TextStyle(fontSize: 13, color: style.inkMuted),
            ),
          ),
        ),
        const SizedBox(height: Space.x4),
        GlassPanel(
          style: style,
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x4,
            vertical: Space.x2,
          ),
          child: SwitchListTile(
            key: const ValueKey('app-cmd'),
            contentPadding: EdgeInsets.zero,
            value: widget.appCmd,
            onChanged: widget.onAppCmdChanged,
            title: Text(
              'Send instructions from here',
              style: TextStyle(fontWeight: FontWeight.w700, color: style.ink),
            ),
            subtitle: Text(
              'Lets this app type into your running Claude session. Anyone with this login can do the same.',
              style: TextStyle(fontSize: 13, color: style.inkMuted),
            ),
          ),
        ),
        if (widget.updates?.supported == true) ...[
          const SizedBox(height: Space.x4),
          UpdateSection(controller: widget.updates!, style: style),
        ],
        const SizedBox(height: Space.x4),
        GlassPanel(
          style: style,
          padding: const EdgeInsets.all(Space.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set up the mod',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: style.ink,
                ),
              ),
              const SizedBox(height: Space.x2),
              Text(
                'In the my-mod settings, set dashboard to on and enter this email and your password. The database address and web key are already filled in. Then start a new session.',
                style: TextStyle(fontSize: 13, color: style.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.style, required this.onSave});

  final GlassStyle style;
  final Future<void> Function(String password) onSave;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _c = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = validatePassword(_c.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(_c.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = friendlyAuthError(''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Password for the plugin'),
      content: TextField(
        key: const ValueKey('plugin-password'),
        controller: _c,
        obscureText: true,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'New password',
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _busy ? null : _save(),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('plugin-password-save'),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

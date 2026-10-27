/// Where a person's sessions live in the database: `users/<uid>/live`.
/// The uid comes from the sign-in, and a key may not hold `. # $ [ ] /`.
String _checked(String uid) {
  if (uid.isEmpty || RegExp(r'[./#$\[\]]').hasMatch(uid)) {
    throw ArgumentError.value(uid, 'uid', 'not a valid database key');
  }
  return uid;
}

String livePath(String uid) => 'users/${_checked(uid)}/live';

/// The permission questions the plugin raised: `users/<uid>/asks/<session>/<ask>`.
String asksPath(String uid) => 'users/${_checked(uid)}/asks';

/// The "Ask me here" switch the plugin reads.
String appAskPath(String uid) => 'users/${_checked(uid)}/prefs/appAsk';

/// The instructions typed in the app: `users/<uid>/cmd/<session>/<cmd>`.
String cmdsPath(String uid) => 'users/${_checked(uid)}/cmd';

/// One session's instructions; new ones are pushed here with a fresh key.
String cmdPath(String uid, String sessionKey) =>
    '${cmdsPath(uid)}/${_checked(sessionKey)}';

/// The "Send instructions from here" switch the plugin reads.
String appCmdPath(String uid) => 'users/${_checked(uid)}/prefs/appCmd';

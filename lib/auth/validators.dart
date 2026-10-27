/// Each validator returns a plain message for the person, or null when the
/// value is fine.
String? validateEmail(String value) {
  final v = value.trim();
  if (v.isEmpty) return 'Enter your email.';
  if (v.length > 254) return 'That email is too long.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(v))
    return 'That email address does not look right.';
  return null;
}

String? validatePassword(String value) {
  if (value.isEmpty) return 'Enter a password.';
  if (value.length < 6) return 'Use at least 6 characters.';
  return null;
}

String? validateConfirm(String password, String confirm) {
  if (confirm.isEmpty || confirm != password)
    return 'The two passwords do not match.';
  return null;
}

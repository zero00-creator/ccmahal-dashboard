import 'dart:convert';

/// The one place the repository is named.
const String updateRepoSlug = 'zero00-creator/ccmahal-dashboard';

/// The public "latest release" endpoint (no token needed).
Uri latestReleaseUri() =>
    Uri.https('api.github.com', '/repos/$updateRepoSlug/releases/latest');

/// A newer release that can be installed.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.url,
    this.size,
    this.sha256,
  });

  /// Without the leading v, for example `1.0.1`.
  final String version;

  /// Release notes shortened to about 300 characters.
  final String notes;
  final Uri url;
  final int? size;

  /// Lower-case hex of the expected SHA-256, when GitHub gave one.
  final String? sha256;

  @override
  bool operator ==(Object other) =>
      other is UpdateInfo &&
      other.version == version &&
      other.notes == notes &&
      other.url == url &&
      other.size == size &&
      other.sha256 == sha256;

  @override
  int get hashCode => Object.hash(version, notes, url, size, sha256);
}

/// What was read from a release JSON (before comparing versions).
class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.name,
    required this.notes,
    required this.url,
    this.size,
    this.sha256,
  });

  final String tag;
  final String name;
  final String notes;
  final Uri url;
  final int? size;
  final String? sha256;
}

const int maxNotesLength = 300;

String shortenNotes(String s) {
  final t = s.trim();
  if (t.length <= maxNotesLength) return t;
  return '${t.substring(0, maxNotesLength).trimRight()}…';
}

/// Only https downloads from GitHub itself are accepted.
bool isTrustedDownloadUri(Uri u) =>
    u.scheme == 'https' &&
    (u.host == 'github.com' || u.host == 'objects.githubusercontent.com');

/// `sha256:ABC...` to lower-case hex, or null when it is not a sha256 digest.
String? parseDigest(Object? raw) {
  if (raw is! String) return null;
  final m = RegExp(r'^sha256:([0-9a-fA-F]{64})$').firstMatch(raw.trim());
  return m?.group(1)!.toLowerCase();
}

/// True when the hex digest [actual] equals [expected] (case-insensitive).
bool digestMatches(String expected, String actual) =>
    expected.toLowerCase() == actual.toLowerCase();

/// Reads a release JSON defensively. Null when anything needed is missing:
/// no tag, no .apk asset, or a download URL that is not trusted.
ReleaseInfo? parseRelease(Object? json) {
  try {
    final Object? data = json is String ? jsonDecode(json) : json;
    if (data is! Map) return null;
    final tag = data['tag_name'];
    if (tag is! String || tag.trim().isEmpty) return null;
    final assets = data['assets'];
    if (assets is! List) return null;
    for (final a in assets) {
      if (a is! Map) continue;
      final name = a['name'];
      final url = a['browser_download_url'];
      if (name is! String || !name.toLowerCase().endsWith('.apk')) continue;
      if (url is! String) continue;
      final uri = Uri.tryParse(url);
      if (uri == null || !isTrustedDownloadUri(uri)) continue;
      final size = a['size'];
      final title = data['name'];
      final body = data['body'];
      return ReleaseInfo(
        tag: tag.trim(),
        name: title is String ? title : '',
        notes: body is String ? shortenNotes(body) : '',
        url: uri,
        size: size is int && size > 0 ? size : null,
        sha256: parseDigest(a['digest']),
      );
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// `v1.0.10+3` to [1, 0, 10]; null when it is not three numbers.
List<int>? parseVersion(String s) {
  var v = s.trim();
  if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
  final plus = v.indexOf('+');
  if (plus >= 0) v = v.substring(0, plus);
  final parts = v.split('.');
  if (parts.length != 3) return null;
  final out = <int>[];
  for (final p in parts) {
    if (!RegExp(r'^\d+$').hasMatch(p)) return null;
    out.add(int.parse(p));
  }
  return out;
}

/// True when [latest] is a higher version than [current]; false for equal,
/// lower or malformed input.
bool isNewerVersion(String current, String latest) {
  final a = parseVersion(current);
  final b = parseVersion(latest);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (b[i] != a[i]) return b[i] > a[i];
  }
  return false;
}

/// The update to offer, or null when the app is current or the data is bad.
UpdateInfo? decideUpdate(String currentVersion, ReleaseInfo? release) {
  if (release == null) return null;
  if (!isNewerVersion(currentVersion, release.tag)) return null;
  final v = parseVersion(release.tag)!;
  return UpdateInfo(
    version: v.join('.'),
    notes: release.notes,
    url: release.url,
    size: release.size,
    sha256: release.sha256,
  );
}

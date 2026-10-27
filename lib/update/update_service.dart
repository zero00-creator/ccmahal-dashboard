import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'update_logic.dart';

/// Thrown when a download cannot be trusted or finished.
class UpdateFailure implements Exception {
  const UpdateFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What the controller needs from the outside world; tests use a fake.
abstract class UpdateService {
  /// The newer release, or null when the app is current. Throws on a network or
  /// server failure.
  Future<UpdateInfo?> checkLatest();

  /// The installed version, for example `1.0.0`.
  Future<String> currentVersion();

  /// Downloads the APK into the cache directory, reporting 0..1.
  Future<File> download(UpdateInfo info, void Function(double) onProgress);

  /// Opens the file with the system installer.
  Future<void> install(File file);
}

/// True where the updater exists: the Android app only.
bool get updatesSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class GithubUpdateService implements UpdateService {
  GithubUpdateService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<String> currentVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  @override
  Future<UpdateInfo?> checkLatest() async {
    final current = await currentVersion();
    final res = await _client
        .get(
          latestReleaseUri(),
          headers: const {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw UpdateFailure('GitHub answered ${res.statusCode}');
    }
    return decideUpdate(
      current,
      parseRelease(jsonDecode(utf8.decode(res.bodyBytes))),
    );
  }

  @override
  Future<File> download(
    UpdateInfo info,
    void Function(double) onProgress,
  ) async {
    if (!isTrustedDownloadUri(info.url)) {
      throw const UpdateFailure('The download address is not trusted.');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ccmahal-${info.version}.apk');
    if (await file.exists()) await file.delete();
    final res = await _client.send(http.Request('GET', info.url));
    if (res.statusCode != 200) {
      throw UpdateFailure('Download failed (${res.statusCode}).');
    }
    final total = res.contentLength ?? info.size ?? 0;
    var got = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress((got / total).clamp(0.0, 1.0));
      }
    } finally {
      await sink.close();
    }
    final want = info.sha256;
    if (want != null) {
      final actual = (await crypto.sha256.bind(file.openRead()).first)
          .toString();
      if (!digestMatches(want, actual)) {
        await file.delete();
        throw const UpdateFailure(
          'The downloaded file did not match its checksum, so it was not kept.',
        );
      }
    }
    onProgress(1);
    return file;
  }

  @override
  Future<void> install(File file) async {
    final r = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (r.type != ResultType.done) {
      throw UpdateFailure(r.message);
    }
  }
}

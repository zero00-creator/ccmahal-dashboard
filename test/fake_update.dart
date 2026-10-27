import 'dart:async';
import 'dart:io';

import 'package:ccmahal_dashboard/update/update_logic.dart';
import 'package:ccmahal_dashboard/update/update_service.dart';

final fakeInfo = UpdateInfo(
  version: '1.0.1',
  notes: 'Fixes things',
  url: Uri.parse('https://github.com/a/b/app.apk'),
);

class FakeUpdateService implements UpdateService {
  UpdateInfo? latest = fakeInfo;
  Object? checkError;
  Object? downloadError;
  int checks = 0;
  int installs = 0;
  String version = '1.0.0';

  /// When set, download waits for it so a test can look at the progress.
  Completer<void>? gate;
  void Function(double)? progress;

  @override
  Future<String> currentVersion() async => version;

  @override
  Future<UpdateInfo?> checkLatest() async {
    checks++;
    if (checkError != null) throw checkError!;
    return latest;
  }

  @override
  Future<File> download(
    UpdateInfo info,
    void Function(double) onProgress,
  ) async {
    progress = onProgress;
    onProgress(0.4);
    if (gate != null) await gate!.future;
    if (downloadError != null) throw downloadError!;
    return File('fake.apk');
  }

  @override
  Future<void> install(File file) async => installs++;
}

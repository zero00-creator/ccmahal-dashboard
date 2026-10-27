import 'dart:async';

import 'package:ccmahal_dashboard/update/update_controller.dart';
import 'package:ccmahal_dashboard/update/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_update.dart';

void main() {
  late FakeUpdateService svc;
  late DateTime now;
  late UpdateController c;

  setUp(() {
    svc = FakeUpdateService();
    now = DateTime(2026, 10, 27, 12);
    c = UpdateController(service: svc, clock: () => now);
  });

  test('starts idle', () {
    expect(c.state, UpdateState.idle);
    expect(c.bannerVisible, isFalse);
  });

  test('checking, then available', () async {
    final seen = <UpdateState>[];
    c.addListener(() => seen.add(c.state));
    await c.checkManual();
    expect(seen, [UpdateState.checking, UpdateState.available]);
    expect(c.info!.version, '1.0.1');
    expect(c.currentVersion, '1.0.0');
    expect(c.bannerVisible, isTrue);
  });

  test('up to date', () async {
    svc.latest = null;
    await c.checkManual();
    expect(c.state, UpdateState.upToDate);
    expect(c.info, isNull);
    expect(c.bannerVisible, isFalse);
  });

  test('a failed manual check says so', () async {
    svc.checkError = Exception('offline');
    await c.checkManual();
    expect(c.state, UpdateState.failed);
    expect(c.message, 'Could not check for updates');
  });

  test('a failed automatic check is silent', () async {
    svc.checkError = Exception('offline');
    await c.checkAuto();
    expect(c.state, UpdateState.idle);
    expect(c.message, isNull);
  });

  test('automatic checks run at most every 6 hours', () async {
    await c.checkAuto();
    await c.checkAuto();
    expect(svc.checks, 1);
    now = now.add(const Duration(hours: 5, minutes: 59));
    await c.checkAuto();
    expect(svc.checks, 1);
    now = now.add(const Duration(minutes: 2));
    await c.checkAuto();
    expect(svc.checks, 2);
  });

  test('a failed automatic check does not start the 6 hour wait', () async {
    svc.checkError = Exception('offline');
    await c.checkAuto();
    svc.checkError = null;
    await c.checkAuto();
    expect(svc.checks, 2);
    expect(c.state, UpdateState.available);
  });

  test('a manual check ignores the wait', () async {
    await c.checkAuto();
    await c.checkManual();
    expect(svc.checks, 2);
  });

  test('downloading reports progress, then downloaded', () async {
    await c.checkManual();
    svc.gate = Completer<void>();
    final done = c.startDownload();
    await Future<void>.delayed(Duration.zero);
    expect(c.state, UpdateState.downloading);
    expect(c.progress, 0.4);
    svc.gate!.complete();
    await done;
    expect(c.state, UpdateState.downloaded);
    expect(c.progress, 1);
  });

  test('install is only offered after the download', () async {
    await c.checkManual();
    await c.install();
    expect(svc.installs, 0);
    await c.startDownload();
    await c.install();
    expect(svc.installs, 1);
  });

  test('a failed download keeps the update so it can be retried', () async {
    await c.checkManual();
    svc.downloadError = const UpdateFailure('checksum');
    await c.startDownload();
    expect(c.state, UpdateState.failed);
    expect(c.message, 'checksum');
    expect(c.info, isNotNull);
    svc.downloadError = null;
    await c.startDownload();
    expect(c.state, UpdateState.downloaded);
  });

  test('dismissing hides the banner but keeps the update', () async {
    await c.checkManual();
    c.dismiss();
    expect(c.dismissed, isTrue);
    expect(c.bannerVisible, isFalse);
    expect(c.info, isNotNull);
  });

  test('unsupported platforms do nothing', () async {
    final off = UpdateController(service: svc, supported: false);
    await off.checkAuto();
    await off.checkManual();
    await off.startDownload();
    expect(svc.checks, 0);
    expect(off.state, UpdateState.idle);
    expect(off.bannerVisible, isFalse);
  });
}

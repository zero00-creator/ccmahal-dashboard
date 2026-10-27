import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_logic.dart';
import 'update_service.dart';

enum UpdateState {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  downloaded,
  failed,
}

/// Remembers when the last automatic check ran.
abstract class LastCheckStore {
  Future<DateTime?> read();
  Future<void> write(DateTime t);
}

class MemoryLastCheckStore implements LastCheckStore {
  DateTime? _t;
  @override
  Future<DateTime?> read() async => _t;
  @override
  Future<void> write(DateTime t) async => _t = t;
}

class PrefsLastCheckStore implements LastCheckStore {
  static const key = 'update_last_check_ms';

  @override
  Future<DateTime?> read() async {
    final ms = (await SharedPreferences.getInstance()).getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> write(DateTime t) async {
    await (await SharedPreferences.getInstance()).setInt(
      key,
      t.millisecondsSinceEpoch,
    );
  }
}

const Duration updateCheckEvery = Duration(hours: 6);
const String couldNotCheck = 'Could not check for updates';

/// The state of the updater. The Settings section and the banner read it.
class UpdateController extends ChangeNotifier {
  UpdateController({
    required this.service,
    this.supported = true,
    LastCheckStore? store,
    DateTime Function()? clock,
  }) : _store = store ?? MemoryLastCheckStore(),
       _clock = clock ?? DateTime.now;

  final UpdateService service;

  /// False on web and other platforms: nothing is shown and nothing runs.
  final bool supported;
  final LastCheckStore _store;
  final DateTime Function() _clock;

  UpdateState _state = UpdateState.idle;
  UpdateInfo? _info;
  double _progress = 0;
  String? _message;
  String _current = '';
  bool _dismissed = false;
  File? _file;
  bool _disposed = false;

  UpdateState get state => _state;
  UpdateInfo? get info => _info;
  double get progress => _progress;

  /// A short problem text when [state] is failed.
  String? get message => _message;
  String get currentVersion => _current;
  bool get dismissed => _dismissed;

  /// The banner shows while a newer version is known and not dismissed.
  bool get bannerVisible => supported && _info != null && !_dismissed;

  bool get _busy =>
      _state == UpdateState.checking || _state == UpdateState.downloading;

  void _set(UpdateState s, {String? message}) {
    _state = s;
    _message = message;
    if (!_disposed) notifyListeners();
  }

  Future<void> _loadCurrent() async {
    if (_current.isNotEmpty) return;
    try {
      _current = await service.currentVersion();
    } catch (_) {}
  }

  /// The check on opening the app: at most every 6 hours, silent on failure.
  Future<void> checkAuto() async {
    if (!supported || _busy) return;
    try {
      final last = await _store.read();
      if (last != null && _clock().difference(last) < updateCheckEvery) return;
    } catch (_) {}
    await _check(manual: false);
  }

  /// The button: always checks, and says so when it cannot.
  Future<void> checkManual() async {
    if (!supported || _busy) return;
    await _check(manual: true);
  }

  Future<void> _check({required bool manual}) async {
    final before = _state;
    _set(UpdateState.checking);
    await _loadCurrent();
    try {
      final found = await service.checkLatest();
      try {
        await _store.write(_clock());
      } catch (_) {}
      if (found == null) {
        _info = null;
        _set(UpdateState.upToDate);
      } else {
        if (_info?.version != found.version) _dismissed = false;
        _info = found;
        _set(UpdateState.available);
      }
    } catch (_) {
      if (manual) {
        _set(UpdateState.failed, message: couldNotCheck);
      } else {
        _set(before == UpdateState.checking ? UpdateState.idle : before);
      }
    }
  }

  Future<void> startDownload() async {
    final info = _info;
    if (!supported || info == null || _busy) return;
    _progress = 0;
    _set(UpdateState.downloading);
    try {
      _file = await service.download(info, (p) {
        _progress = p;
        if (!_disposed) notifyListeners();
      });
      _progress = 1;
      _set(UpdateState.downloaded);
    } catch (e) {
      _set(
        UpdateState.failed,
        message: e is UpdateFailure
            ? e.message
            : 'The download failed. Check your connection and try again.',
      );
    }
  }

  Future<void> install() async {
    final f = _file;
    if (!supported || f == null || _state != UpdateState.downloaded) return;
    try {
      await service.install(f);
    } catch (_) {
      _set(UpdateState.failed, message: 'Could not open the installer.');
    }
  }

  /// Hides the banner for this session.
  void dismiss() {
    _dismissed = true;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

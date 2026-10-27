import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'asks.dart';
import 'auth/auth_service.dart';
import 'cmds.dart';
import 'firebase_options.dart';
import 'models.dart';
import 'paths.dart';
import 'sprites.dart';
import 'ui/offline_notice.dart';
import 'ui/live_view.dart';

/// The thin Firebase wrapper around [LiveView]: it owns the streams, the
/// server-time offset and the phone's clock, and passes plain data down.
/// It reads only the signed-in person's own sessions (`users/<uid>/live`).
class LivePage extends StatefulWidget {
  const LivePage({super.key, required this.auth, required this.user});

  final AuthService auth;
  final AuthUser user;

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  late final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: databaseUrl,
  );
  // One subscription for the life of the page: rebuilding must not resubscribe and refetch the sessions.
  late Stream<DatabaseEvent> _live = _db.ref(livePath(widget.user.uid)).onValue;
  late final Stream<DatabaseEvent> _asks = _db
      .ref(asksPath(widget.user.uid))
      .onValue;
  late final Stream<DatabaseEvent> _appAsk = _db
      .ref(appAskPath(widget.user.uid))
      .onValue;
  late final Stream<DatabaseEvent> _cmds = _db
      .ref(cmdsPath(widget.user.uid))
      .onValue;
  late final Stream<DatabaseEvent> _appCmd = _db
      .ref(appCmdPath(widget.user.uid))
      .onValue;
  bool _slow = false; // no data after the wait: show the offline notice
  Timer? _wait;
  int _offsetMs = 0; // server time minus this device's time
  Timer? _tick;
  StreamSubscription<DatabaseEvent>? _offsetSub;
  SpriteSet? _sprites;

  @override
  void initState() {
    super.initState();
    _startWait();
    SpriteSet.load().then((s) {
      if (mounted) setState(() => _sprites = s);
    });
    _offsetSub = _db.ref('.info/serverTimeOffset').onValue.listen((e) {
      final v = e.snapshot.value;
      if (v is num) _offsetMs = v.round();
    });
    // Redraw every 30 s so the light follows the clock and "offline" appears.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _startWait() {
    _wait?.cancel();
    _wait = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  void _retry() => setState(() {
    _slow = false;
    _live = _db.ref(livePath(widget.user.uid)).onValue;
    _startWait();
  });

  @override
  void dispose() {
    _wait?.cancel();
    _tick?.cancel();
    _offsetSub?.cancel();
    super.dispose();
  }

  /// The answer is the one field the rules let the app write, and only while the ask is pending.
  Future<void> _answer(AskInfo ask, bool allow) =>
      _db.ref(ask.answerPath(widget.user.uid)).set(allow ? 'allow' : 'deny');

  Future<void> _setAppAsk(bool on) =>
      _db.ref(appAskPath(widget.user.uid)).set(on);

  Future<void> _setAppCmd(bool on) =>
      _db.ref(appCmdPath(widget.user.uid)).set(on);

  /// One create under a fresh push key, always `queued`; the plugin does the rest.
  Future<void> _sendCmd(
    String sessionKey,
    String target,
    String text, {
    String? quick,
  }) async {
    final entry = buildCmdEntry(
      target: target,
      text: text,
      quick: quick,
      queued: 0, // the view already refused a ninth
    );
    if (entry == null) throw ArgumentError('instruction refused');
    await _db.ref(cmdPath(widget.user.uid, sessionKey)).push().set(entry);
  }

  int get _serverNow => DateTime.now().millisecondsSinceEpoch + _offsetMs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _live,
      builder: (context, snap) {
        if (snap.hasError || (!snap.hasData && _slow)) {
          return OfflineNotice(onRetry: _retry, onSignOut: widget.auth.signOut);
        }
        if (!snap.hasData || _sprites == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return StreamBuilder<DatabaseEvent>(
          stream: _asks,
          builder: (context, asks) => StreamBuilder<DatabaseEvent>(
            stream: _appAsk,
            builder: (context, pref) => StreamBuilder<DatabaseEvent>(
              stream: _cmds,
              builder: (context, cmds) => StreamBuilder<DatabaseEvent>(
                stream: _appCmd,
                builder: (context, cmdPref) => _view(
                  snap.data!,
                  parseAsks(asks.data?.snapshot.value),
                  pref.data?.snapshot.value == true,
                  parseCmds(cmds.data?.snapshot.value),
                  cmdPref.data?.snapshot.value == true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _view(
    DatabaseEvent snap,
    List<AskInfo> asks,
    bool appAsk,
    List<CmdInfo> cmds,
    bool appCmd,
  ) {
    return LiveView(
      sessions: parseSessions(snap.snapshot.value),
      serverNow: _serverNow,
      sprites: _sprites!,
      now: DateTime.now(),
      onSignOut: widget.auth.signOut,
      user: widget.user,
      onSetPluginPassword: widget.auth.setPluginPassword,
      asks: asks,
      onAnswer: _answer,
      appAsk: appAsk,
      onAppAskChanged: _setAppAsk,
      cmds: cmds,
      appCmd: appCmd,
      onSendCmd: _sendCmd,
      onAppCmdChanged: _setAppCmd,
    );
  }
}

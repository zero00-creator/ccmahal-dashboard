/// At most this many commands may wait in one session; the app refuses a ninth.
const maxQueued = 8;
const maxCmdText = 500;
const maxCmdTarget = 40;

/// The plugin fails a command it picks up after this long (hooks/cmd.ts).
const cmdStaleAfterMs = 10 * 60 * 1000;

/// Quick actions are canned sentences, not controls: nothing here kills a process.
const quickTexts = <String, String>{
  'pause': 'please pause after the current step',
  'continue': 'please continue',
  'stop': 'please stop after the current step and wait for me',
  'status': 'please report your status in one short message',
};

/// One instruction typed in the app (see hooks/cmd.ts in the my-mod plugin).
/// The app creates it as `queued`; the plugin marks it delivered or failed.
class CmdInfo {
  CmdInfo({
    required this.sessionKey,
    required this.id,
    required this.target,
    required this.text,
    required this.createdAt,
    required this.status,
    this.quick,
    this.note,
  });

  final String sessionKey;
  final String id;
  final String target; // main | all | an agent type
  final String text;
  final int createdAt;
  final String status; // queued | delivered | failed
  final String? quick;
  final String? note;

  bool get isQueued => status == 'queued';

  /// A queued command older than the plugin's limit will be failed as "too old":
  /// show that now, even if the plugin has not written it (switch off, PC asleep).
  CmdInfo withStaleCheck(int serverNow) =>
      isQueued && serverNow - createdAt > cmdStaleAfterMs
      ? CmdInfo(
          sessionKey: sessionKey,
          id: id,
          target: target,
          text: text,
          createdAt: createdAt,
          status: 'failed',
          quick: quick,
          note: 'too old',
        )
      : this;
}

const _states = {'queued', 'delivered', 'failed'};

/// Reads `users/<uid>/cmd` defensively, newest first: anything malformed is skipped.
List<CmdInfo> parseCmds(Object? value) {
  final out = <CmdInfo>[];
  if (value is! Map) return out;
  value.forEach((sk, byCmd) {
    if (byCmd is! Map) return;
    byCmd.forEach((id, raw) {
      if (raw is! Map) return;
      final target = raw['target'];
      final text = raw['text'];
      final status = raw['status'];
      final at = raw['createdAt'];
      if (target is! String ||
          text is! String ||
          status is! String ||
          !_states.contains(status) ||
          at is! num) {
        return;
      }
      final quick = raw['quick'];
      final note = raw['note'];
      out.add(
        CmdInfo(
          sessionKey: '$sk',
          id: '$id',
          target: target,
          text: text,
          createdAt: at.round(),
          status: status,
          quick: quick is String && quickTexts.containsKey(quick)
              ? quick
              : null,
          note: note is String && note.isNotEmpty ? note : null,
        ),
      );
    });
  });
  out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return out;
}

/// The entry to write under `users/<uid>/cmd/<session>/<pushKey>`, or null when
/// it must be refused (text not 1..500 after trimming, target not 1..40, a
/// ninth queued command, an unknown quick action). A quick action replaces the text.
Map<String, Object?>? buildCmdEntry({
  required String target,
  required String text,
  String? quick,
  required int queued,
}) {
  if (queued >= maxQueued) return null;
  if (target.isEmpty || target.length > maxCmdTarget) return null;
  var body = text.trim();
  if (quick != null) {
    final canned = quickTexts[quick];
    if (canned == null) return null;
    body = canned;
  }
  if (body.isEmpty || body.length > maxCmdText) return null;
  return {
    'v': 1,
    'target': target,
    'text': body,
    'createdAt': {'.sv': 'timestamp'},
    'status': 'queued',
    'quick': ?quick,
  };
}

/// Why sending is off right now, or null when it is allowed.
String? cmdBlockReason({
  required bool appCmd,
  required bool offline,
  required int queued,
}) {
  if (!appCmd) return 'Turn on instructions in Settings';
  if (offline) return 'This session is offline';
  if (queued >= maxQueued) {
    return '$maxQueued instructions are already waiting. Wait for them to be delivered.';
  }
  return null;
}

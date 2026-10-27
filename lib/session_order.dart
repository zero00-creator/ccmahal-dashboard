import 'models.dart';

/// An offline session is dropped from the app after this long without a heartbeat.
const offlineDropMs = 3600000;

/// The sessions to show, oldest first. Ended sessions are never shown, and an
/// offline one disappears an hour after its last heartbeat. The order follows
/// when a session first appeared, never how recently it was active, so rows
/// do not jump; a session with no first-seen time goes last, by key.
List<SessionInfo> visibleSessions(List<SessionInfo> sessions, int serverNow) {
  final out = [
    for (final s in sessions)
      if (s.liveStatus(serverNow) != 'ended' &&
          !(s.isOffline(serverNow) && serverNow - s.seenAt > offlineDropMs))
        s,
  ];
  out.sort((a, b) {
    final ak = a.firstSeen > 0, bk = b.firstSeen > 0;
    if (ak != bk) return ak ? -1 : 1;
    final c = a.firstSeen.compareTo(b.firstSeen);
    return c != 0 ? c : a.key.compareTo(b.key);
  });
  return out;
}

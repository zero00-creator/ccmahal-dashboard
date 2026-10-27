import '../models.dart';

enum CrabMood { working, idle, done, failed, waiting }

/// How a subagent looks: an offline session shows everyone idle; otherwise
/// the agent's own status decides (anything unknown reads as done).
CrabMood moodOf({required String agentStatus, required bool sessionOffline}) {
  if (sessionOffline) return CrabMood.idle;
  switch (agentStatus) {
    case 'running':
      return CrabMood.working;
    case 'failed':
      return CrabMood.failed;
    default:
      return CrabMood.done;
  }
}

/// How the session's own agent looks: waiting when a question is pending.
CrabMood mainMoodOf(SessionInfo s, int serverNow) {
  final live = s.liveStatus(serverNow);
  if (live == 'offline' || live == 'ended') return CrabMood.idle;
  if (s.pending > 0) return CrabMood.waiting;
  return live == 'running' ? CrabMood.working : CrabMood.idle;
}

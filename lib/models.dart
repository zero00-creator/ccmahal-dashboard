/// What one session pushes (see hooks/dashboard.ts in the my-mod plugin),
/// read defensively: a missing or oddly typed field reads as empty.
class AgentInfo {
  AgentInfo({
    required this.id,
    required this.type,
    required this.task,
    required this.model,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.ctxPct,
    required this.costUsd,
    this.stepDone,
    this.stepTotal,
    required this.stepNote,
  });

  final String id;
  final String type;
  final String task;
  final String model;
  final String status; // running | done | failed
  final int startedAt;
  final int? endedAt;
  final int? ctxPct;
  final double costUsd;
  final int? stepDone;
  final int? stepTotal;
  final String stepNote;

  bool get isRunning => status == 'running';

  factory AgentInfo.fromMap(Map<dynamic, dynamic> m) => AgentInfo(
    id: _s(m['id']),
    type: _s(m['type']),
    task: _s(m['task']),
    model: _s(m['model']),
    status: _s(m['status'], 'running'),
    startedAt: _i(m['startedAt']) ?? 0,
    endedAt: _i(m['endedAt']),
    ctxPct: _i(m['ctxPct']),
    costUsd: _d(m['costUsd']) ?? 0,
    stepDone: _i(m['stepDone']),
    stepTotal: _i(m['stepTotal']),
    stepNote: _s(m['stepNote']),
  );
}

class SessionInfo {
  SessionInfo({
    required this.key,
    required this.project,
    required this.status,
    required this.model,
    required this.mode,
    this.ctxPct,
    this.costUsd,
    required this.limits,
    required this.agents,
    required this.flowTitle,
    this.flowDone,
    this.flowTotal,
    required this.allowed,
    required this.you,
    required this.pending,
    required this.denied,
    required this.seenAt,
    this.title = '',
    this.firstSeen = 0,
    this.host = '',
  });

  final String key;
  final String project;
  final String status; // running | idle | ended
  final String model;
  final String mode;
  final int? ctxPct;
  final double? costUsd;
  final Map<String, int> limits;
  final List<AgentInfo> agents;
  final String flowTitle;
  final int? flowDone;
  final int? flowTotal;
  final int allowed;
  final int you;
  final int pending;
  final int denied;
  final int seenAt; // server time, ms

  /// The session's own title, when Claude names it; empty otherwise.
  final String title;

  /// When the session first appeared (ms, the PC's clock); 0 when unknown.
  final int firstSeen;

  /// A short hash of the PC that runs the session; empty when unknown.
  final String host;

  factory SessionInfo.fromMap(String key, Map<dynamic, dynamic> m) {
    final main = _m(m['main']);
    final meter = _m(m['meter']);
    final flow = _m(m['flow']);
    final gate = _m(m['gate']);
    final limits = <String, int>{};
    final rawLimits = meter['limits'];
    if (rawLimits is List) {
      for (final l in rawLimits) {
        final lm = _m(l);
        final p = _i(lm['pct']);
        if (p != null) limits[_s(lm['kind'])] = p;
      }
    }
    final agents = <AgentInfo>[];
    final rawAgents = m['agents'];
    if (rawAgents is List) {
      for (final a in rawAgents) {
        if (a is Map) agents.add(AgentInfo.fromMap(a));
      }
    } else if (rawAgents is Map) {
      for (final a in rawAgents.values) {
        if (a is Map) agents.add(AgentInfo.fromMap(a));
      }
    }
    return SessionInfo(
      key: key,
      project: _s(m['project'], key),
      status: _s(m['status'], 'idle'),
      model: _s(main['model']),
      mode: _s(main['mode']),
      ctxPct: _i(meter['ctxPct']),
      costUsd: _d(meter['costUsd']),
      limits: limits,
      agents: agents,
      flowTitle: _s(flow['title']),
      flowDone: _i(flow['done']),
      flowTotal: _i(flow['total']),
      allowed: _i(gate['allowed']) ?? 0,
      you: _i(gate['you']) ?? 0,
      pending: _i(gate['pending']) ?? 0,
      denied: _i(gate['denied']) ?? 0,
      seenAt: _i(m['seenAt']) ?? 0,
      title: _s(m['title']),
      firstSeen: _i(m['firstSeen']) ?? 0,
      host: _s(m['host']),
    );
  }

  /// A session that has not sent anything for this long is offline.
  static const offlineAfterMs = 45000;

  bool isOffline(int serverNowMs) =>
      status != 'ended' && serverNowMs - seenAt > offlineAfterMs;

  /// What the card shows: ended, offline, running or idle.
  String liveStatus(int serverNowMs) {
    if (status == 'ended') return 'ended';
    if (isOffline(serverNowMs)) return 'offline';
    return status;
  }
}

/// Every session under `live`, newest activity first.
List<SessionInfo> parseSessions(Object? value) {
  if (value is! Map) return const [];
  final out = <SessionInfo>[];
  value.forEach((k, v) {
    if (v is Map) out.add(SessionInfo.fromMap(k.toString(), v));
  });
  out.sort((a, b) => b.seenAt.compareTo(a.seenAt));
  return out;
}

String _s(Object? v, [String fallback = '']) => v is String ? v : fallback;
int? _i(Object? v) => v is num ? v.round() : null;
double? _d(Object? v) => v is num ? v.toDouble() : null;
Map<dynamic, dynamic> _m(Object? v) => v is Map ? v : const {};

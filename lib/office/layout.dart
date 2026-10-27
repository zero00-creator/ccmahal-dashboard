import '../models.dart';

/// One desk in the room. `agent` is null for the session's own (main) desk.
class Seat {
  const Seat(this.gx, this.gy, this.agent);
  final double gx;
  final double gy;
  final AgentInfo? agent;
}

class SeatPlan {
  const SeatPlan(this.seats, this.overflow);
  final List<Seat> seats;

  /// Agents that did not get a desk ("+n more").
  final int overflow;
}

/// Which room is drawn: the compact one (phone, 8 desks) or the wide hall
/// (desktop centre column, 16 desks).
enum SceneKind { compact, wide }

/// The main agent's desk (middle of the second column).
const _mainDesk = (4.4, 5.0);

/// The seven desks for subagents, in the order they are given out.
const _agentDesks = <(double, double)>[
  (1.0, 0.9),
  (1.0, 2.9),
  (1.0, 4.9),
  (1.0, 6.4),
  (4.4, 1.0),
  (4.4, 3.0),
  (4.4, 6.5),
];

/// The wide hall: desks in three rows of up to six, the main desk in the
/// middle row. The columns are 3 cells apart (gx 1.2 ... 16.2), the rows
/// 2.4 apart (gy 1.0, 3.4, 5.8).
const _wideMainDesk = (7.2, 3.4);

/// The fifteen agent desks of the wide hall, nearest the main desk first.
const _wideAgentDesks = <(double, double)>[
  (7.2, 1.0),
  (10.2, 3.4),
  (4.2, 3.4),
  (10.2, 1.0),
  (4.2, 1.0),
  (7.2, 5.8),
  (13.2, 3.4),
  (1.2, 3.4),
  (13.2, 1.0),
  (1.2, 1.0),
  (4.2, 5.8),
  (10.2, 5.8),
  (16.2, 3.4),
  (16.2, 1.0),
  (13.2, 5.8),
];

/// How many subagent desks a room has (the main desk is extra).
int agentDeskCount(SceneKind kind) => _desksOf(kind).length;

List<(double, double)> _desksOf(SceneKind kind) =>
    kind == SceneKind.wide ? _wideAgentDesks : _agentDesks;

/// Gives out the agent desks and remembers who sits where, so nobody
/// moves when the list changes. Running agents come first: a newcomer that is
/// running takes the desk of the oldest finished agent when the room is full,
/// while a finished newcomer never displaces anyone. Duplicate ids keep one desk.
class SeatAssigner {
  SeatAssigner([this.kind = SceneKind.compact]);

  /// The room whose desk table is used.
  final SceneKind kind;
  final Map<String, int> _desk = {};

  SeatPlan plan(List<AgentInfo> agents) {
    final sorted = [...agents]
      ..sort((a, b) {
        final c = a.startedAt.compareTo(b.startedAt);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    final seen = <String>{};
    final unique = [
      for (final a in sorted)
        if (seen.add(a.id)) a,
    ];
    final byId = {for (final a in unique) a.id: a};
    _desk.removeWhere((id, _) => !byId.containsKey(id));

    final desks = _desksOf(kind);
    final newcomers =
        [
          for (final a in unique)
            if (!_desk.containsKey(a.id)) a,
        ]..sort((a, b) {
          if (a.isRunning != b.isRunning) return a.isRunning ? -1 : 1;
          final c = a.startedAt.compareTo(b.startedAt);
          return c != 0 ? c : a.id.compareTo(b.id);
        });
    for (final a in newcomers) {
      final used = _desk.values.toSet();
      var free = -1;
      for (var d = 0; d < desks.length; d++) {
        if (!used.contains(d)) {
          free = d;
          break;
        }
      }
      if (free < 0 && a.isRunning) {
        // Full: a running newcomer takes the desk of the oldest finished agent.
        AgentInfo? oldest;
        for (final id in _desk.keys) {
          final other = byId[id]!;
          if (!other.isRunning &&
              (oldest == null || other.startedAt < oldest.startedAt))
            oldest = other;
        }
        if (oldest != null) {
          free = _desk.remove(oldest.id)!;
        }
      }
      if (free >= 0) _desk[a.id] = free;
    }

    final main = kind == SceneKind.wide ? _wideMainDesk : _mainDesk;
    final seats = <Seat>[Seat(main.$1, main.$2, null)];
    for (final a in unique) {
      final d = _desk[a.id];
      if (d != null) seats.add(Seat(desks[d].$1, desks[d].$2, a));
    }
    return SeatPlan(seats, unique.length - (seats.length - 1));
  }
}

/// A one-off plan with no memory (every agent is a newcomer).
SeatPlan planSeats(
  List<AgentInfo> agents, [
  SceneKind kind = SceneKind.compact,
]) => SeatAssigner(kind).plan(agents);

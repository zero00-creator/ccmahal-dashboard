import 'package:ccmahal_dashboard/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a pushed snapshot is read, newest activity first', () {
    final sessions = parseSessions({
      'old': {'v': 1, 'project': 'a', 'status': 'idle', 'seenAt': 1000},
      'new': {
        'v': 1,
        'project': 'proj',
        'status': 'running',
        'seenAt': 9000,
        'main': {'model': 'claude-opus-5-5', 'mode': 'auto'},
        'meter': {
          'ctxPct': 42,
          'costUsd': 1.5,
          'limits': [
            {'kind': '5h', 'pct': 10},
          ],
        },
        'gate': {'allowed': 3, 'you': 1, 'pending': 0, 'denied': 2},
        'agents': [
          {
            'id': 'a1',
            'type': 'coder-low',
            'task': 'Fix bug',
            'status': 'running',
            'stepDone': 1,
            'stepTotal': 4,
            'costUsd': 0.05,
          },
        ],
      },
    });
    expect(sessions.map((s) => s.key), ['new', 'old']);
    final s = sessions.first;
    expect(s.project, 'proj');
    expect(s.ctxPct, 42);
    expect(s.limits['5h'], 10);
    expect(s.agents.single.task, 'Fix bug');
    expect(s.agents.single.isRunning, isTrue);
    expect(s.denied, 2);
  });

  test('a session silent for 45 s is offline, an ended one is ended', () {
    final s = SessionInfo.fromMap('k', {'status': 'running', 'seenAt': 10000});
    expect(s.liveStatus(20000), 'running');
    expect(s.liveStatus(60000), 'offline');
    final e = SessionInfo.fromMap('k', {'status': 'ended', 'seenAt': 10000});
    expect(e.liveStatus(999999), 'ended');
  });

  test('missing or odd fields read as empty', () {
    expect(parseSessions(null), isEmpty);
    expect(parseSessions('x'), isEmpty);
    final s = SessionInfo.fromMap('k', {
      'agents': 5,
      'meter': 'x',
      'seenAt': 'soon',
    });
    expect(s.agents, isEmpty);
    expect(s.ctxPct, isNull);
    expect(s.seenAt, 0);
    expect(s.project, 'k');
  });
}

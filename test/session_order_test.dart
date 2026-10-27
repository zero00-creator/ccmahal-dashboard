import 'package:ccmahal_dashboard/models.dart';
import 'package:ccmahal_dashboard/session_order.dart';
import 'package:flutter_test/flutter_test.dart';

const now = 10000000;
const minute = 60000;

SessionInfo s(
  String key, {
  int firstSeen = 0,
  int seenAt = now - 10000,
  String status = 'running',
}) => SessionInfo.fromMap(key, {
  'firstSeen': firstSeen,
  'seenAt': seenAt,
  'status': status,
});

void main() {
  test('parseSessions reads title, firstSeen and host and defaults them when missing', () {
    final full = SessionInfo.fromMap('k', {
      'title': 'My title',
      'firstSeen': 123,
      'host': 'ab12cd34',
      'project': 'p',
    });
    expect(full.title, 'My title');
    expect(full.firstSeen, 123);
    expect(full.host, 'ab12cd34');
    final bare = SessionInfo.fromMap('k', {});
    expect(bare.title, '');
    expect(bare.firstSeen, 0);
    expect(bare.host, '');
  });

  test('ended sessions are not shown', () {
    final out = visibleSessions([
      s('a', firstSeen: 1),
      s('b', firstSeen: 2, status: 'ended'),
    ], now);
    expect(out.map((e) => e.key), ['a']);
  });

  test('an offline session is shown for an hour and then dropped', () {
    final shown = visibleSessions([
      s('a', firstSeen: 1, seenAt: now - 59 * minute),
    ], now);
    final gone = visibleSessions([
      s('a', firstSeen: 1, seenAt: now - 61 * minute),
    ], now);
    expect(shown.map((e) => e.key), ['a']);
    expect(gone, isEmpty);
  });

  test(
    'a session with seenAt 0 and no firstSeen is dropped as long offline',
    () {
      expect(visibleSessions([s('a', seenAt: 0)], now), isEmpty);
    },
  );

  test('order is by firstSeen, unknown last by key, and does not change when seenAt changes', () {
    final list = [
      s('z'),
      s('a', firstSeen: 100),
      s('m', firstSeen: 300),
      s('y'),
    ];
    final one = visibleSessions(list, now).map((e) => e.key).toList();
    final two = visibleSessions(
      list.reversed.toList(),
      now,
    ).map((e) => e.key).toList();
    expect(one, ['a', 'm', 'y', 'z']);
    expect(two, one);
    final moved = visibleSessions([
      s('m', firstSeen: 300, seenAt: now - 1000),
      s('a', firstSeen: 100, seenAt: now - 5000),
    ], now);
    expect(moved.map((e) => e.key), ['a', 'm']);
  });
}
